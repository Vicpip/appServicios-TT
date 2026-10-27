"""Datos del admin: pólizas eliminadas, estado único, filtros y contadores (sesión 2)."""
from app.models.policy import Policy

ADMIN = "/api/admin"


def _delete_policy(client, headers, world):
    res = client.delete(f"{ADMIN}/policies/{world.policy.id}", headers=headers)
    assert res.status_code == 200, res.text


# -- H-08 ---------------------------------------------------------------------


def test_poliza_eliminada_sale_del_listado_y_da_404(client, world, admin_headers):
    pid = world.policy.id
    assert client.get(f"{ADMIN}/policies", headers=admin_headers).json()["total"] == 1
    _delete_policy(client, admin_headers, world)

    listing = client.get(f"{ADMIN}/policies", headers=admin_headers).json()
    assert listing["total"] == 0 and listing["items"] == []

    assert client.get(f"{ADMIN}/policies/{pid}", headers=admin_headers).status_code == 404
    assert client.put(f"{ADMIN}/policies/{pid}", json={"sla_notes": "x"}, headers=admin_headers).status_code == 404
    assert client.post(
        f"{ADMIN}/policies/{pid}/printers", json={"printer_ids": [world.printers[0].id]}, headers=admin_headers
    ).status_code == 404
    assert client.get(f"{ADMIN}/policies/{pid}/assignments", headers=admin_headers).status_code == 404
    assert client.get(f"{ADMIN}/policies/{pid}/visits", headers=admin_headers).status_code == 404
    assert client.post(f"{ADMIN}/policies/{pid}/visits/generate", json={}, headers=admin_headers).status_code == 404
    assert client.patch(
        f"{ADMIN}/policies/{pid}/visits/{world.visit1.id}", json={"status": "scheduled"}, headers=admin_headers
    ).status_code == 404
    assert client.delete(f"{ADMIN}/policies/{pid}/visits", headers=admin_headers).status_code == 404


def test_poliza_eliminada_no_se_elimina_dos_veces(client, world, admin_headers):
    _delete_policy(client, admin_headers, world)
    assert client.delete(f"{ADMIN}/policies/{world.policy.id}", headers=admin_headers).status_code == 409


def test_descarga_de_la_app_excluye_polizas_eliminadas(client, world, admin_headers, tech_headers):
    def ids():
        res = client.get("/api/sync/download", headers=tech_headers)
        assert res.status_code == 200, res.text
        return [p["id"] for p in res.json()["policies"]]

    assert world.policy.id in ids()
    _delete_policy(client, admin_headers, world)
    assert world.policy.id not in ids()


# -- H-09 ---------------------------------------------------------------------

import uuid
from datetime import timedelta

from app.api.routers.portal import _portal_token
from app.models.portal import PortalUser
from app.services.policy_status import policy_status
from tests.conftest import now


def _portal_headers_for(db, world):
    user = PortalUser(
        id=str(uuid.uuid4()), client_id=world.client_row.id, email="portal@vibra.test",
        password_hash="x", name="Portal", is_active=True,
    )
    db.add(user)
    db.commit()
    return {"Authorization": f"Bearer {_portal_token(user, db)}"}


def _add_policy(db, world, folio, end_offset_days, status="Active"):
    p = Policy(
        id=str(uuid.uuid4()), code=f"P-{folio[-3:]}", client_id=world.client_row.id, folio=folio,
        start_date=now() - timedelta(days=60), end_date=now() + timedelta(days=end_offset_days),
        coverage_type="Integral", status=status, frequency_maintenance="Anual",
    )
    db.add(p)
    db.commit()
    return p


def test_policy_status_por_end_date():
    assert policy_status(now() - timedelta(days=1)) == "Expired"
    assert policy_status(now() + timedelta(days=10)) == "Expiring"
    assert policy_status(now() + timedelta(days=90)) == "Active"


def test_admin_y_portal_coinciden_en_el_estado(client, world, db, admin_headers):
    # Guardada como "Active" pero ya vencida; y otra guardada "Expiring" con 10 días.
    vencida = _add_policy(db, world, "POL-2026-901", -1, status="Active")
    por_vencer = _add_policy(db, world, "POL-2026-902", 10, status="Expiring")
    eliminada = _add_policy(db, world, "POL-2026-903", 90, status="Deleted")

    admin = {
        p["folio"]: p["status"]
        for p in client.get(f"{ADMIN}/policies?limit=200", headers=admin_headers).json()["items"]
    }
    portal = {
        p["folio"]: p["status"]
        for p in client.get("/api/portal/policies", headers=_portal_headers_for(db, world)).json()
    }
    assert admin[vencida.folio] == portal[vencida.folio] == "Expired"
    assert admin[por_vencer.folio] == portal[por_vencer.folio] == "Expiring"
    assert admin[world.policy.folio] == portal[world.policy.folio] == "Active"
    assert eliminada.folio not in admin and eliminada.folio not in portal
    assert admin.keys() == portal.keys()


def test_portal_detalle_de_poliza_eliminada_da_404(client, world, db, admin_headers):
    headers = _portal_headers_for(db, world)
    assert client.get(f"/api/portal/policies/{world.policy.id}", headers=headers).json()["status"] == "Active"
    client.delete(f"{ADMIN}/policies/{world.policy.id}", headers=admin_headers)
    assert client.get(f"/api/portal/policies/{world.policy.id}", headers=headers).status_code == 404


def test_contador_de_polizas_activas_usa_end_date(client, world, db, admin_headers):
    _add_policy(db, world, "POL-2026-901", -1, status="Active")   # vencida, guardada Active
    _add_policy(db, world, "POL-2026-902", 10, status="Expiring")  # vigente, guardada Expiring
    _add_policy(db, world, "POL-2026-903", 90, status="Deleted")   # eliminada
    item = client.get(f"{ADMIN}/clients", headers=admin_headers).json()["items"][0]
    assert item["active_policy_count"] == 2  # la de world + la que vence en 10 días
