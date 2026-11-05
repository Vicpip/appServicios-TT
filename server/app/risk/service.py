"""Servicio de riesgo: carga perezosa del modelo y calculo sobre las visitas reales.

No importa numpy/pandas/scikit-learn al cargarse. Si faltan o el modelo no carga, se lanza ModeloNoDisponible
y el router responde 503; el resto de la app no se entera.
"""
import logging
import os
from dataclasses import dataclass
from datetime import date
from pathlib import Path

from sqlalchemy.orm import Session

from app.config import get_settings
from app.risk import ModeloNoDisponible
from app.risk import queries

logger = logging.getLogger(__name__)

RUTA_MODELO_DEFECTO = Path(__file__).resolve().parents[2] / "ml_models" / "modelo_riesgo.joblib"
_cache: dict = {}    # {(ruta, mtime): artefacto}; un solo slot: si cambia el archivo se recarga


def verificar_habilitado() -> None:
    if not get_settings().risk_enabled:
        raise ModeloNoDisponible("El modulo de riesgo esta deshabilitado (RISK_ENABLED=false)")


def ruta_modelo() -> Path:
    configurada = (get_settings().risk_model_path or "").strip()
    return Path(configurada) if configurada else RUTA_MODELO_DEFECTO


def _importar_motor():
    """Importa el motor (numpy/pandas/sklearn/joblib). Aislado para poder simular su ausencia en pruebas."""
    try:
        from app.risk import modelo
    except ImportError as e:
        raise ModeloNoDisponible(f"Faltan dependencias del modulo de riesgo (requirements-ml.txt): {e}") from e
    return modelo


def cargar_artefacto():
    """Artefacto del modelo, en cache por (ruta, mtime). Lanza ModeloNoDisponible si no esta disponible."""
    verificar_habilitado()
    modelo = _importar_motor()
    ruta = ruta_modelo()
    try:
        clave = (str(ruta), os.stat(ruta).st_mtime)
    except OSError as e:
        raise ModeloNoDisponible(f"No existe el archivo del modelo: {ruta}") from e
    if clave not in _cache:
        art = modelo.cargar(ruta)
        _cache.clear()
        _cache[clave] = art
        logger.info("Modelo de riesgo cargado: version %s (%s)", art.get("version"), ruta)
    return _cache[clave]


def informacion() -> dict:
    art = cargar_artefacto()
    info = _importar_motor().informacion(art)
    info["historico_cargado"], info["n_filas_historico"] = queries.estado_historico()
    info["permitir_sin_historico"] = bool(get_settings().risk_permitir_sin_historico)
    return info


@dataclass
class Resultado:
    version_modelo: str
    horizonte_dias: int
    aviso: str
    equipos: list[dict]
    excluidas: list[tuple[str, str]]
    sin_datos: list[str]


def calcular(db: Session, printer_ids: list[str] | None = None, client_id: str | None = None,
             hoy: date | None = None, historico=None, con_entradas: bool = False) -> Resultado:
    """Riesgo de las impresoras indicadas (todas las activas si printer_ids es None).
    Cada equipo trae lo de `modelo.predecir` mas printer_id, client_id y el desglose de visitas (app / historicas).
    `con_entradas=True` agrega ademas `entradas` (variables numericas de la ultima visita), `ultimo_report_id` y
    `dano_solo_notas`: lo que necesitan los snapshots."""
    art = cargar_artefacto()              # primero el modelo: si falla, no se toca la base
    modelo = _importar_motor()
    if historico is None:
        historico = queries.cargar_historico()    # 503 (HistorialNoDisponible) si falta y no esta permitido
    visitas = queries.construir_visitas(db, printer_ids, client_id, historico=historico)
    equipos = []
    for fila in modelo.predecir(art, visitas.df, hoy=hoy, con_entradas=con_entradas):
        i = visitas.info[queries._clave_serie(fila["numero_serie"])]
        fila.update(printer_id=i.printer_id, client_id=i.client_id,
                    visitas_app=i.visitas_app, visitas_historicas=i.visitas_historicas)
        if con_entradas:
            fila.update(ultimo_report_id=i.ultimo_report_id, dano_solo_notas=dict(i.dano_solo_notas))
        equipos.append(fila)
    return Resultado(version_modelo=art["version"], horizonte_dias=art["horizonte_dias"], aviso=art["aviso"],
                     equipos=equipos, excluidas=visitas.excluidas, sin_datos=visitas.sin_datos)
