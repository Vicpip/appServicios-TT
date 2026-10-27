"""Reglas de visitas de póliza compartidas por el sync, el admin y las pruebas."""
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.models.catalog import CatalogModel
from app.models.policy import (
    PolicyDelivery,
    PolicyDeliveryReport,
    PolicyPrinter,
    PolicyVisit,
)
from app.models.printer import Printer
from app.models.report import Report

PENDING_STATUS = "pending_delivery"


def _now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def policy_printer_ids(db: Session, policy_id: str) -> set[str]:
    return {
        pp.printer_id
        for pp in db.query(PolicyPrinter).filter(PolicyPrinter.policy_id == policy_id)
    }


def delivered_printer_ids(db: Session, visit: PolicyVisit) -> set[str]:
    """Equipos de la póliza entregados en la visita: impresoras de los reportes
    incluidos en las entregas con visit_id == visita (unión entre entregas
    parciales). No compara fechas; las entregas sin visit_id no cuentan."""
    printer_ids = policy_printer_ids(db, visit.policy_id)
    if not printer_ids:
        return set()
    rows = (
        db.query(Report.printer_id)
        .join(PolicyDeliveryReport, PolicyDeliveryReport.report_id == Report.id)
        .join(PolicyDelivery, PolicyDelivery.id == PolicyDeliveryReport.delivery_id)
        .filter(
            PolicyDelivery.visit_id == visit.id,
            Report.printer_id.in_(printer_ids),
        )
        .distinct()
        .all()
    )
    return {row[0] for row in rows}


def pending_delivery_reports(db: Session, policy_id: str) -> list[Report]:
    """Reportes pending_delivery de los equipos de la póliza."""
    printer_ids = policy_printer_ids(db, policy_id)
    if not printer_ids:
        return []
    return (
        db.query(Report)
        .filter(Report.printer_id.in_(printer_ids), Report.status == PENDING_STATUS)
        .all()
    )


def auto_complete_if_all_delivered(db: Session, visit: PolicyVisit) -> bool:
    """Regla automática: la visita en curso pasa a completed cuando TODOS los
    equipos de la póliza tienen reporte entregado dentro de la visita.

    Solo actúa sobre visitas in_progress: una visita ya completada (por esta
    regla o cerrada manualmente) NO se vuelve a tocar, así una entrega tardía
    no reescribe completed_at ni reabre nada.
    """
    if visit.status != "in_progress":
        return False
    printer_ids = policy_printer_ids(db, visit.policy_id)
    if printer_ids and printer_ids <= delivered_printer_ids(db, visit):
        visit.status = "completed"
        visit.completed_at = _now()
        return True
    return False


def _equipment_item(db: Session, printer_id: str, state: str, report: Report | None) -> dict:
    printer = db.get(Printer, printer_id)
    model = db.get(CatalogModel, printer.model_id) if printer and printer.model_id else None
    return {
        "printer_id": printer_id,
        "serial_number": printer.serial_number if printer else None,
        "model_name": f"{model.brand} {model.model_name}" if model else None,
        "state": state,  # delivered | pending_delivery | without_report
        "report_id": report.id if report else None,
        "report_code": report.code if report else None,
    }


def visit_close_summary(db: Session, visit: PolicyVisit) -> dict:
    """Resumen previo al cierre: qué equipos tienen reporte entregado y cuáles no."""
    printer_ids = policy_printer_ids(db, visit.policy_id)
    delivered = delivered_printer_ids(db, visit)
    pending_by_printer: dict[str, Report] = {}
    for r in pending_delivery_reports(db, visit.policy_id):
        pending_by_printer.setdefault(r.printer_id, r)

    items = []
    for pid in sorted(printer_ids):
        if pid in delivered:
            items.append(_equipment_item(db, pid, "delivered", None))
        elif pid in pending_by_printer:
            items.append(_equipment_item(db, pid, "pending_delivery", pending_by_printer[pid]))
        else:
            items.append(_equipment_item(db, pid, "without_report", None))

    pending_count = len(pending_delivery_reports(db, visit.policy_id))
    return {
        "visit_id": visit.id,
        "visit_number": visit.visit_number,
        "status": visit.status,
        "total_printers": len(printer_ids),
        "delivered_count": sum(1 for i in items if i["state"] == "delivered"),
        "pending_delivery_count": pending_count,
        "without_report_count": sum(1 for i in items if i["state"] == "without_report"),
        "can_close": visit.status == "in_progress" and pending_count == 0,
        "equipment": items,
    }
