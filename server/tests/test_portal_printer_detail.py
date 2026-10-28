"""H-04: estadísticas del detalle de impresora calculadas en el servidor."""
import uuid
from datetime import timedelta

from app.models.report import Report
from tests.conftest import now
from tests.portal_helpers import make_portal_user, portal_headers


def _report(db, world, printer, days_ago, service_type="Preventivo", status="Signed"):
    r = Report(
        id=str(uuid.uuid4()), code=f"R-{uuid.uuid4().hex[:5]}", printer_id=printer.id,
        tech_id=world.tech.id, service_type=service_type, status=status,
        service_date=now() - timedelta(days=days_ago, hours=1),
        linear_inches_counter=100, technical_checkboxes="{}",
    )
    db.add(r)
    return r


def test_detalle_calcula_30_dias_sobre_todos_los_reportes_y_no_la_pagina(client, db, world):
    printer = world.printers[0]
    for i in range(12):                      # 12 Preventivo recientes (más que una página de 10)
        _report(db, world, printer, i + 1)
    for i in range(3):                       # 3 Correctivo recientes
        _report(db, world, printer, i + 1, service_type="Correctivo")
    _report(db, world, printer, 90)          # fuera de ventana
    _report(db, world, printer, 2, status="pending_delivery")
    _report(db, world, printer, 60, status="pending_delivery")  # pendiente fuera de ventana
    db.commit()

    user = make_portal_user(db, world.client_row.id)
    res = client.get(f"/api/portal/printers/{printer.id}", headers=portal_headers(db, user))
    assert res.status_code == 200, res.text
    body = res.json()
    assert body["reports_last_30d"] == 12 + 3 + 1
    assert body["most_frequent_service_type"] == "Preventivo"
    assert body["pending_delivery_count"] == 2


def test_detalle_sin_reportes(client, db, world):
    user = make_portal_user(db, world.client_row.id)
    body = client.get(
        f"/api/portal/printers/{world.printers[1].id}", headers=portal_headers(db, user)
    ).json()
    assert body["reports_last_30d"] == 0
    assert body["most_frequent_service_type"] is None
    assert body["pending_delivery_count"] == 0
