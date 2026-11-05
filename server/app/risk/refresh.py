"""Recalcula y guarda los snapshots de riesgo.   python -m app.risk.refresh --all | --printer <id>

Pensado para el timer diario de systemd (server/deploy/systemd/). Debe correr con WorkingDirectory=/opt/app/server:
la configuracion se lee de `.env` por ruta relativa. Solo escribe en `printer_risk_snapshots`; nunca en `reports`.
No imprime numeros de serie ni nombres de clientes: solo conteos.

Codigos de salida:  0 = listo | 1 = fallo (sin modelo, sin historial, error de base de datos, impresora inexistente)
                    2 = argumentos invalidos | 75 = otro refresh en curso (no se hizo nada; reintentar luego)
"""
import argparse
import logging
import sys
import time

from sqlalchemy.orm import Session

from app.risk import ModeloNoDisponible, snapshots
from app.models.printer import Printer

logger = logging.getLogger("app.risk.refresh")

EX_OK, EX_FALLO, EX_OCUPADO = 0, 1, 75


def ejecutar(db: Session, printer_id: str | None = None) -> int:
    """Refresca todas las impresoras (printer_id=None) o solo una. Devuelve el codigo de salida."""
    if printer_id is not None:
        printer = db.get(Printer, printer_id)
        if printer is None or not printer.is_active:
            logger.error("La impresora indicada no existe o esta inactiva")
            return EX_FALLO
    try:
        snapshots.bloquear(db)
    except snapshots.RefreshOcupado:
        db.rollback()
        logger.warning("Otro refresh de riesgo esta en curso; no se hizo nada")
        return EX_OCUPADO
    inicio = time.monotonic()
    try:
        res = snapshots.refrescar(db, None if printer_id is None else [printer_id], computed_by=None)
    except ModeloNoDisponible as e:
        db.rollback()
        logger.error("No se puede calcular el riesgo: %s", e)
        return EX_FALLO
    except Exception:
        db.rollback()
        logger.exception("Fallo inesperado al actualizar el riesgo")
        return EX_FALLO
    niveles = {"ALTO": 0, "MEDIO": 0, "BAJO": 0}
    for e in res.equipos:
        niveles[e["cabezal"]["nivel"]] += 1
    logger.info("Riesgo actualizado: %d impresora(s) calculada(s) (cabezal ALTO=%d MEDIO=%d BAJO=%d), %d sin visitas, "
                "%d no Zebra excluidas; %d fila(s) de snapshot eliminadas por no elegibles; modelo %s; %.1f s", len(res.equipos), niveles["ALTO"], niveles["MEDIO"],
                niveles["BAJO"], len(res.sin_datos), len(res.excluidas), res.eliminados, res.version_modelo, time.monotonic() - inicio)
    if printer_id is not None and not res.equipos:
        logger.error("La impresora indicada no tiene visitas o no aplica (no Zebra): no se calculo nada")
        return EX_FALLO
    return EX_OK


def main(argv: list[str] | None = None, session_factory=None) -> int:
    ap = argparse.ArgumentParser(prog="python -m app.risk.refresh", description=__doc__.split("\n")[0])
    grupo = ap.add_mutually_exclusive_group(required=True)
    grupo.add_argument("--all", action="store_true", help="todas las impresoras activas Zebra")
    grupo.add_argument("--printer", metavar="ID", help="solo la impresora con ese id")
    args = ap.parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    if session_factory is None:
        from app.database import SessionLocal as session_factory
    db = session_factory()
    try:
        return ejecutar(db, args.printer)
    finally:
        db.close()


if __name__ == "__main__":
    sys.exit(main())
