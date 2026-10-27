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


# -- H-07 ---------------------------------------------------------------------

from app.models.printer import Printer
from app.models.report import Report


def _add_printers_with_reports(db, world, n, damaged_idx):
    """n impresoras más (SN-1xx); las de damaged_idx tienen el último reporte con rodillo dañado."""
    base = world.printers[0]
    for i in range(n):
        p = Printer(
            id=str(uuid.uuid4()), qr_uuid=str(uuid.uuid4()), serial_number=f"SN-1{i:02d}",
            client_id=world.client_row.id, plant_id=base.plant_id, area_id=base.area_id,
            model_id=base.model_id, is_active=True,
        )
        db.add(p)
        db.flush()
        db.add(Report(
            id=str(uuid.uuid4()), code=f"RX-{i:02d}", printer_id=p.id, tech_id=world.tech.id,
            service_type="Preventivo", status="Signed", service_date=now() - timedelta(hours=2),
            linear_inches_counter=1,
            technical_checkboxes='{"Rodillo dañado": %s}' % ("true" if i in damaged_idx else "false"),
        ))
    db.commit()


def test_filtro_estado_de_impresoras_antes_de_paginar(client, world, db, admin_headers):
    _add_printers_with_reports(db, world, 25, damaged_idx={3, 14, 24})
    url = f"{ADMIN}/printers?printer_status=En%20Atenci%C3%B3n"

    page1 = client.get(f"{url}&limit=2&offset=0", headers=admin_headers).json()
    page2 = client.get(f"{url}&limit=2&offset=2", headers=admin_headers).json()
    assert page1["total"] == page2["total"] == 3
    assert [i["serial_number"] for i in page1["items"]] == ["SN-103", "SN-114"]
    assert [i["serial_number"] for i in page2["items"]] == ["SN-124"]

    full = client.get(f"{url}&limit=20", headers=admin_headers).json()
    assert full["total"] == 3 and len(full["items"]) == 3
    assert {i["printer_status"] for i in full["items"]} == {"En Atención"}

    correcto = client.get(f"{ADMIN}/printers?printer_status=Correcto&limit=200", headers=admin_headers).json()
    assert correcto["total"] == 22 and len(correcto["items"]) == 22


def test_filtro_estado_de_polizas_antes_de_paginar(client, world, db, admin_headers):
    for i in range(6):
        _add_policy(db, world, f"POL-2026-5{i:02d}", 10 + i, status="Active")   # 6 por vencer
    for i in range(5):
        _add_policy(db, world, f"POL-2026-6{i:02d}", -1 - i, status="Active")   # 5 vencidas
    _add_policy(db, world, "POL-2026-700", 15, status="Deleted")                # eliminada: no cuenta

    def get(status, **params):
        qs = "&".join(f"{k}={v}" for k, v in {"status": status, **params}.items())
        return client.get(f"{ADMIN}/policies?{qs}", headers=admin_headers).json()

    p1, p2 = get("Expiring", limit=4, offset=0), get("Expiring", limit=4, offset=4)
    assert p1["total"] == p2["total"] == 6
    assert len(p1["items"]) == 4 and len(p2["items"]) == 2
    assert {i["status"] for i in p1["items"] + p2["items"]} == {"Expiring"}

    assert get("Expired", limit=200)["total"] == 5
    assert get("Active", limit=200)["total"] == 1                               # la del world
    assert client.get(f"{ADMIN}/policies?limit=1", headers=admin_headers).json()["total"] == 12
