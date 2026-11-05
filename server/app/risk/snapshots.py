"""Snapshots del riesgo (tabla printer_risk_snapshots): escritura (upsert), lectura y bloqueo de concurrencia.

- Una fila por (impresora, pieza). El refresh calcula con `service.calcular` y hace upsert; leer NUNCA calcula.
- `vigente`, `stale` y `modelo_desactualizado` no se guardan: se derivan al leer.
    vigente                valid_until >= hoy
    stale                  hay un reporte elegible mas reciente que `last_report_id` (o el ultimo ya no es ese)
    modelo_desactualizado  model_version != version del modelo cargado (False si el modelo no esta disponible)
- inputs_json guarda SOLO numeros: las variables de la ultima visita que vio el modelo, el desglose de visitas
  (app / historicas) y, por pieza, si se activo solo por las notas. Jamas el texto de las notas, la serie ni el cliente.

Este modulo no importa numpy ni pandas: se pueden leer snapshots aunque el motor de ML no este instalado.
"""
import json
import logging
import uuid
from dataclasses import dataclass, field
from datetime import date, datetime, timezone

from sqlalchemy import delete, select, text
from sqlalchemy.orm import Session

from app.models.risk import PrinterRiskSnapshot
from app.risk import ModeloNoDisponible, queries, service

logger = logging.getLogger(__name__)

PIEZAS = ("cabezal", "rodillo")
HORIZONTE_DIAS = 90
LOCK_KEY = 7_262_026_001      # pg_try_advisory_xact_lock: un solo refresh a la vez en toda la base
AVISO_DEFECTO = ("Estimacion estadistica del riesgo de que la pieza aparezca danada en alguna visita de los proximos "
                 "90 dias. No es una fecha de falla ni una garantia.")


class RefreshOcupado(RuntimeError):
    """Ya hay un refresh de riesgo corriendo (lock de PostgreSQL ocupado)."""


def _ahora() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)      # UTC naive, como el resto de la base


def bloquear(db: Session) -> None:
    """Toma el lock de refresh hasta el fin de la transaccion (commit/rollback). Solo en PostgreSQL; en SQLite (pruebas)
    no hace nada. Lanza RefreshOcupado si otro proceso lo tiene."""
    if db.get_bind().dialect.name != "postgresql":
        return
    if not db.execute(text("SELECT pg_try_advisory_xact_lock(:k)"), {"k": LOCK_KEY}).scalar():
        raise RefreshOcupado("Ya hay una actualización de riesgo en curso")


# --------------------------------------------------------------------------- escritura

def _inputs_json(equipo: dict) -> str:
    entradas = {k: v for k, v in (equipo.get("entradas") or {}).items()
                if v is None or (isinstance(v, (int, float)) and not isinstance(v, bool))}    # defensa: solo numeros
    solo_notas = equipo.get("dano_solo_notas") or {}
    return json.dumps({
        "entradas": entradas,
        "visitas_app": int(equipo["visitas_app"]), "visitas_historicas": int(equipo["visitas_historicas"]),
        "dano_solo_notas": {p: bool(solo_notas.get(p, False)) for p in PIEZAS},
    }, sort_keys=True)


def guardar(db: Session, equipos: list[dict], version_modelo: str, computed_by: str | None = None,
            ahora: datetime | None = None) -> list[PrinterRiskSnapshot]:
    """Upsert por (printer_id, piece) de los equipos de `service.calcular(..., con_entradas=True)`. No hace commit."""
    ahora = ahora or _ahora()
    if not equipos:
        return []
    existentes = {(s.printer_id, s.piece): s for s in db.scalars(
        select(PrinterRiskSnapshot).where(PrinterRiskSnapshot.printer_id.in_([e["printer_id"] for e in equipos])))}
    guardados = []
    for e in equipos:
        inputs = _inputs_json(e)
        for pieza in PIEZAS:
            p = e[pieza]
            s = existentes.get((e["printer_id"], pieza))
            if s is None:
                s = PrinterRiskSnapshot(id=str(uuid.uuid4()), printer_id=e["printer_id"], piece=pieza)
                db.add(s)
                existentes[(e["printer_id"], pieza)] = s
            s.level, s.risk_index = p["nivel"], float(p["indice_riesgo"])
            s.damaged_last_visit, s.previous_damages = bool(p["danada_en_ultima_visita"]), int(p["danos_previos"])
            s.visits_count, s.short_history = int(e["visitas_registradas"]), bool(e["historial_corto"])
            s.last_visit_date = date.fromisoformat(e["fecha_ultima_visita"])
            s.valid_until = date.fromisoformat(e["vigente_hasta"])
            s.last_report_id = e.get("ultimo_report_id")
            s.model_version = version_modelo
            s.inputs_json = inputs
            s.computed_at, s.computed_by = ahora, computed_by
            guardados.append(s)
    db.flush()
    return guardados


@dataclass
class ResultadoRefresh:
    equipos: list[dict]                                  # lo calculado (con printer_id, client_id, ...)
    snapshots: list[PrinterRiskSnapshot]
    version_modelo: str
    computed_at: datetime
    excluidas: list = field(default_factory=list)        # no Zebra
    sin_datos: list = field(default_factory=list)        # sin visitas de app ni historial
    eliminados: int = 0                                  # filas de snapshot borradas por dejar de ser elegibles


def eliminar_no_elegibles(db: Session, vigentes: list[str], printer_ids: list[str] | None = None) -> int:
    """Borra los snapshots del alcance (todas las impresoras si printer_ids es None) que ya no estan en `vigentes`
    (los printer_id que acaba de calcular el refresh). Devuelve cuantas filas borro. No hace commit."""
    q = delete(PrinterRiskSnapshot)
    if printer_ids is not None:
        q = q.where(PrinterRiskSnapshot.printer_id.in_(printer_ids))
    if vigentes:
        q = q.where(PrinterRiskSnapshot.printer_id.not_in(vigentes))
    return db.execute(q.execution_options(synchronize_session=False)).rowcount or 0


def refrescar(db: Session, printer_ids: list[str] | None = None, computed_by: str | None = None,
              hoy: date | None = None) -> ResultadoRefresh:
    """Recalcula y guarda (commit) el riesgo de las impresoras indicadas (todas las activas si None).
    Lanza ModeloNoDisponible / HistorialNoDisponible si no se puede calcular: en ese caso no se escribe nada.
    No toma el lock: quien llama decide (`bloquear` antes, en la misma transaccion)."""
    res = service.calcular(db, printer_ids, hoy=hoy, con_entradas=True)
    ahora = _ahora()
    try:
        snaps = guardar(db, res.equipos, res.version_modelo, computed_by, ahora)
        eliminados = eliminar_no_elegibles(db, [e["printer_id"] for e in res.equipos], printer_ids)
        db.commit()
    except Exception:
        db.rollback()
        raise
    return ResultadoRefresh(equipos=res.equipos, snapshots=snaps, version_modelo=res.version_modelo, computed_at=ahora,
                            excluidas=res.excluidas, sin_datos=res.sin_datos, eliminados=eliminados)


# --------------------------------------------------------------------------- lectura

@dataclass
class VistaSnapshot:
    """Las dos piezas de una impresora, ya con lo derivado al leer."""
    printer_id: str
    client_id: str
    numero_serie: str
    modelo_impresora: str
    piezas: dict[str, PrinterRiskSnapshot]
    vigente: bool
    stale: bool
    modelo_desactualizado: bool

    @property
    def ref(self) -> PrinterRiskSnapshot:
        return self.piezas["cabezal"]

    def inputs(self) -> dict:
        try:
            return json.loads(self.ref.inputs_json or "{}")
        except ValueError:
            return {}


@dataclass
class Lectura:
    vistas: list[VistaSnapshot]
    sin_calcular: int                  # impresoras que entran al calculo y aun no tienen snapshot
    version_modelo: str | None         # del modelo cargado; None si no esta disponible
    aviso: str


def version_actual() -> tuple[str | None, str]:
    """(version, aviso) del modelo cargado, o (None, aviso por defecto) si no esta disponible: leer no debe fallar por eso."""
    try:
        art = service.cargar_artefacto()
    except ModeloNoDisponible as e:
        logger.info("Riesgo: se lee sin conocer la version del modelo (%s)", e)
        return None, AVISO_DEFECTO
    return art["version"], art.get("aviso") or AVISO_DEFECTO


def _visitas_historicas(snap: PrinterRiskSnapshot) -> int:
    try:
        return int(json.loads(snap.inputs_json or "{}").get("visitas_historicas", 0))
    except (ValueError, TypeError, AttributeError):
        return 0


def leer(db: Session, printer_ids: list[str] | None = None, client_id: str | None = None,
         hoy: date | None = None) -> Lectura:
    """Snapshots de las impresoras que entran al calculo (activas, Zebra, no excluidas). NO calcula."""
    hoy = hoy or date.today()
    candidatas, _ = queries.impresoras_candidatas(db, printer_ids, client_id)
    por_id = {c.id: c for c in candidatas}
    version, aviso = version_actual()
    if not por_id:
        return Lectura([], 0, version, aviso)
    filas: dict[str, dict[str, PrinterRiskSnapshot]] = {}
    for s in db.scalars(select(PrinterRiskSnapshot).where(PrinterRiskSnapshot.printer_id.in_(list(por_id)))):
        filas.setdefault(s.printer_id, {})[s.piece] = s
    completos = {pid: p for pid, p in filas.items() if all(z in p for z in PIEZAS)}
    ultimos = queries.ultimos_reportes_elegibles(db, list(completos))
    vistas = []
    for pid, piezas in completos.items():
        c = por_id[pid]
        ref = piezas["cabezal"]
        if pid not in ultimos and not _visitas_historicas(ref):
            continue          # fila vieja de un equipo que ya no tiene visitas: el refresh la borrara
        vistas.append(VistaSnapshot(
            printer_id=pid, client_id=c.client_id, numero_serie=c.serial_number,
            modelo_impresora=queries.nombre_modelo(c.model_name, c.dpi), piezas=piezas,
            vigente=ref.valid_until >= hoy,
            stale=ultimos.get(pid) != ref.last_report_id,
            modelo_desactualizado=version is not None and any(p.model_version != version for p in piezas.values())))
    return Lectura(vistas=vistas, sin_calcular=len(por_id) - len(vistas), version_modelo=version, aviso=aviso)
