"""Regla automática de cierre de visita y botón "Cerrar visita"."""
import uuid

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


def test_resumen_de_cierre(client, world, admin_headers):
    world.add_report(world.printers[0], status="signed")
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
