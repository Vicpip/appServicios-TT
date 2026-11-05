"""Riesgo de piezas (cabezal y rodillo) — solo admin.

- GET: lee los snapshots guardados (tabla printer_risk_snapshots). NUNCA calcula.
- POST .../refresh: recalcula y guarda el riesgo de una impresora o de las impresoras de una poliza.

Todos los handlers son `def` (no `async def`): FastAPI los corre en un hilo y el calculo (pandas/sklearn, ~0.5 s) no bloquea
el unico proceso de uvicorn. Un solo refresh a la vez: pg_try_advisory_xact_lock en PostgreSQL (409 si esta ocupado).
"""
import logging
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.auth import require_admin
from app.database import get_db
from app.models.policy import Policy, PolicyPrinter
from app.models.printer import Printer
from app.risk import HistorialNoDisponible, ModeloNoDisponible, service, snapshots
from app.schemas.risk import (EquipoSnapshot, ModeloInfo, PiezaSnapshot, RefreshRespuesta, RiesgoSnapshots)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/admin", tags=["risk"], dependencies=[Depends(require_admin)])


def _no_disponible(e: ModeloNoDisponible) -> HTTPException:
    logger.warning("Riesgo no disponible: %s", e)    # la causa (rutas, versiones) va al log, no al cliente
    if isinstance(e, HistorialNoDisponible):         # este mensaje esta escrito para el administrador y no lleva rutas
        return HTTPException(status_code=503, detail=str(e))
    return HTTPException(status_code=503, detail="Modelo de riesgo no disponible. Intenta más tarde o avisa al administrador del sistema.")


def _equipo(v: snapshots.VistaSnapshot, aviso: str) -> EquipoSnapshot:
    ref, inputs = v.ref, v.inputs()
    solo_notas = inputs.get("dano_solo_notas") or {}
    piezas = {
        pz: PiezaSnapshot(nivel=s.level, indice_riesgo=s.risk_index, danada_en_ultima_visita=s.damaged_last_visit,
                          danos_previos=s.previous_damages, en_monitoreo=(pz == "rodillo"),
                          dano_detectado_en_notas=bool(solo_notas.get(pz, False)))
        for pz, s in v.piezas.items()}
    return EquipoSnapshot(
        printer_id=v.printer_id, client_id=v.client_id, numero_serie=v.numero_serie, modelo_impresora=v.modelo_impresora,
        fecha_ultima_visita=ref.last_visit_date.isoformat(), vigente_hasta=ref.valid_until.isoformat(),
        vigente=v.vigente, stale=v.stale, modelo_desactualizado=v.modelo_desactualizado,
        visitas_registradas=ref.visits_count, visitas_app=int(inputs.get("visitas_app", 0)),
        visitas_historicas=int(inputs.get("visitas_historicas", 0)), historial_corto=ref.short_history,
        cabezal=piezas["cabezal"], rodillo=piezas["rodillo"], version_modelo=ref.model_version,
        computed_at=ref.computed_at, computed_by=ref.computed_by, aviso=aviso)


@router.get("/risk/model/info", response_model=ModeloInfo)
def model_info() -> ModeloInfo:
    """Version, fecha de entrenamiento y metricas del modelo cargado."""
    try:
        return ModeloInfo(**service.informacion())
    except ModeloNoDisponible as e:
        raise _no_disponible(e)


@router.get("/risk/printers", response_model=RiesgoSnapshots)
def list_printers(
    level: Literal["ALTO", "MEDIO", "BAJO"] | None = Query(None, description="Nivel de la pieza"),
    piece: Literal["cabezal", "rodillo"] | None = Query(None, description="Pieza; sin ella, level aplica a cualquiera"),
    client_id: str | None = Query(None),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
) -> RiesgoSnapshots:
    """Riesgo guardado de las impresoras Zebra activas, de mayor a menor. Lee snapshots: no calcula."""
    lectura = snapshots.leer(db, client_id=client_id)
    piezas = (piece,) if piece else snapshots.PIEZAS
    vistas = [v for v in lectura.vistas if level is None or any(v.piezas[p].level == level for p in piezas)]
    # Orden: mayor indice de riesgo primero (de la pieza pedida o del maximo de las dos); serie para desempatar.
    vistas.sort(key=lambda v: (-max(v.piezas[p].risk_index for p in piezas), v.numero_serie))
    return RiesgoSnapshots(
        total=len(vistas), version_modelo=lectura.version_modelo, horizonte_dias=snapshots.HORIZONTE_DIAS,
        aviso=lectura.aviso, equipos=[_equipo(v, lectura.aviso) for v in vistas[:limit]],
        sin_calcular=lectura.sin_calcular)


@router.get("/risk/printers/{printer_id}", response_model=EquipoSnapshot)
def get_printer(printer_id: str, db: Session = Depends(get_db)) -> EquipoSnapshot:
    """Riesgo guardado de una impresora. 404 si no existe, no aplica o aun no se ha calculado."""
    lectura = snapshots.leer(db, [printer_id])
    if lectura.vistas:
        return _equipo(lectura.vistas[0], lectura.aviso)
    if lectura.sin_calcular:
        raise HTTPException(status_code=404, detail="Aún no hay un cálculo de riesgo para esta impresora. Usa «Actualizar riesgo».")
    raise HTTPException(status_code=404, detail="Impresora no encontrada, inactiva o sin estimación de riesgo (no aplica a equipos que no son Zebra)")


def _refrescar(db: Session, printer_ids: list[str], user_id: str | None) -> RefreshRespuesta:
    """Un refresh a la vez; calcula, guarda y responde con lo guardado (lo mismo que devolvera el GET)."""
    try:
        snapshots.bloquear(db)
    except snapshots.RefreshOcupado as e:
        raise HTTPException(status_code=409, detail=str(e))
    try:
        res = snapshots.refrescar(db, printer_ids, computed_by=user_id)
    except ModeloNoDisponible as e:
        db.rollback()                                 # suelta el lock
        raise _no_disponible(e)
    except Exception:
        db.rollback()
        logger.exception("Riesgo: fallo al actualizar")
        raise HTTPException(status_code=500, detail="No se pudo actualizar el riesgo. Revisa el registro del servidor.")
    lectura = snapshots.leer(db, [e["printer_id"] for e in res.equipos])
    return RefreshRespuesta(
        computed_at=res.computed_at, computed_by=user_id, version_modelo=res.version_modelo,
        equipos=[_equipo(v, lectura.aviso) for v in sorted(lectura.vistas, key=lambda v: v.numero_serie)],
        sin_datos=len(res.sin_datos), excluidas_no_zebra=len(res.excluidas))


@router.post("/risk/printers/{printer_id}/refresh", response_model=RefreshRespuesta)
def refresh_printer(printer_id: str, admin: dict = Depends(require_admin), db: Session = Depends(get_db)) -> RefreshRespuesta:
    """Recalcula y guarda el riesgo de UNA impresora (síncrono, ~0.5 s)."""
    printer = db.get(Printer, printer_id)
    if printer is None or not printer.is_active:
        raise HTTPException(status_code=404, detail="Impresora no encontrada")
    respuesta = _refrescar(db, [printer_id], admin.get("sub"))
    if not respuesta.equipos:
        detalle = ("La estimación de riesgo no aplica a equipos que no son Zebra" if respuesta.excluidas_no_zebra
                   else "La impresora no tiene visitas registradas: no hay con qué estimar el riesgo")
        raise HTTPException(status_code=404, detail=detalle)
    return respuesta


@router.post("/policies/{policy_id}/risk/refresh", response_model=RefreshRespuesta)
def refresh_policy(policy_id: str, admin: dict = Depends(require_admin), db: Session = Depends(get_db)) -> RefreshRespuesta:
    """Recalcula y guarda el riesgo de las impresoras de UNA póliza (cada impresora se calcula una sola vez)."""
    policy = db.get(Policy, policy_id)
    if policy is None or policy.status == "Deleted":
        raise HTTPException(status_code=404, detail="Póliza no encontrada")
    ids = sorted(set(db.scalars(select(PolicyPrinter.printer_id).where(PolicyPrinter.policy_id == policy_id))))
    if not ids:
        raise HTTPException(status_code=404, detail="La póliza no tiene impresoras asignadas")
    return _refrescar(db, ids, admin.get("sub"))
