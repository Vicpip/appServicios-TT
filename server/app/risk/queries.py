"""Construccion de las visitas para el modelo de riesgo a partir de la base real y del historial anterior a la app.

Reglas (addendum D-11 a D-16):
- Una "visita" es un Report. Solo cuentan los estados de ESTADOS_ELEGIBLES (lista blanca: todo lo demas queda fuera),
  los reportes reemplazados por otro (supersedes_report_id) y las impresoras inactivas se excluyen. Nunca se parte de polizas.
- El historial anterior a la app es un CSV de solo lectura (data/historico_visitas.csv). Por impresora se usan sus filas con
  fecha < (primer reporte elegible de la app - MARGEN_DUPLICADO_DIAS); desde ese corte manda la app.
- Criterio de Aurora para `cabezal` y `rodillo` (confirmado; ver ml_models/MODEL_CARD.md): la bandera vale 1 si las
  notas del reporte indican reemplazo, cambio, sustitucion, dano, desgaste, quemado o rotura de ESA pieza, aunque el
  checkbox "dañado" no este marcado. No cuentan limpieza, revision sin hallazgos ni otras piezas (ribbon, spindle,
  sensores). `falla` = 1 si alguna pieza de dano vale 1.
  PENDIENTE: `_fila_app` aun deriva las banderas solo del checklist (`CLAVES_CHECKLIST`), asi que subestima frente a
  ese criterio (en la copia: 9 cabezal y 7 rodillo de 152 visitas). El mapeo no se ha cambiado.
- Contador 0 = dato faltante (NaN). Modelo = f"{model_name.strip().upper()}-{dpi}dpi".
- Lo que no es Zebra no se puntua (MODELOS_EXCLUIDOS).

Este modulo no importa numpy ni pandas al cargarse: se importan dentro de las funciones que arman el DataFrame.
"""
import json
import logging
import re
from dataclasses import dataclass, field
from datetime import date, timedelta
from functools import lru_cache
from pathlib import Path
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session, aliased

from app.config import get_settings
from app.models.catalog import CatalogModel
from app.models.printer import Printer
from app.models.report import Report

logger = logging.getLogger(__name__)

# Lista blanca: cualquier estado nuevo o desconocido (Draft, Deleted, ...) queda fuera por defecto.
ESTADOS_ELEGIBLES = ("signed", "Signed", "Synced", "pending_delivery", "pending_group_signature")

RUTA_HISTORICO = Path(__file__).resolve().parent / "data" / "historico_visitas.csv"
MARGEN_DUPLICADO_DIAS = 2          # service_date se guarda en UTC y el Excel esta en fecha local
OFFSET_APP = 1_000_000             # fila_origen de las visitas de la app: siempre despues de las del CSV

# Aparatos que no son Zebra. Se buscan como inicio de palabra en "marca modelo" (sin distinguir mayusculas).
# catalog_models trae `brand`, pero no hay forma de saber desde aqui si esta bien capturada en produccion,
# asi que se usa solo a traves de estos patrones. No excluye GC420t, ZD*, ZQ*, ZE500, 105 SL PLUS ni ZM400.
MODELOS_EXCLUIDOS = ("HP", "LASERJET", "OFFICEJET", "MICROLINE", "DVR")

CLAVES_CHECKLIST = {
    "mantenimiento": "Mantenimiento general",
    "calibracion": "Calibración sensores",
    "rodillo": "Rodillo dañado",
    "cabezal": "Cabezal dañado",
    "sensor_ribbon": "Sensor ribbon dañado",
    "sensor_papel": "Sensor papel dañado",
}
_DANOS = ("rodillo", "cabezal", "sensor_ribbon", "sensor_papel")


def es_modelo_excluido(marca: str | None, modelo: str | None, excluidos: tuple[str, ...] = MODELOS_EXCLUIDOS) -> bool:
    """True si "marca modelo" empieza con alguno de los patrones en cualquier palabra (p. ej. 'HP LaserJet 4250n')."""
    texto = f"{marca or ''} {modelo or ''}".upper()
    return any(re.search(rf"(?<![A-Z0-9]){re.escape(p.upper())}", texto) for p in excluidos)


def nombre_modelo(model_name: str, dpi: int | None) -> str:
    return f"{(model_name or '').strip().upper()}-{dpi}dpi"


def _clave_serie(serie: Any) -> str:
    return str(serie).strip().upper()


def _checklist(texto: str | None) -> dict:
    """json.loads defensivo: texto vacio, JSON malo o que no sea un objeto -> {}."""
    try:
        valor = json.loads(texto) if texto else {}
    except (ValueError, TypeError):
        return {}
    return valor if isinstance(valor, dict) else {}


def _fecha(valor) -> date:
    return valor.date() if hasattr(valor, "date") else valor


@dataclass
class ImpresoraInfo:
    printer_id: str
    numero_serie: str
    client_id: str
    modelo: str
    visitas_app: int = 0
    visitas_historicas: int = 0
    corte: date | None = None      # fecha del primer reporte elegible de la app


@dataclass
class Visitas:
    df: Any                                            # DataFrame con exactamente datos.COLS
    info: dict[str, ImpresoraInfo] = field(default_factory=dict)       # clave de serie -> info
    excluidas: list[tuple[str, str]] = field(default_factory=list)     # (serie, modelo) no Zebra
    sin_datos: list[str] = field(default_factory=list)                 # impresoras sin visitas de app ni historial

    def por_printer_id(self, printer_id: str) -> ImpresoraInfo | None:
        return next((i for i in self.info.values() if i.printer_id == printer_id), None)


def series_excluidas_config() -> frozenset[str]:
    """Claves de serie (mayusculas, sin espacios) de RISK_SERIES_EXCLUIDAS: equipos de demo/prueba fuera del calculo."""
    texto = getattr(get_settings(), "risk_series_excluidas", "") or ""
    return frozenset(_clave_serie(s) for s in texto.split(",") if s.strip())


def impresoras_candidatas(db: Session, printer_ids: list[str] | None = None, client_id: str | None = None,
                          excluidos: tuple[str, ...] = MODELOS_EXCLUIDOS):
    """Impresoras activas. Devuelve (candidatas, excluidas): las no Zebra se separan y se registran en el log.
    Las series de RISK_SERIES_EXCLUIDAS (demo/prueba) tambien quedan fuera y se registran en el log, sin entrar a `excluidas`."""
    manuales = series_excluidas_config()
    q = (select(Printer.id, Printer.serial_number, Printer.client_id, CatalogModel.brand,
                CatalogModel.model_name, CatalogModel.dpi)
         .join(CatalogModel, CatalogModel.id == Printer.model_id)
         .where(Printer.is_active.is_(True))
         .order_by(Printer.serial_number))
    if printer_ids is not None:
        q = q.where(Printer.id.in_(printer_ids))
    if client_id is not None:
        q = q.where(Printer.client_id == client_id)
    candidatas, excluidas, por_config = [], [], []
    for fila in db.execute(q).all():
        if _clave_serie(fila.serial_number) in manuales:
            por_config.append(fila.serial_number)
        elif es_modelo_excluido(fila.brand, fila.model_name, excluidos):
            excluidas.append((fila.serial_number, nombre_modelo(fila.model_name, fila.dpi)))
        else:
            candidatas.append(fila)
    if excluidas:
        logger.info("Riesgo: %d impresora(s) no Zebra excluidas del calculo: %s", len(excluidas),
                    ", ".join(f"{s} ({m})" for s, m in excluidas))
    if por_config:
        logger.info("Riesgo: %d impresora(s) excluidas por RISK_SERIES_EXCLUIDAS: %s", len(por_config), ", ".join(por_config))
    return candidatas, excluidas


def reportes_elegibles(db: Session, printer_ids: list[str]):
    """Reportes elegibles de esas impresoras, en orden determinista (serie, service_date, created_at, id)."""
    if not printer_ids:
        return []
    sup = aliased(Report)   # un reporte que reemplaza a otro: el reemplazado queda fuera
    reemplazados = select(sup.supersedes_report_id).where(sup.supersedes_report_id.is_not(None))
    q = (select(Printer.id.label("printer_id"), Printer.serial_number, Report.id.label("report_id"),
                Report.service_date, Report.service_type, Report.linear_inches_counter, Report.technical_checkboxes)
         .join(Printer, Printer.id == Report.printer_id)
         .where(Printer.id.in_(printer_ids), Report.status.in_(ESTADOS_ELEGIBLES), Report.id.not_in(reemplazados))
         .order_by(Printer.serial_number, Report.service_date, Report.created_at, Report.id))
    return db.execute(q).all()


@lru_cache(maxsize=4)
def _leer_historico(ruta: str, mtime: float):
    import pandas as pd
    from app.risk import datos as D
    # `mtime` solo invalida la cache si cambia el archivo.
    return D.preparar_visitas(pd.read_csv(ruta, dtype={"numero_serie": str}))


def ruta_historico() -> Path:
    configurada = (get_settings().risk_historico_path or "").strip()
    return Path(configurada) if configurada else RUTA_HISTORICO


def cargar_historico(ruta: Path | str | None = None):
    """Historial anterior a la app (DataFrame con datos.COLS). Se lee una vez; no lo modifiques (hazle .copy()).
    Si el archivo no existe lanza HistorialNoDisponible; con risk_permitir_sin_historico=true devuelve un historial vacio
    (y avisa en el log): nunca se calcula sin historial en silencio."""
    from app.risk import HistorialNoDisponible
    ruta = Path(ruta) if ruta else ruta_historico()
    if not ruta.is_file():
        if get_settings().risk_permitir_sin_historico:
            import pandas as pd
            from app.risk import datos as D
            logger.warning("Riesgo: no existe el historial %s; se calcula SIN historial (RISK_PERMITIR_SIN_HISTORICO=true): "
                           "el riesgo se subestima", ruta)
            return pd.DataFrame(columns=D.COLS)
        logger.error("Riesgo: no existe el historial de visitas %s", ruta)
        raise HistorialNoDisponible(
            f"No se encontró el historial de visitas anterior a la app ({ruta.name}). Sin él el riesgo se "
            "subestima. Colócalo en el servidor (RISK_HISTORICO_PATH) o permite calcular sin historial con "
            "RISK_PERMITIR_SIN_HISTORICO=true.")
    return _leer_historico(str(ruta), ruta.stat().st_mtime)


def estado_historico() -> tuple[bool, int]:
    """(cargado, n_filas) sin lanzar: para informar. cargado=False si el archivo falta."""
    ruta = ruta_historico()
    if not ruta.is_file():
        return False, 0
    return True, int(len(_leer_historico(str(ruta), ruta.stat().st_mtime)))


def _fila_app(r, fila_origen: int, modelo: str, tipo: str) -> dict:
    cb = _checklist(r.technical_checkboxes)
    flags = {col: 1 if cb.get(clave) is True else 0 for col, clave in CLAVES_CHECKLIST.items()}
    contador = r.linear_inches_counter
    return dict(numero_serie=r.serial_number, fila_origen=fila_origen, fecha=_fecha(r.service_date), modelo=modelo,
                tipo_servicio=tipo, contador_1=None if not contador else contador,    # 0 = dato faltante
                **flags, falla=1 if any(flags[c] for c in _DANOS) else 0)


def construir_visitas(db: Session, printer_ids: list[str] | None = None, client_id: str | None = None,
                      historico=None, excluidos: tuple[str, ...] = MODELOS_EXCLUIDOS) -> Visitas:
    """DataFrame de visitas (historial CSV + reportes de la app) listo para `modelo.predecir`.
    `historico`: DataFrame con datos.COLS; por defecto el CSV versionado. Pasa uno vacio para no usar historial."""
    import pandas as pd
    from app.risk import datos as D

    candidatas, excluidas = impresoras_candidatas(db, printer_ids, client_id, excluidos)
    info = {_clave_serie(c.serial_number): ImpresoraInfo(c.id, c.serial_number, c.client_id, nombre_modelo(c.model_name, c.dpi))
            for c in candidatas}
    por_id = {i.printer_id: i for i in info.values()}

    filas, contadas = [], {}
    for r in reportes_elegibles(db, list(por_id)):
        i = por_id[r.printer_id]
        n = contadas.get(i.printer_id, 0)
        contadas[i.printer_id] = n + 1
        fecha = _fecha(r.service_date)
        i.corte = fecha if i.corte is None else min(i.corte, fecha)
        i.visitas_app = n + 1
        filas.append(_fila_app(r, OFFSET_APP + n, i.modelo, D.normalizar_tipo_servicio(r.service_type)))
    app_df = pd.DataFrame(filas, columns=D.COLS)

    hist = cargar_historico() if historico is None else historico
    partes = []
    if len(hist):
        claves = hist.numero_serie.map(_clave_serie)
        for clave, i in info.items():
            mias = hist[claves == clave]
            if i.corte is not None:
                mias = mias[mias.fecha.dt.date < i.corte - timedelta(days=MARGEN_DUPLICADO_DIAS)]
            if len(mias):
                mias = mias.copy()
                mias["numero_serie"] = i.numero_serie
                i.visitas_historicas = len(mias)
                partes.append(mias[D.COLS])
    if len(app_df):
        partes.append(app_df)
    df = pd.concat(partes, ignore_index=True) if partes else pd.DataFrame(columns=D.COLS)
    df["fecha"] = pd.to_datetime(df.fecha)      # una sola dtype (solo fecha, sin hora) para historial y app
    sin_datos = [i.numero_serie for i in info.values() if i.visitas_app + i.visitas_historicas == 0]
    return Visitas(df=df, info=info, excluidas=excluidas, sin_datos=sin_datos)
