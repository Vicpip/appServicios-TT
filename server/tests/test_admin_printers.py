"""H-15: desactivar impresoras, listado de inactivas y conteos."""
import uuid
from datetime import timedelta

from app.models.policy import Policy, PolicyPrinter
from app.models.printer import Printer

from tests.conftest import now


def _printer(db, world, serial, active=True):
    base = world.printers[0]
    p = Printer(
        id=str(uuid.uuid4()), qr_uuid=str(uuid.uuid4()), serial_number=serial,
        client_id=base.client_id, plant_id=base.plant_id, area_id=base.area_id,
        model_id=base.model_id, is_active=active,
    )
    db.add(p)
    db.commit()
    return p


def _list(client, headers, **params):
    res = client.get("/api/admin/printers", params={"limit": 200, **params}, headers=headers)
    assert res.status_code == 200, res.text
    return res.json()


def _policy(db, world, folio, end_in_days, status="Active", printer=None):
    pol = Policy(
        id=str(uuid.uuid4()), code=f"P-{uuid.uuid4().hex[:4]}", client_id=world.client_row.id,
        folio=folio, start_date=now() - timedelta(days=400),
        end_date=now() + timedelta(days=end_in_days), coverage_type="Integral",
        status=status, frequency_maintenance="Anual",
    )
    db.add(pol)
    db.flush()
    db.add(PolicyPrinter(id=str(uuid.uuid4()), policy_id=pol.id, printer_id=printer.id))
    db.commit()
    return pol


# -- desactivar ----------------------------------------------------------------


def test_desactivar_impresora_en_poliza_vigente_da_409_con_folio(client, world, db, admin_headers):
    res = client.delete(f"/api/admin/printers/{world.printers[0].id}", headers=admin_headers)
    assert res.status_code == 409
    assert "POL-2026-001" in res.json()["detail"]
    db.expire_all()
    assert db.get(Printer, world.printers[0].id).is_active is True


def test_desactivar_impresora_sin_poliza_ok_aunque_tenga_reportes(client, world, db, admin_headers):
    p = _printer(db, world, "SN-LIBRE")
    world.add_report(p)
    assert client.delete(f"/api/admin/printers/{p.id}", headers=admin_headers).status_code == 200
    db.expire_all()
    assert db.get(Printer, p.id).is_active is False


def test_desactivar_con_poliza_vencida_ok(client, world, db, admin_headers):
    p = _printer(db, world, "SN-VENCIDA")
    _policy(db, world, "POL-VENCIDA", end_in_days=-5, printer=p)
    assert client.delete(f"/api/admin/printers/{p.id}", headers=admin_headers).status_code == 200


def test_desactivar_con_poliza_eliminada_ok(client, world, db, admin_headers):
    p = _printer(db, world, "SN-ELIM")
    _policy(db, world, "POL-ELIM", end_in_days=200, status="Deleted", printer=p)
    assert client.delete(f"/api/admin/printers/{p.id}", headers=admin_headers).status_code == 200


def test_desactivar_con_poliza_por_vencer_da_409(client, world, db, admin_headers):
    p = _printer(db, world, "SN-POR-VENCER")
    _policy(db, world, "POL-PORVENCER", end_in_days=10, printer=p)
    res = client.delete(f"/api/admin/printers/{p.id}", headers=admin_headers)
    assert res.status_code == 409
    assert "POL-PORVENCER" in res.json()["detail"]


# -- listado -------------------------------------------------------------------


def test_listado_oculta_inactivas_por_defecto(client, world, db, admin_headers):
    _printer(db, world, "SN-INACTIVA", active=False)
    data = _list(client, admin_headers)
    assert "SN-INACTIVA" not in {i["serial_number"] for i in data["items"]}
    assert data["total"] == 3
    assert all(i["is_active"] is True for i in data["items"])


def test_listado_incluye_inactivas_con_flag(client, world, db, admin_headers):
    _printer(db, world, "SN-INACTIVA", active=False)
    data = _list(client, admin_headers, include_inactive="true")
    by_serial = {i["serial_number"]: i["is_active"] for i in data["items"]}
    assert by_serial["SN-INACTIVA"] is False
    assert data["total"] == 4


def test_listado_filtro_en_atencion_no_cuenta_inactivas(client, world, db, admin_headers):
    p = _printer(db, world, "SN-ATENCION", active=False)
    r = world.add_report(p)
    r.technical_checkboxes = '{"Cabezal dañado": true}'
    db.commit()
    for params in ({"printer_status": "En Atención"}, {"printer_status": "En Atención", "include_inactive": "true"}):
        data = _list(client, admin_headers, **params)
        seriales = {i["serial_number"] for i in data["items"]}
        assert ("SN-ATENCION" in seriales) == bool(params.get("include_inactive"))


def test_conteo_de_impresoras_del_cliente_excluye_inactivas(client, world, db, admin_headers):
    _printer(db, world, "SN-INACTIVA", active=False)
    res = client.get("/api/admin/clients", params={"limit": 50}, headers=admin_headers)
    assert res.status_code == 200
    row = next(c for c in res.json()["items"] if c["id"] == world.client_row.id)
    assert row["printer_count"] == 3
