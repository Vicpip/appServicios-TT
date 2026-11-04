"""Riesgo de piezas (cabezal y rodillo) — solo admin, solo lectura. Calcula al vuelo; sin persistencia.

Los handlers son `def` (no `async def`) para que FastAPI los corra en un hilo y no bloqueen el proceso de uvicorn.
"""
import logging
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.auth import require_admin
from app.database import get_db
from app.risk import HistorialNoDisponible, ModeloNoDisponible, service
from app.schemas.risk import EquipoRiesgo, ModeloInfo, RiesgoListado

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/admin/risk", tags=["risk"], dependencies=[Depends(require_admin)])

_NIVELES = {"ALTO": 0, "MEDIO": 1, "BAJO": 2}


def _no_disponible(e: ModeloNoDisponible) -> HTTPException:
    logger.warning("Riesgo no disponible: %s", e)    # la causa (rutas, versiones) va al log, no al cliente
    if isinstance(e, HistorialNoDisponible):         # este mensaje esta escrito para el administrador y no lleva rutas
        return HTTPException(status_code=503, detail=str(e))
    return HTTPException(status_code=503, detail="Modelo de riesgo no disponible. Intenta más tarde o avisa al administrador del sistema.")


def _equipo(fila: dict, aviso: str) -> EquipoRiesgo:
    return EquipoRiesgo(
        printer_id=fila["printer_id"], client_id=fila["client_id"], numero_serie=fila["numero_serie"],
        modelo_impresora=fila["modelo_impresora"], fecha_ultima_visita=fila["fecha_ultima_visita"],
        vigente_hasta=fila["vigente_hasta"], vigente=fila["vigente"], visitas_registradas=fila["visitas_registradas"],
        visitas_app=fila["visitas_app"], visitas_historicas=fila["visitas_historicas"],
        historial_corto=fila["historial_corto"],
        cabezal=fila["cabezal"], rodillo={**fila["rodillo"], "en_monitoreo": True}, aviso=aviso)


@router.get("/model/info", response_model=ModeloInfo)
def model_info() -> ModeloInfo:
    """Version, fecha de entrenamiento y metricas del modelo cargado."""
    try:
        return ModeloInfo(**service.informacion())
    except ModeloNoDisponible as e:
        raise _no_disponible(e)


@router.get("/printers", response_model=RiesgoListado)
def list_printers(
    level: Literal["ALTO", "MEDIO", "BAJO"] | None = Query(None, description="Nivel de la pieza"),
    piece: Literal["cabezal", "rodillo"] | None = Query(None, description="Pieza; sin ella, level aplica a cualquiera"),
    client_id: str | None = Query(None),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
) -> RiesgoListado:
    """Riesgo de las impresoras activas Zebra, de mayor a menor. Calcula al vuelo."""
    try:
        res = service.calcular(db, client_id=client_id)
    except ModeloNoDisponible as e:
        raise _no_disponible(e)
    piezas = (piece,) if piece else ("cabezal", "rodillo")
    equipos = [f for f in res.equipos if level is None or any(f[p]["nivel"] == level for p in piezas)]
    # Orden: mayor indice de riesgo primero (de la pieza pedida o del maximo de las dos); serie para desempatar.
    equipos.sort(key=lambda f: (-max(f[p]["indice_riesgo"] for p in piezas), f["numero_serie"]))
    return RiesgoListado(
        total=len(equipos), version_modelo=res.version_modelo, horizonte_dias=res.horizonte_dias, aviso=res.aviso,
        equipos=[_equipo(f, res.aviso) for f in equipos[:limit]],
        excluidas_no_zebra=len(res.excluidas), sin_visitas=len(res.sin_datos))


@router.get("/printers/{printer_id}", response_model=EquipoRiesgo)
def get_printer(printer_id: str, db: Session = Depends(get_db)) -> EquipoRiesgo:
    """Riesgo de una impresora. 404 si no existe, esta inactiva, no es Zebra o no tiene visitas."""
    try:
        res = service.calcular(db, [printer_id])
    except ModeloNoDisponible as e:
        raise _no_disponible(e)
    for f in res.equipos:
        return _equipo(f, res.aviso)
    if res.excluidas:
        raise HTTPException(status_code=404, detail="La estimación de riesgo no aplica a equipos que no son Zebra")
    raise HTTPException(status_code=404, detail="Impresora no encontrada o sin visitas registradas")
