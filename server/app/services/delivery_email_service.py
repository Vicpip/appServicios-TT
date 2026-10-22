"""Correo único por entrega de póliza, con ligas a los PDFs.

Flujo de sincronización de la app: reportes -> entregas -> archivos (firma y
PDFs de cada reporte). Por eso el correo NO sale al crear la entrega: se evalúa
cada vez que llega un archivo relacionado (firma de la entrega o PDF de uno de
sus reportes) y sale solo cuando existe todo lo que se va a ligar. Es
idempotente: ``policy_deliveries.email_sent_at`` se reclama con un UPDATE
atómico antes de enviar.
"""
import logging
from dataclasses import dataclass, field
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.models.catalog import CatalogModel
from app.models.client import Client
from app.models.client_contact_email import ClientContactEmail
from app.models.file import EntityFile
from app.models.policy import Policy, PolicyDelivery, PolicyDeliveryReport
from app.models.printer import Printer
from app.models.report import Report
from app.models.share_link import TARGET_DELIVERY_PDF, TARGET_REPORT_PDF
from app.services import share_link_service as links
from app.services.email_service import send_delivery_email

log = logging.getLogger(__name__)

SENT = "sent"
ALREADY_SENT = "already_sent"
DEFERRED = "deferred"
NO_RECIPIENTS = "no_recipients"
NOT_FOUND = "not_found"
FAILED = "failed"


@dataclass
class DeliveryEmailResult:
    status: str
    sent_to: list[str] = field(default_factory=list)
    missing: list[str] = field(default_factory=list)


def _now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def dedupe_emails(*groups: list[str | None]) -> list[str]:
    """Une listas de correos sin duplicados (sin distinguir mayúsculas), en orden."""
    seen: set[str] = set()
    out: list[str] = []
    for group in groups:
        for email in group:
            if not email:
                continue
            email = email.strip()
            key = email.lower()
            if email and key not in seen:
                seen.add(key)
                out.append(email)
    return out


def collect_delivery_recipients(db: Session, delivery: PolicyDelivery) -> list[str]:
    """Correos activos del cliente de la póliza + correo adicional de la entrega."""
    policy = db.get(Policy, delivery.policy_id)
    contacts: list[str] = []
    if policy:
        contacts = [
            row.email
            for row in db.query(ClientContactEmail)
            .filter(
                ClientContactEmail.client_id == policy.client_id,
                ClientContactEmail.is_active.is_(True),
            )
            .order_by(ClientContactEmail.created_at)
            .all()
        ]
    return dedupe_emails(contacts, [delivery.extra_email])


def _delivery_reports(db: Session, delivery_id: str) -> list[Report]:
    rows = (
        db.query(PolicyDeliveryReport)
        .filter(PolicyDeliveryReport.delivery_id == delivery_id)
        .all()
    )
    reports = [db.get(Report, r.report_id) for r in rows]
    return sorted((r for r in reports if r), key=lambda r: r.service_date)


def delivery_readiness(db: Session, delivery: PolicyDelivery) -> list[str]:
    """Lo que aún falta para poder enviar (lista vacía = listo)."""
    missing: list[str] = []
    has_signature = (
        db.query(EntityFile.id)
        .filter(
            EntityFile.entity_id == delivery.id, EntityFile.entity_type == "signature"
        )
        .first()
        is not None
    )
    if not has_signature:
        missing.append("firma de la entrega")
    if links.delivery_pdf_path(db, delivery.id) is None:
        missing.append("PDF de resumen de la entrega")
    for report in _delivery_reports(db, delivery.id):
        if links.report_pdf_path(db, report.id) is None:
            missing.append(f"PDF del reporte {report.code or report.id}")
    return missing


def _build_and_send(
    db: Session, delivery: PolicyDelivery, recipients: list[str], regenerate: bool
) -> bool:
    policy = db.get(Policy, delivery.policy_id)
    client = db.get(Client, policy.client_id) if policy else None

    get_link = links.regenerate_link if regenerate else links.get_or_create_active_link
    summary_link = get_link(db, TARGET_DELIVERY_PDF, delivery.id)

    equipment = []
    for report in _delivery_reports(db, delivery.id):
        printer = db.get(Printer, report.printer_id) if report.printer_id else None
        model = (
            db.get(CatalogModel, printer.model_id) if printer and printer.model_id else None
        )
        url = None
        if links.report_pdf_path(db, report.id) is not None:
            url = links.link_url(get_link(db, TARGET_REPORT_PDF, report.id))
        equipment.append(
            {
                "model": f"{model.brand} {model.model_name}" if model else "-",
                "serial": printer.serial_number if printer else "-",
                "service_type": report.service_type,
                "url": url,
            }
        )
    db.commit()  # persiste las ligas creadas/regeneradas

    return send_delivery_email(
        to_emails=recipients,
        client_name=client.name if client else "",
        policy_folio=policy.folio if policy else delivery.policy_id,
        delivery_date=delivery.delivery_date.strftime("%d/%m/%Y")
        if delivery.delivery_date
        else "",
        signer_name=delivery.signature_name,
        signer_role=delivery.signature_role,
        equipment=equipment,
        summary_url=links.link_url(summary_link),
        expire_days=links.link_expire_days(),
    )


def send_delivery_email_for(
    db: Session,
    delivery_id: str,
    *,
    force: bool = False,
    regenerate_links: bool = False,
) -> DeliveryEmailResult:
    """Envía el correo único de la entrega.

    Automático (``force=False``): solo si no se envió antes y están todos los
    PDFs; si falta algo, queda diferido (``DEFERRED``) y se reintenta cuando
    llegue el siguiente archivo. Manual (``force=True``, botón del admin web):
    reenvía aunque ya se haya enviado y solo exige el PDF de resumen; los
    reportes sin PDF salen sin liga.
    """
    delivery = db.get(PolicyDelivery, delivery_id)
    if delivery is None:
        return DeliveryEmailResult(NOT_FOUND)

    if force:
        if links.delivery_pdf_path(db, delivery.id) is None:
            return DeliveryEmailResult(DEFERRED, missing=["PDF de resumen de la entrega"])
    else:
        if delivery.email_sent_at is not None:
            return DeliveryEmailResult(ALREADY_SENT)
        missing = delivery_readiness(db, delivery)
        if missing:
            log.info("delivery email %s diferido, falta: %s", delivery.id, missing)
            return DeliveryEmailResult(DEFERRED, missing=missing)

    recipients = collect_delivery_recipients(db, delivery)
    if not recipients:
        log.info("delivery email %s: sin destinatarios", delivery.id)
        return DeliveryEmailResult(NO_RECIPIENTS)

    previous = delivery.email_sent_at
    if not force:
        # Reclamo atómico: si dos archivos llegan a la vez, solo uno envía.
        claimed = (
            db.query(PolicyDelivery)
            .filter(PolicyDelivery.id == delivery.id, PolicyDelivery.email_sent_at.is_(None))
            .update({"email_sent_at": _now()}, synchronize_session=False)
        )
        db.commit()
        if not claimed:
            return DeliveryEmailResult(ALREADY_SENT)

    try:
        ok = _build_and_send(db, delivery, recipients, regenerate_links)
    except Exception:  # noqa: BLE001
        log.exception("delivery email %s: error armando el correo", delivery.id)
        ok = False

    db.refresh(delivery)
    if ok:
        delivery.email_sent_at = _now()
        db.commit()
        return DeliveryEmailResult(SENT, sent_to=recipients)

    # Falló el SMTP: se libera el reclamo para que un próximo archivo (o el
    # botón manual) pueda reintentar.
    delivery.email_sent_at = previous if force else None
    db.commit()
    return DeliveryEmailResult(FAILED, sent_to=[])


def trigger_for_delivery(db: Session, delivery_id: str) -> None:
    """Disparo automático no fatal (nunca rompe la petición que lo origina)."""
    try:
        result = send_delivery_email_for(db, delivery_id)
        if result.status != DEFERRED:
            log.info("delivery email %s -> %s", delivery_id, result.status)
    except Exception:  # noqa: BLE001
        db.rollback()
        log.exception("delivery email %s: fallo no fatal", delivery_id)


def trigger_for_report_pdf(db: Session, report_id: str) -> None:
    """Llegó el PDF de un reporte: reintenta las entregas que lo contienen."""
    ids = [
        row[0]
        for row in db.query(PolicyDeliveryReport.delivery_id)
        .filter(PolicyDeliveryReport.report_id == report_id)
        .all()
    ]
    for delivery_id in ids:
        trigger_for_delivery(db, delivery_id)


def report_in_policy_delivery(db: Session, report_id: str) -> bool:
    return (
        db.query(PolicyDeliveryReport.id)
        .filter(PolicyDeliveryReport.report_id == report_id)
        .first()
        is not None
    )
