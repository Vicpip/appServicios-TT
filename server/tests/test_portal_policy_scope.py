"""H-12: un usuario del portal restringido a una planta solo ve su parte de la póliza."""
import uuid
from datetime import timedelta

from app.models.policy import Policy, PolicyDelivery, PolicyDeliveryReport, PolicyPrinter
from tests.conftest import now
from tests.portal_helpers import add_plant_b_printer, make_portal_user, portal_headers


def _delivery(db, world, policy, reports, pdf="policy/x.pdf"):
    d = PolicyDelivery(
        id=str(uuid.uuid4()), policy_id=policy.id, delivery_date=now(),
        signature_name="Firma", signature_role="Jefe", tech_id=world.tech.id, pdf_path=pdf,
    )
    db.add(d)
    db.flush()
    for r in reports:
        db.add(PolicyDeliveryReport(id=str(uuid.uuid4()), delivery_id=d.id, report_id=r.id))
    db.commit()
    return d


class Scenario:
    """Póliza con 3 equipos en planta A (World) y 1 en planta B; 3 entregas:
    solo A, mixta (A+B) y solo B."""

    def __init__(self, db, world):
        self.plant_b, self.printer_b = add_plant_b_printer(db, world)
        db.add(PolicyPrinter(id=str(uuid.uuid4()), policy_id=world.policy.id,
                             printer_id=self.printer_b.id))
        db.commit()
        self.r_a = world.add_report(world.printers[0], "Signed", "RA")
        self.r_a2 = world.add_report(world.printers[1], "Signed", "RA2")
        self.r_b = world.add_report(self.printer_b, "Signed", "RB")
        self.d_a = _delivery(db, world, world.policy, [self.r_a, self.r_a2], "policy/a.pdf")
        self.d_mixta = _delivery(db, world, world.policy, [self.r_a, self.r_b], "policy/m.pdf")
        self.d_b = _delivery(db, world, world.policy, [self.r_b], "policy/b.pdf")
        self.user_a = make_portal_user(db, world.client_row.id, plant_id=world.printers[0].plant_id)
        self.user_full = make_portal_user(db, world.client_row.id)


def test_detalle_solo_equipos_de_su_planta(client, db, world):
    sc = Scenario(db, world)
    res = client.get(f"/api/portal/policies/{world.policy.id}", headers=portal_headers(db, sc.user_a))
    assert res.status_code == 200, res.text
    body = res.json()
    assert {p["id"] for p in body["printers"]} == {p.id for p in world.printers}
    assert body["printer_count"] == 3
    # entregas: la de solo B se oculta; la mixta cuenta solo reportes de A y no expone el PDF
    by_id = {d["id"]: d for d in body["deliveries"]}
    assert set(by_id) == {sc.d_a.id, sc.d_mixta.id}
    assert by_id[sc.d_a.id]["report_count"] == 2
    assert by_id[sc.d_mixta.id]["report_count"] == 1
    assert by_id[sc.d_mixta.id]["pdf_path"] is None and by_id[sc.d_mixta.id]["pdf_url"] is None
    assert by_id[sc.d_a.id]["pdf_url"] is not None


def test_entrega_filtra_reportes_y_oculta_las_ajenas(client, db, world):
    sc = Scenario(db, world)
    h = portal_headers(db, sc.user_a)
    base = f"/api/portal/policies/{world.policy.id}/deliveries"

    mixta = client.get(f"{base}/{sc.d_mixta.id}", headers=h)
    assert mixta.status_code == 200
    assert [r["serial_number"] for r in mixta.json()["reports"]] == ["SN-001"]
    assert mixta.json()["report_count"] == 1

    assert client.get(f"{base}/{sc.d_b.id}", headers=h).status_code == 404


def test_usuario_de_planta_b_ve_su_parte(client, db, world):
    sc = Scenario(db, world)
    user_b = make_portal_user(db, world.client_row.id, plant_id=sc.plant_b.id)
    h = portal_headers(db, user_b)
    body = client.get(f"/api/portal/policies/{world.policy.id}", headers=h).json()
    assert [p["id"] for p in body["printers"]] == [sc.printer_b.id]
    assert {d["id"] for d in body["deliveries"]} == {sc.d_mixta.id, sc.d_b.id}
    assert next(d for d in body["deliveries"] if d["id"] == sc.d_b.id)["pdf_url"] is not None


def test_usuario_sin_planta_no_cambia(client, db, world):
    sc = Scenario(db, world)
    h = portal_headers(db, sc.user_full)
    body = client.get(f"/api/portal/policies/{world.policy.id}", headers=h).json()
    assert body["printer_count"] == 4
    assert len(body["deliveries"]) == 3
    assert all(d["pdf_url"] for d in body["deliveries"])
    mixta = client.get(
        f"/api/portal/policies/{world.policy.id}/deliveries/{sc.d_mixta.id}", headers=h
    ).json()
    assert len(mixta["reports"]) == 2


def test_listado_solo_polizas_con_equipo_en_su_planta(client, db, world):
    sc = Scenario(db, world)
    # póliza solo con equipo en planta B
    only_b = Policy(
        id=str(uuid.uuid4()), code="P-B", client_id=world.client_row.id, folio="POL-B",
        start_date=now() - timedelta(days=5), end_date=now() + timedelta(days=200),
        coverage_type="Integral", status="Active", frequency_maintenance="Anual",
    )
    db.add(only_b)
    db.flush()
    db.add(PolicyPrinter(id=str(uuid.uuid4()), policy_id=only_b.id, printer_id=sc.printer_b.id))
    db.commit()

    items_a = client.get("/api/portal/policies", headers=portal_headers(db, sc.user_a)).json()
    assert [i["folio"] for i in items_a] == [world.policy.folio]
    assert items_a[0]["printer_count"] == 3

    items_full = client.get("/api/portal/policies", headers=portal_headers(db, sc.user_full)).json()
    assert {i["folio"]: i["printer_count"] for i in items_full} == {"POL-2026-001": 4, "POL-B": 1}

    # detalle de póliza sin equipos en su planta: 404, y no cuenta en el dashboard
    assert client.get(f"/api/portal/policies/{only_b.id}", headers=portal_headers(db, sc.user_a)).status_code == 404
    dash_a = client.get("/api/portal/dashboard", headers=portal_headers(db, sc.user_a)).json()
    dash_full = client.get("/api/portal/dashboard", headers=portal_headers(db, sc.user_full)).json()
    assert dash_a["active_policies"] == 1 and dash_full["active_policies"] == 2
