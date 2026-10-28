"""H-25: cuenta desactivada (403) vs credenciales inválidas (401) e invitación a correo ya registrado."""
from tests.portal_helpers import PORTAL_PASSWORD, make_portal_user


def test_login_desactivado_devuelve_403_y_credenciales_malas_401(client, db, world):
    user = make_portal_user(db, world.client_row.id, active=False)
    ok_pwd = client.post("/api/portal/login", json={"email": user.email, "password": PORTAL_PASSWORD})
    assert ok_pwd.status_code == 403
    assert ok_pwd.json()["detail"] == "Cuenta desactivada"

    bad_pwd = client.post("/api/portal/login", json={"email": user.email, "password": "Otra#2026"})
    assert bad_pwd.status_code == 401
    unknown = client.post("/api/portal/login", json={"email": "nadie@cliente.example.com", "password": "Otra#2026"})
    assert unknown.status_code == 401


def test_invitar_correo_ya_registrado_devuelve_409(client, db, world, admin_headers, outbox):
    user = make_portal_user(db, world.client_row.id)
    res = client.post(
        "/api/portal/invite",
        json={"email": user.email, "client_id": world.client_row.id},
        headers=admin_headers,
    )
    assert res.status_code == 409
    assert outbox.sent == []  # no se manda correo

    nuevo = client.post(
        "/api/portal/invite",
        json={"email": "nuevo@cliente.example.com", "client_id": world.client_row.id},
        headers=admin_headers,
    )
    assert nuevo.status_code == 201, nuevo.text


def test_invitacion_pendiente_se_puede_reenviar(client, db, world, admin_headers, outbox):
    body = {"email": "pendiente@cliente.example.com", "client_id": world.client_row.id}
    assert client.post("/api/portal/invite", json=body, headers=admin_headers).status_code == 201
    assert client.post("/api/portal/invite", json=body, headers=admin_headers).status_code == 201
