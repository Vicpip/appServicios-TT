"""H-06: filtros de /api/portal/reports aplicados en SQL, con paginación y total correctos."""
import uuid
from datetime import datetime

from app.models.report import Report
from tests.portal_helpers import add_plant_b_printer, make_portal_user, portal_headers


def _add(db, world, printer, when, code, service_type="Preventivo"):
    db.add(Report(
        id=str(uuid.uuid4()), code=code, printer_id=printer.id, tech_id=world.tech.id,
        service_type=service_type, status="Signed", service_date=when,
        linear_inches_counter=1, technical_checkboxes="{}",
    ))


def _get(client, db, user, **params):
    res = client.get("/api/portal/reports", params=params, headers=portal_headers(db, user))
    assert res.status_code == 200, res.text
    return res.json()


def test_fechas_inclusivas_y_total_refleja_el_filtro(client, db, world):
    p = world.printers[0]
    for day in range(1, 31):
        _add(db, world, p, datetime(2026, 3, day, 15, 30), f"MAR-{day:02d}")
    _add(db, world, p, datetime(2026, 2, 28, 23, 59), "FEB-28")
    _add(db, world, p, datetime(2026, 4, 1, 0, 0), "ABR-01")
    db.commit()
    user = make_portal_user(db, world.client_row.id)

    body = _get(client, db, user, date_from="2026-03-10", date_to="2026-03-20", limit=100)
    assert body["total"] == 11
    assert {i["code"] for i in body["items"]} == {f"MAR-{d}" for d in range(10, 21)}

    # solo date_to: incluye todo el día final y excluye el siguiente
    assert _get(client, db, user, date_to="2026-03-30")["total"] == 31  # marzo 1-30 + FEB-28
    assert _get(client, db, user, date_from="2026-03-31")["total"] == 1  # ABR-01
    assert _get(client, db, user, date_from="2026-04-02", date_to="2026-03-01")["total"] == 0


def test_busqueda_por_serie_codigo_tipo_y_modelo(client, db, world):
    p0, p1 = world.printers[0], world.printers[1]
    now_ = datetime(2026, 5, 1, 10, 0)
    _add(db, world, p0, now_, "ABC-001", "Preventivo")
    _add(db, world, p1, now_, "XYZ-777", "Correctivo")
    db.commit()
    user = make_portal_user(db, world.client_row.id)

    assert [i["code"] for i in _get(client, db, user, q="sn-001")["items"]] == ["ABC-001"]   # serie, sin mayúsculas
    assert [i["code"] for i in _get(client, db, user, q="xyz")["items"]] == ["XYZ-777"]      # código
    assert [i["code"] for i in _get(client, db, user, q="correct")["items"]] == ["XYZ-777"]  # tipo
    assert _get(client, db, user, q="zt411")["total"] == 2                                   # modelo
    assert _get(client, db, user, q="Zebra ZT411")["total"] == 2                             # marca + modelo
    assert _get(client, db, user, q="no-existe")["total"] == 0
    assert _get(client, db, user, q="%")["total"] == 0   # comodín escapado, no coincide con todo


def test_paginacion_con_filtros_y_alcance_de_planta(client, db, world):
    p0 = world.printers[0]
    _, printer_b = add_plant_b_printer(db, world)
    for i in range(45):
        _add(db, world, p0, datetime(2026, 6, 1 + i % 28, 8, i % 60), f"PAG-{i:03d}")
    for i in range(25):
        _add(db, world, p0, datetime(2026, 7, 1, 8, i), f"OTRO-{i:03d}", "Correctivo")
    _add(db, world, printer_b, datetime(2026, 6, 5, 8, 0), "PAG-PLANTA-B")
    db.commit()

    user = make_portal_user(db, world.client_row.id, plant_id=p0.plant_id)
    page1 = _get(client, db, user, q="PAG-", limit=20, offset=0)
    page3 = _get(client, db, user, q="PAG-", limit=20, offset=40)
    assert page1["total"] == page3["total"] == 45        # nada de planta B
    assert len(page1["items"]) == 20 and len(page3["items"]) == 5

    seen = set()
    for off in (0, 20, 40):
        seen |= {i["id"] for i in _get(client, db, user, q="PAG-", limit=20, offset=off)["items"]}
    assert len(seen) == 45

    combo = _get(client, db, user, q="OTRO", date_from="2026-07-01", date_to="2026-07-01", limit=10, offset=10)
    assert combo["total"] == 25 and len(combo["items"]) == 10

    full = make_portal_user(db, world.client_row.id)
    assert _get(client, db, full, q="PAG-")["total"] == 46  # el usuario sin planta sí ve la planta B
