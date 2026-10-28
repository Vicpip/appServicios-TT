"""Alcance del portal: el helper compartido respeta cliente, planta y is_active."""
from app.api.routers.portal import _get_printer_ids_in_scope
from tests.portal_helpers import add_plant_b_printer, make_portal_user, portal_headers


def test_alcance_cliente_completo_y_por_planta(db, world):
    _, printer_b = add_plant_b_printer(db, world)
    full = make_portal_user(db, world.client_row.id)
    plant_a = make_portal_user(db, world.client_row.id, plant_id=world.printers[0].plant_id)

    assert set(_get_printer_ids_in_scope(full, db)) == {p.id for p in world.printers} | {printer_b.id}
    assert set(_get_printer_ids_in_scope(plant_a, db)) == {p.id for p in world.printers}


def test_alcance_excluye_inactivas_y_lista_de_impresoras_coincide(client, db, world):
    world.printers[2].is_active = False
    db.commit()
    user = make_portal_user(db, world.client_row.id)
    res = client.get("/api/portal/printers", headers=portal_headers(db, user))
    assert res.status_code == 200
    assert {i["id"] for i in res.json()} == set(_get_printer_ids_in_scope(user, db))
    assert len(res.json()) == 2
