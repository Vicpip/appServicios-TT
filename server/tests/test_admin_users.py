"""H-17: listado de técnicos/administradores, guardas de baja y asignaciones."""
import uuid

from app.models.user import User

from tests.conftest import _PASSWORD_HASH


def _add_user(db, name, role="technician", active=True):
    u = User(
        id=str(uuid.uuid4()), code=f"X-{uuid.uuid4().hex[:4]}", name=name,
        email=f"{uuid.uuid4().hex[:6]}@smp.test", password_hash=_PASSWORD_HASH,
        role=role, is_active=active, token_version=0,
    )
    db.add(u)
    db.commit()
    return u


def _list(client, headers, **params):
    res = client.get("/api/admin/technicians", params=params, headers=headers)
    assert res.status_code == 200, res.text
    return res.json()["items"]


# -- listado -----------------------------------------------------------------


def test_listado_por_defecto_solo_tecnicos(client, world, admin_headers):
    items = _list(client, admin_headers)
    assert {i["role"] for i in items} == {"technician"}


def test_listado_filtra_admin_y_todos(client, world, admin_headers):
    assert {i["id"] for i in _list(client, admin_headers, role="admin")} == {world.admin.id}
    ids = {i["id"] for i in _list(client, admin_headers, role="all")}
    assert ids == {world.admin.id, world.tech.id}


def test_listado_rol_invalido_da_422(client, world, admin_headers):
    res = client.get("/api/admin/technicians", params={"role": "otro"}, headers=admin_headers)
    assert res.status_code == 422


def test_listado_devuelve_is_active(client, world, db, admin_headers):
    _add_user(db, "Baja", active=False)
    por_nombre = {i["name"]: i["is_active"] for i in _list(client, admin_headers)}
    assert por_nombre["Baja"] is False
    assert por_nombre["Técnico Uno"] is True


def test_detalle_y_edicion_funcionan_para_admin(client, world, admin_headers):
    res = client.get(f"/api/admin/technicians/{world.admin.id}", headers=admin_headers)
    assert res.status_code == 200
    assert res.json()["role"] == "admin"
    res = client.put(
        f"/api/admin/technicians/{world.admin.id}", json={"name": "Admin Renombrado"},
        headers=admin_headers,
    )
    assert res.status_code == 200
    assert res.json()["name"] == "Admin Renombrado"


def test_admin_creado_aparece_en_filtro_admin(client, world, admin_headers):
    res = client.post(
        "/api/admin/technicians",
        json={"name": "Nuevo Admin", "email": "nuevo@smp.test", "password": "Otra#Clave2026", "role": "admin"},
        headers=admin_headers,
    )
    assert res.status_code == 201, res.text
    assert res.json()["is_active"] is True
    assert "Nuevo Admin" in {i["name"] for i in _list(client, admin_headers, role="admin")}


# -- guardas -------------------------------------------------------------------


def test_admin_no_puede_desactivarse_a_si_mismo(client, world, db, admin_headers):
    _add_user(db, "Otro Admin", role="admin")  # que no sea el último
    res = client.delete(f"/api/admin/technicians/{world.admin.id}", headers=admin_headers)
    assert res.status_code == 409
    assert "propia cuenta" in res.json()["detail"]


def test_no_se_desactiva_al_ultimo_admin_activo(client, world, db, admin_headers):
    # se desactiva al otro admin; world.admin queda como el último activo
    otro = _add_user(db, "Otro Admin", role="admin")
    assert client.delete(f"/api/admin/technicians/{otro.id}", headers=admin_headers).status_code == 200
    res = client.delete(f"/api/admin/technicians/{world.admin.id}", headers=admin_headers)
    assert res.status_code == 409


def test_se_puede_desactivar_otro_admin_si_hay_mas(client, world, db, admin_headers):
    otro = _add_user(db, "Otro Admin", role="admin")
    res = client.delete(f"/api/admin/technicians/{otro.id}", headers=admin_headers)
    assert res.status_code == 200
    db.expire_all()
    assert db.get(User, otro.id).is_active is False


def test_no_se_degrada_al_ultimo_admin(client, world, admin_headers):
    res = client.put(
        f"/api/admin/technicians/{world.admin.id}", json={"role": "technician"},
        headers=admin_headers,
    )
    assert res.status_code == 409
    assert "último administrador" in res.json()["detail"]


def test_se_degrada_admin_si_hay_otro_activo(client, world, db, admin_headers):
    otro = _add_user(db, "Otro Admin", role="admin")
    res = client.put(
        f"/api/admin/technicians/{otro.id}", json={"role": "technician"}, headers=admin_headers
    )
    assert res.status_code == 200
    assert res.json()["role"] == "technician"


def test_desactivar_tecnico_sigue_funcionando(client, world, admin_headers):
    res = client.delete(f"/api/admin/technicians/{world.tech.id}", headers=admin_headers)
    assert res.status_code == 200


# -- asignaciones --------------------------------------------------------------


def _assign(client, headers, world, user):
    return client.post(
        f"/api/admin/policies/{world.policy.id}/assignments",
        json={"printer_id": world.printers[0].id, "technician_id": user.id},
        headers=headers,
    )


def test_asignar_tecnico_activo_ok(client, world, admin_headers):
    assert _assign(client, admin_headers, world, world.tech).status_code == 200


def test_asignar_tecnico_inactivo_da_409(client, world, db, admin_headers):
    baja = _add_user(db, "Baja", active=False)
    res = _assign(client, admin_headers, world, baja)
    assert res.status_code == 409
    assert "inactivo" in res.json()["detail"]


def test_asignar_admin_da_409(client, world, admin_headers):
    res = _assign(client, admin_headers, world, world.admin)
    assert res.status_code == 409
    assert "técnico" in res.json()["detail"]
