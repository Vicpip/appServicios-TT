"""Ayudas para simular lo que hace la app móvil al sincronizar."""
import io
import uuid
from datetime import datetime, timedelta, timezone

from PIL import Image

from tests.conftest import PDF_BYTES


def png_bytes() -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (40, 20), "white").save(buf, format="PNG")
    return buf.getvalue()


def upload(client, headers, entity_type, entity_id, category, content=None, name="f.pdf"):
    """POST /api/files como la app (entity_type 'signature' o 'report')."""
    if content is None:
        content = PDF_BYTES + entity_id.encode() + uuid.uuid4().bytes  # evita el dedupe por hash
    ctype = "image/png" if name.endswith(".png") else "application/pdf"
    return client.post(
        "/api/files",
        data={"entity_type": entity_type, "entity_id": entity_id, "file_category": category},
        files={"file": (name, content, ctype)},
        headers=headers,
    )


def upload_signature(client, headers, delivery_id):
    res = upload(client, headers, "signature", delivery_id, "signature", png_bytes(), "sig.png")
    assert res.status_code == 200, res.text
    return res


def upload_report_pdf(client, headers, report_id):
    res = upload(client, headers, "report", report_id, "pdf")
    assert res.status_code == 200, res.text
    return res


def post_report(client, headers, world, printer, hours_ago=1):
    """POST /api/reports (reporte nuevo en pending_delivery, como lo sube la app)."""
    rid = str(uuid.uuid4())
    when = (datetime.now(timezone.utc) - timedelta(hours=hours_ago)).replace(tzinfo=None)
    res = client.post(
        "/api/reports",
        json={
            "id": rid, "code": f"R-{rid[:4]}", "printerId": printer.id,
            "techId": world.tech.id, "serviceType": "Preventivo",
            "status": "pending_delivery", "serviceDate": when.isoformat(),
            "linearInchesCounter": 10, "technicalCheckboxes": {},
        },
        headers=headers,
    )
    assert res.status_code == 200, res.text
    return rid


def post_delivery(client, headers, world, report_ids, visit=None, extra_email=None):
    delivery_id = str(uuid.uuid4())
    body = {
        "id": delivery_id, "policy_id": world.policy.id,
        "delivery_date": "2026-10-22T10:00:00", "signature_name": "Cliente Uno",
        "signature_role": "Compras", "tech_id": world.tech.id,
        "report_ids": report_ids, "visit_id": (visit or world.visit1).id,
    }
    if extra_email is not None:
        body["extra_email"] = extra_email
    res = client.post("/api/policy-deliveries", json=body, headers=headers)
    assert res.status_code == 201, res.text
    return delivery_id


def sync_delivery(client, headers, world, printers, visit=None, extra_email=None,
                  with_signature=True, with_pdfs=True):
    """Orden real de la app: reportes -> entrega -> firma -> PDFs de cada reporte."""
    report_ids = [post_report(client, headers, world, p) for p in printers]
    delivery_id = post_delivery(client, headers, world, report_ids, visit, extra_email)
    if with_signature:
        upload_signature(client, headers, delivery_id)
    if with_pdfs:
        for rid in report_ids:
            upload_report_pdf(client, headers, rid)
    return delivery_id, report_ids
