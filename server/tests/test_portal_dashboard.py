"""H-05: GET /api/portal/dashboard agrega en SQL sin el tope de 100 reportes."""
import uuid
from collections import Counter
from datetime import datetime, timedelta

from app.models.policy import Policy
from app.models.report import Report
from tests.conftest import now
from tests.portal_helpers import add_plant_b_printer, make_portal_user, portal_headers


def _bulk_reports(db, world, printer, dates, service_type="Preventivo"):
    db.add_all([
        Report(
            id=str(uuid.uuid4()), code=f"R-{uuid.uuid4().hex[:6]}", printer_id=printer.id,
            tech_id=world.tech.id, service_type=service_type, status="Signed",
            service_date=d, linear_inches_counter=1, technical_checkboxes="{}",
        )
        for d in dates
    ])
    db.commit()


def test_dashboard_con_mas_de_100_reportes(client, db, world):
    n = now()
    dates = [n - timedelta(days=i * 3) for i in range(130)]  # ~13 meses atrás
    _bulk_reports(db, world, world.printers[0], dates)
    _bulk_reports(db, world, world.printers[1], [n - timedelta(days=1)] * 5, "Correctivo")

    user = make_portal_user(db, world.client_row.id)
    res = client.get("/api/portal/dashboard", headers=portal_headers(db, user))
    assert res.status_code == 200, res.text
    body = res.json()

    all_dates = dates + [n - timedelta(days=1)] * 5
    assert len(body["reports_by_month"]) == 12
    assert (body["reports_by_month"][-1]["year"], body["reports_by_month"][-1]["month"]) == (n.year, n.month)
    first = body["reports_by_month"][0]
    window_start = datetime(first["year"], first["month"], 1)
    expected = Counter((d.year, d.month) for d in all_dates if d >= window_start)
    got = {(m["year"], m["month"]): m["total"] for m in body["reports_by_month"]}
    assert got == {k: expected.get(k, 0) for k in got}
    assert sum(got.values()) == sum(expected.values()) > 100

    assert body["reports_year"] == sum(1 for d in all_dates if d.year == n.year)
    assert {t["service_type"]: t["total"] for t in body["reports_by_type"]} == {
        "Preventivo": 130, "Correctivo": 5,
    }
    assert body["printers_count"] == 3


def test_dashboard_polizas_vencidas_no_cuentan(client, db, world):
    db.add(Policy(
        id=str(uuid.uuid4()), code="P-OLD", client_id=world.client_row.id, folio="POL-OLD",
        start_date=now() - timedelta(days=400), end_date=now() - timedelta(days=5),
        coverage_type="Integral", status="Active", frequency_maintenance="Semestral",
    ))
    db.add(Policy(
        id=str(uuid.uuid4()), code="P-DEL", client_id=world.client_row.id, folio="POL-DEL",
        start_date=now() - timedelta(days=10), end_date=now() + timedelta(days=100),
        coverage_type="Integral", status="Deleted", frequency_maintenance="Semestral",
    ))
    db.commit()
    user = make_portal_user(db, world.client_row.id)
    body = client.get("/api/portal/dashboard", headers=portal_headers(db, user)).json()
    assert body["active_policies"] == 1  # solo la póliza vigente del World


def test_dashboard_respeta_alcance_de_planta_y_vacio(client, db, world):
    plant_b, printer_b = add_plant_b_printer(db, world)
    _bulk_reports(db, world, printer_b, [now() - timedelta(days=2)] * 4)
    _bulk_reports(db, world, world.printers[0], [now() - timedelta(days=2)] * 2)

    plant_a_user = make_portal_user(db, world.client_row.id, plant_id=world.printers[0].plant_id)
    body = client.get("/api/portal/dashboard", headers=portal_headers(db, plant_a_user)).json()
    two_days_ago = now() - timedelta(days=2)
    assert body["reports_year"] == (2 if two_days_ago.year == now().year else 0)
    assert sum(t["total"] for t in body["reports_by_type"]) == 2
    assert body["printers_count"] == 3

    plant_b_user = make_portal_user(db, world.client_row.id, plant_id=plant_b.id)
    body_b = client.get("/api/portal/dashboard", headers=portal_headers(db, plant_b_user)).json()
    assert sum(t["total"] for t in body_b["reports_by_type"]) == 4
    assert body_b["printers_count"] == 1


def test_dashboard_requiere_token_de_portal(client, admin_headers):
    assert client.get("/api/portal/dashboard").status_code in (401, 403)
    assert client.get("/api/portal/dashboard", headers=admin_headers).status_code == 403
