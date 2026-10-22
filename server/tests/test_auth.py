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


def test_revocacion_invalida_tokens_con_401(client, world, tech_headers):
    assert client.post("/api/auth/refresh", headers=tech_headers).status_code == 200
    res = client.post(f"/api/admin/technicians/{world.tech.id}/revoke-tokens")
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
