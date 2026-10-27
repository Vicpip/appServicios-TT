"""Login móvil 365 días, refresh deslizante, revocación (401) y usuario desactivado (403)."""
from datetime import datetime, timezone

from jose import jwt

from app.config import get_settings
from tests.conftest import PASSWORD


def _days_left(token: str) -> float:
    payload = jwt.decode(token, get_settings().secret_key, algorithms=[get_settings().algorithm])
    exp = datetime.fromtimestamp(payload["exp"], tz=timezone.utc)
    return (exp - datetime.now(timezone.utc)).total_seconds() / 86400


def test_login_movil_dura_365_dias(client, world):
    res = client.post("/api/auth/login", json={"email": world.tech.email, "password": PASSWORD})
    assert res.status_code == 200
    days = _days_left(res.json()["access_token"])
    assert 364 < days <= 365


def test_login_web_no_usa_token_largo(client, world):
    res = client.post(
        "/api/auth/login",
        json={"email": world.admin.email, "password": PASSWORD, "client_type": "web"},
    )
    assert res.status_code == 200
    assert _days_left(res.json()["access_token"]) < 30  # access_token_expire_minutes, no 365 d


def test_credenciales_incorrectas(client, world):
    res = client.post("/api/auth/login", json={"email": world.tech.email, "password": "mala"})
    assert res.status_code == 401


def test_refresh_renueva_365_dias(client, world, tech_headers):
    res = client.post("/api/auth/refresh", headers=tech_headers)
    assert res.status_code == 200
    assert 364 < _days_left(res.json()["access_token"]) <= 365


def test_revocacion_invalida_tokens_con_401(client, world, tech_headers, admin_headers):
    assert client.post("/api/auth/refresh", headers=tech_headers).status_code == 200
    res = client.post(f"/api/admin/technicians/{world.tech.id}/revoke-tokens", headers=admin_headers)
    assert res.status_code == 200
    res = client.post("/api/auth/refresh", headers=tech_headers)
    assert res.status_code == 401
    # Y también en cualquier endpoint protegido de sincronización.
    assert client.get("/api/sync/download", headers=tech_headers).status_code == 401
    # Un login nuevo vuelve a funcionar.
    res = client.post("/api/auth/login", json={"email": world.tech.email, "password": PASSWORD})
    assert res.status_code == 200
    new_headers = {"Authorization": f"Bearer {res.json()['access_token']}"}
    assert client.post("/api/auth/refresh", headers=new_headers).status_code == 200


def test_usuario_desactivado_recibe_403(client, world, db, tech_headers):
    world.tech.is_active = False
    db.commit()
    assert client.post("/api/auth/refresh", headers=tech_headers).status_code == 403
    assert client.get("/api/sync/download", headers=tech_headers).status_code == 403
    res = client.post("/api/auth/login", json={"email": world.tech.email, "password": PASSWORD})
    assert res.status_code == 403


# ---------------------------------------------------------------------------
# H-01 / H-02 — rutas admin exigen rol admin; login web solo para admin
# ---------------------------------------------------------------------------

import uuid  # noqa: E402

import pytest  # noqa: E402

from app.api.routers.portal import _portal_token  # noqa: E402
from app.models.client import Client  # noqa: E402
from app.models.client_contact_email import ClientContactEmail  # noqa: E402
from app.models.portal import PortalUser  # noqa: E402


def _admin_routes(world) -> list[tuple[str, str]]:
    """Una ruta GET por familia de /api/admin/* (todas deben ser solo admin)."""
    cid, pid, tid = world.client_row.id, world.policy.id, world.tech.id
    return [
        ("/api/admin/reports", "reports"),
        ("/api/admin/clients", "clients"),
        (f"/api/admin/clients/{cid}/detail", "clients-detail"),
        ("/api/admin/technicians", "technicians"),
        (f"/api/admin/technicians/{tid}", "technician-detail"),
        ("/api/admin/printers", "printers"),
        ("/api/admin/policies", "policies"),
        (f"/api/admin/policies/{pid}", "policy-detail"),
        (f"/api/admin/policies/{pid}/visits", "visits"),
        (f"/api/admin/policies/{pid}/deliveries", "deliveries"),
        ("/api/admin/plants", "plants"),
        ("/api/admin/areas", "areas"),
        ("/api/admin/catalog/models", "catalog"),
        ("/api/admin/sync/history", "sync-history"),
        ("/api/admin/dashboard/reports-by-day", "dashboard"),
    ]


def test_rutas_admin_sin_token_401(client, world):
    for url, name in _admin_routes(world):
        assert client.get(url).status_code == 401, name
    # escritura sensible: crear admin sin token
    res = client.post(
        "/api/admin/technicians",
        json={"name": "x", "email": "x@x.com", "password": "Abc!defghij1", "role": "admin"},
    )
    assert res.status_code == 401


def test_rutas_admin_con_tecnico_403(client, world, tech_headers):
    for url, name in _admin_routes(world):
        assert client.get(url, headers=tech_headers).status_code == 403, name
    res = client.post(
        "/api/admin/technicians",
        json={"name": "x", "email": "x@x.com", "password": "Abc!defghij1", "role": "admin"},
        headers=tech_headers,
    )
    assert res.status_code == 403
    res = client.post(f"/api/admin/technicians/{world.tech.id}/revoke-tokens", headers=tech_headers)
    assert res.status_code == 403


def test_rutas_admin_con_admin_200(client, world, admin_headers):
    for url, name in _admin_routes(world):
        assert client.get(url, headers=admin_headers).status_code == 200, name


def test_contact_emails_get_tecnico_200_post_403(client, world, tech_headers, admin_headers):
    url = f"/api/admin/clients/{world.client_row.id}/contact-emails"
    assert client.get(url).status_code == 401
    assert client.get(url, headers=tech_headers).status_code == 200
    body = {"email": "nuevo@cliente.com", "label": "x"}
    assert client.post(url, json=body, headers=tech_headers).status_code == 403
    assert client.post(url, json=body, headers=admin_headers).status_code == 201


def test_get_report_y_get_policies_exigen_token(client, world, tech_headers):
    rid = str(uuid.uuid4())
    assert client.get(f"/api/reports/{rid}").status_code == 401
    assert client.get("/api/policies").status_code == 401
    assert client.get("/api/policies", headers=tech_headers).status_code == 200
    # con token pasa la auth (404 porque el reporte no existe)
    assert client.get(f"/api/reports/{rid}", headers=tech_headers).status_code == 404


def test_portal_invite_y_usuarios_solo_admin(client, world, tech_headers, admin_headers):
    users_url = f"/api/portal/admin/clients/{world.client_row.id}/users"
    invite = {"client_id": world.client_row.id, "email": "inv@cliente.com"}
    assert client.get(users_url).status_code == 401
    assert client.get(users_url, headers=tech_headers).status_code == 403
    assert client.get(users_url, headers=admin_headers).status_code == 200
    assert client.post("/api/portal/invite", json=invite).status_code == 401
    assert client.post("/api/portal/invite", json=invite, headers=tech_headers).status_code == 403
    assert client.patch(
        "/api/portal/admin/users/x/toggle-active", json={"is_active": False}, headers=tech_headers
    ).status_code == 403


def _portal_headers(db, client_id: str, email: str) -> dict:
    user = PortalUser(
        id=str(uuid.uuid4()), client_id=client_id, email=email, name="Portal",
        password_hash="x", is_active=True,
    )
    db.add(user)
    db.commit()
    return {"Authorization": f"Bearer {_portal_token(user, db)}"}


def test_portal_contact_emails_solo_los_de_su_cliente(client, world, db):
    other = Client(id=str(uuid.uuid4()), name="Otro Cliente", is_active=True)
    foreign = ClientContactEmail(
        id=str(uuid.uuid4()), client_id=other.id, email="ajeno@otro.com", is_active=True
    )
    db.add_all([other, foreign])
    db.commit()
    world.add_contact("propio@cliente.com")
    db.commit()
    headers = _portal_headers(db, world.client_row.id, "portal@cliente.com")

    res = client.get("/api/portal/contact-emails", headers=headers)
    assert res.status_code == 200
    emails = [r["email"] for r in res.json()]
    assert "propio@cliente.com" in emails and "ajeno@otro.com" not in emails

    created = client.post("/api/portal/contact-emails", json={"email": "alta@cliente.com"}, headers=headers)
    assert created.status_code == 201
    assert created.json()["client_id"] == world.client_row.id

    # no puede borrar un correo de otro cliente
    res = client.delete(f"/api/portal/contact-emails/{foreign.id}", headers=headers)
    assert res.status_code == 404
    db.expire_all()
    assert db.get(ClientContactEmail, foreign.id) is not None

    # sí puede borrar uno propio
    assert client.delete(f"/api/portal/contact-emails/{created.json()['id']}", headers=headers).status_code == 200
    assert client.get("/api/portal/contact-emails").status_code in (401, 403)


def test_login_web_con_tecnico_403_y_movil_200(client, world):
    res = client.post(
        "/api/auth/login",
        json={"email": world.tech.email, "password": PASSWORD, "client_type": "web"},
    )
    assert res.status_code == 403
    assert "administradores" in res.json()["detail"]
    res = client.post(
        "/api/auth/login",
        json={"email": world.tech.email, "password": PASSWORD, "client_type": "mobile"},
    )
    assert res.status_code == 200
    res = client.post(
        "/api/auth/login",
        json={"email": world.admin.email, "password": PASSWORD, "client_type": "web"},
    )
    assert res.status_code == 200
