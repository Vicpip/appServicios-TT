"""Regla automática de cierre de visita y botón "Cerrar visita"."""
import uuid

from datetime import date, timedelta

from app.models.policy import PolicyVisit


def _post_delivery(client, headers, world, reports, visit=None, extra_email=None):
    body = {
        "id": str(uuid.uuid4()),
        "policy_id": world.policy.id,
        "delivery_date": "2026-10-22T10:00:00",
        "signature_name": "Cliente Uno",
        "signature_role": "Compras",
        "tech_id": world.tech.id,
        "report_ids": [r.id for r in reports],
        "visit_id": (visit or world.visit1).id,
    }
    if extra_email is not None:
        body["extra_email"] = extra_email
    return client.post("/api/policy-deliveries", json=body, headers=headers)


def _visit(db, visit_id):
    db.expire_all()
    return db.get(PolicyVisit, visit_id)


# -- regla automática -------------------------------------------------------


def test_entrega_parcial_no_cierra_la_visita(client, world, db, tech_headers):
    r1 = world.add_report(world.printers[0])
    r2 = world.add_report(world.printers[1])
    assert _post_delivery(client, tech_headers, world, [r1, r2]).status_code == 201
    assert _visit(db, world.visit1.id).status == "in_progress"


def test_entrega_que_cubre_todos_cierra(client, world, db, tech_headers):
    reports = [world.add_report(p) for p in world.printers]
    assert _post_delivery(client, tech_headers, world, reports).status_code == 201
    v = _visit(db, world.visit1.id)
    assert v.status == "completed"
    assert v.completed_at is not None
    assert v.closed_at is None  # cierre automático, no manual


def test_dos_entregas_parciales_acumuladas_cierran(client, world, db, tech_headers):
    r1, r2, r3 = (world.add_report(p) for p in world.printers)
    _post_delivery(client, tech_headers, world, [r1, r2])
    assert _visit(db, world.visit1.id).status == "in_progress"
    _post_delivery(client, tech_headers, world, [r3])
    assert _visit(db, world.visit1.id).status == "completed"


def test_entrega_con_correo_adicional_invalido_se_rechaza(client, world, tech_headers):
    r1 = world.add_report(world.printers[0])
    res = _post_delivery(client, tech_headers, world, [r1], extra_email="no-es-correo")
    assert res.status_code == 422


# -- entregado = entrega -> visit_id -> reportes (sin comparar fechas) -------


def _visits_by_number(client, headers, world):
    res = client.get(f"/api/admin/policies/{world.policy.id}/visits", headers=headers)
    assert res.status_code == 200, res.text
    return {v["visit_number"]: v for v in res.json()}


def test_reporte_anterior_a_started_at_en_la_entrega_cuenta(client, world, db, tech_headers):
    # Caso H-27: service_date (hora local) menor que started_at (UTC).
    visit = _visit(db, world.visit1.id)
    reports = []
    for p in world.printers:
        r = world.add_report(p)
        r.service_date = visit.started_at - timedelta(hours=3)
        reports.append(r)
    db.commit()
    assert _post_delivery(client, tech_headers, world, reports).status_code == 201
    assert _visit(db, world.visit1.id).status == "completed"


def test_parcial_y_luego_completa_cierra_sola(client, world, db, tech_headers):
    r1 = world.add_report(world.printers[0])
    _post_delivery(client, tech_headers, world, [r1])
    assert _visit(db, world.visit1.id).status == "in_progress"
    r2, r3 = world.add_report(world.printers[1]), world.add_report(world.printers[2])
    _post_delivery(client, tech_headers, world, [r2, r3])
    assert _visit(db, world.visit1.id).status == "completed"


def test_entrega_sin_visit_id_no_cuenta(client, world, db, tech_headers):
    reports = [world.add_report(p) for p in world.printers]
    body = {
        "id": str(uuid.uuid4()), "policy_id": world.policy.id,
        "delivery_date": "2026-10-22T10:00:00", "signature_name": "Cliente Uno",
        "signature_role": "Compras", "tech_id": world.tech.id,
        "report_ids": [r.id for r in reports],
    }
    assert client.post("/api/policy-deliveries", json=body, headers=tech_headers).status_code == 201
    assert _visit(db, world.visit1.id).status == "in_progress"


def test_contador_no_baja_a_cero_al_firmar(client, world, admin_headers, tech_headers):
    r1, r2 = world.add_report(world.printers[0]), world.add_report(world.printers[1])
    v = _visits_by_number(client, admin_headers, world)[1]
    assert (v["attended_count"], v["delivered_count"]) == (2, 0)
    _post_delivery(client, tech_headers, world, [r1, r2])
    v = _visits_by_number(client, admin_headers, world)[1]
    assert (v["attended_count"], v["delivered_count"]) == (2, 2)
    assert v["total_printers"] == 3


def test_entrega_de_visita_anterior_no_cuenta_en_la_siguiente(
    client, world, db, admin_headers, tech_headers
):
    reports = [world.add_report(p) for p in world.printers]
    _post_delivery(client, tech_headers, world, reports)  # completa la visita 1
    assert _visit(db, world.visit1.id).status == "completed"
    url2 = f"/api/admin/policies/{world.policy.id}/visits/{world.visit2.id}"
    assert client.patch(url2, json={"status": "in_progress"}, headers=admin_headers).status_code == 200
    visits = _visits_by_number(client, admin_headers, world)
    assert visits[2]["attended_count"] == 0 and visits[2]["delivered_count"] == 0
    assert visits[1]["delivered_count"] == 3
    assert _visit(db, world.visit2.id).status == "in_progress"


# -- Cerrar visita ----------------------------------------------------------


def _close(client, headers, world, reason="Cliente canceló los equipos restantes", visit=None):
    v = visit or world.visit1
    return client.post(
        f"/api/admin/policies/{world.policy.id}/visits/{v.id}/close",
        json={"reason": reason},
        headers=headers,
    )


def test_cerrar_visita_con_motivo(client, world, db, admin_headers):
    res = _close(client, admin_headers, world)
    assert res.status_code == 200, res.text
    body = res.json()
    assert body["status"] == "completed"
    assert body["closed_reason"] == "Cliente canceló los equipos restantes"
    assert body["closed_by_name"] == world.admin.name
    v = _visit(db, world.visit1.id)
    assert v.closed_at is not None and v.closed_by == world.admin.id
    assert v.completed_at is not None


def test_cerrar_visita_exige_motivo(client, world, admin_headers):
    assert _close(client, admin_headers, world, reason="").status_code == 422
    assert _close(client, admin_headers, world, reason="   ").status_code == 422


def test_cerrar_visita_solo_admin(client, world, tech_headers):
    assert _close(client, tech_headers, world).status_code == 403


def test_cerrar_visita_requiere_login(client, world):
    res = client.post(
        f"/api/admin/policies/{world.policy.id}/visits/{world.visit1.id}/close",
        json={"reason": "x"},
    )
    assert res.status_code in (401, 403)


def test_cerrar_bloqueado_con_reportes_pending_delivery(client, world, db, admin_headers):
    world.add_report(world.printers[0], status="pending_delivery", code="R-777")
    res = _close(client, admin_headers, world)
    assert res.status_code == 409
    assert "pendiente" in res.json()["detail"] and "R-777" in res.json()["detail"]
    assert _visit(db, world.visit1.id).status == "in_progress"


def test_cerrar_visita_que_no_esta_en_curso(client, world, admin_headers):
    assert _close(client, admin_headers, world, visit=world.visit2).status_code == 409


def test_resumen_de_cierre(client, world, db, admin_headers, tech_headers):
    r1 = world.add_report(world.printers[0])
    assert _post_delivery(client, tech_headers, world, [r1]).status_code == 201
    world.add_report(world.printers[1], status="pending_delivery")
    res = client.get(
        f"/api/admin/policies/{world.policy.id}/visits/{world.visit1.id}/close-summary",
        headers=admin_headers,
    )
    assert res.status_code == 200
    s = res.json()
    assert s["total_printers"] == 3
    assert s["delivered_count"] == 1
    assert s["pending_delivery_count"] == 1
    assert s["without_report_count"] == 1
    assert s["can_close"] is False
    states = {e["serial_number"]: e["state"] for e in s["equipment"]}
    assert states == {"SN-001": "delivered", "SN-002": "pending_delivery", "SN-003": "without_report"}


def test_cerrar_permite_activar_la_siguiente(client, world, admin_headers):
    url2 = f"/api/admin/policies/{world.policy.id}/visits/{world.visit2.id}"
    # Mientras la 1 sigue en curso, no se puede activar la 2.
    assert client.patch(url2, json={"status": "in_progress"}, headers=admin_headers).status_code == 409
    assert _close(client, admin_headers, world).status_code == 200
    res = client.patch(url2, json={"status": "in_progress"}, headers=admin_headers)
    assert res.status_code == 200
    assert res.json()["status"] == "in_progress"


def test_visita_cerrada_no_se_reabre(client, world, db, admin_headers, tech_headers):
    assert _close(client, admin_headers, world).status_code == 200
    completed_at = _visit(db, world.visit1.id).completed_at
    url1 = f"/api/admin/policies/{world.policy.id}/visits/{world.visit1.id}"
    # PATCH manual
    assert client.patch(url1, json={"status": "in_progress"}, headers=admin_headers).status_code == 409
    assert client.patch(url1, json={"status": "scheduled"}, headers=admin_headers).status_code == 409
    # Regla automática: una entrega tardía ligada a la visita cerrada no la toca.
    reports = [world.add_report(p, status="pending_delivery") for p in world.printers]
    assert _post_delivery(client, tech_headers, world, reports).status_code == 201
    v = _visit(db, world.visit1.id)
    assert v.status == "completed"
    assert v.completed_at == completed_at
    assert v.closed_reason


def test_patch_no_permite_completar_sin_motivo(client, world, admin_headers):
    url1 = f"/api/admin/policies/{world.policy.id}/visits/{world.visit1.id}"
    assert client.patch(url1, json={"status": "completed"}, headers=admin_headers).status_code == 409


def test_descarga_incluye_cierre_para_la_app(client, world, admin_headers, tech_headers):
    _close(client, admin_headers, world, reason="Equipos retirados")
    data = client.get("/api/sync/download", headers=tech_headers).json()
    v = next(v for v in data["policyVisits"] if v["id"] == world.visit1.id)
    assert v["status"] == "completed"
    assert v["closedReason"] == "Equipos retirados"
    assert v["closedByName"] == world.admin.name
    assert v["closedAt"]


# -- H-28: fechas de las visitas generadas ------------------------------------

import pytest

from app.services.visit_schedule import add_months, visit_dates

ADMIN = "/api/admin"


def _generate(client, headers, world, start, end, frequency):
    """Crea una póliza con ese rango y frecuencia y genera sus visitas."""
    res = client.post(f"{ADMIN}/policies", json={
        "client_id": world.client_row.id, "folio": f"POL-T-{uuid.uuid4().hex[:6]}",
        "start_date": f"{start}T00:00:00", "end_date": f"{end}T00:00:00",
        "coverage_type": "Integral", "frequency_maintenance": frequency,
    }, headers=headers)
    assert res.status_code == 201, res.text
    pid = res.json()["id"]
    res = client.post(f"{ADMIN}/policies/{pid}/visits/generate", json={}, headers=headers)
    assert res.status_code == 201, res.text
    return pid, res.json()


@pytest.mark.parametrize("frequency, expected", [
    ("Mensual (12 visitas)", [
        "2026-10-27", "2026-11-27", "2026-12-27", "2027-01-27", "2027-02-27", "2027-03-27",
        "2027-04-27", "2027-05-27", "2027-06-27", "2027-07-27", "2027-08-27", "2027-09-27"]),
    ("Bimestral (6 visitas)", [
        "2026-10-27", "2026-12-27", "2027-02-27", "2027-04-27", "2027-06-27", "2027-08-27"]),
    ("Trimestral (4 visitas)", ["2026-10-27", "2027-01-27", "2027-04-27", "2027-07-27"]),
    ("Semestral (2 visitas)", ["2026-10-27", "2027-04-27"]),
    ("Anual (1 visita)", ["2026-10-27"]),
])
def test_visitas_por_frecuencia_desde_start_date(client, world, admin_headers, frequency, expected):
    _, visits = _generate(client, admin_headers, world, "2026-10-27", "2027-10-26", frequency)
    assert [v["scheduled_date"] for v in visits] == expected
    assert [v["visit_number"] for v in visits] == list(range(1, len(expected) + 1))
    assert {v["status"] for v in visits} == {"scheduled"}
    assert all(v["scheduled_date"] < "2027-10-26" for v in visits)     # antes del end_date


def test_visitas_fin_de_mes_no_encadenan(client, world, admin_headers):
    _, visits = _generate(client, admin_headers, world, "2026-01-31", "2027-01-30", "Mensual (12 visitas)")
    dates = [v["scheduled_date"] for v in visits]
    assert dates[:5] == ["2026-01-31", "2026-02-28", "2026-03-31", "2026-04-30", "2026-05-31"]
    assert dates[-1] == "2026-12-31"
    _, bim = _generate(client, admin_headers, world, "2026-01-31", "2027-01-30", "Bimestral (6 visitas)")
    # 31 ene -> 31 mar -> 31 may -> 31 jul -> 30 sep (sin 31) -> 30 nov
    assert [v["scheduled_date"] for v in bim] == [
        "2026-01-31", "2026-03-31", "2026-05-31", "2026-07-31", "2026-09-30", "2026-11-30"]


def test_visitas_anio_bisiesto(client, world, admin_headers):
    _, visits = _generate(client, admin_headers, world, "2028-02-29", "2029-02-27", "Trimestral (4 visitas)")
    assert [v["scheduled_date"] for v in visits] == ["2028-02-29", "2028-05-29", "2028-08-29", "2028-11-29"]
    _, visits = _generate(client, admin_headers, world, "2027-08-29", "2028-08-28", "Mensual (12 visitas)")
    dates = [v["scheduled_date"] for v in visits]
    assert dates[6] == "2028-02-29" and dates[5] == "2028-01-29"      # 2028 es bisiesto
    assert add_months(date(2028, 2, 29), 12) == date(2029, 2, 28)     # recorte al año no bisiesto


def test_visitas_anual_una_sola_en_start_date(client, world, admin_headers):
    _, visits = _generate(client, admin_headers, world, "2026-10-27", "2027-10-26", "Anual (1 visita)")
    assert len(visits) == 1 and visits[0]["scheduled_date"] == "2026-10-27"


def test_visitas_solo_antes_del_end_date():
    # Vigencia corta con frecuencia mensual: solo las fechas anteriores al fin
    assert visit_dates(date(2026, 1, 1), date(2026, 4, 1), 12) == [
        date(2026, 1, 1), date(2026, 2, 1), date(2026, 3, 1)]


def test_regenerar_conserva_guards(client, world, admin_headers):
    pid, _ = _generate(client, admin_headers, world, "2026-10-27", "2027-10-26", "Semestral (2 visitas)")
    # ya tiene visitas -> 409 hasta eliminarlas; luego regenera con la misma regla
    assert client.post(f"{ADMIN}/policies/{pid}/visits/generate", json={}, headers=admin_headers).status_code == 409
    assert client.delete(f"{ADMIN}/policies/{pid}/visits", headers=admin_headers).status_code == 200
    res = client.post(f"{ADMIN}/policies/{pid}/visits/generate", json={}, headers=admin_headers)
    assert [v["scheduled_date"] for v in res.json()] == ["2026-10-27", "2027-04-27"]
