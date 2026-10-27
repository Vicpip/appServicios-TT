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
