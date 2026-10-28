"""H-11: reglas de contraseña validadas en el servidor (registro y recuperación)."""
import uuid
from datetime import timedelta

import pytest

from app.models.portal import PortalInvitation, PortalPasswordReset
from tests.conftest import now
from tests.portal_helpers import make_portal_user


STRONG = ["Portal#2026", "Contra.seña9", "Abcdefg_1", "Mi clave 2026!"]


def _invitation(db, world, email=None) -> str:
    token = uuid.uuid4().hex
    db.add(PortalInvitation(
        id=str(uuid.uuid4()), client_id=world.client_row.id, invited_by=world.admin.id,
        email=email or f"{uuid.uuid4().hex[:6]}@cliente.example.com", token=token, status="pending",
        expires_at=now() + timedelta(hours=48),
    ))
    db.commit()
    return token


def _reset_token(db, user) -> str:
    token = uuid.uuid4().hex
    db.add(PortalPasswordReset(
        id=str(uuid.uuid4()), portal_user_id=user.id, token=token, used=False,
        expires_at=now() + timedelta(hours=1),
    ))
    db.commit()
    return token


@pytest.mark.parametrize("password", ["abc", "sinnumero#A", "sin-mayuscula1", "SinEspecial123", "Corta#1"])
def test_registro_rechaza_contrasenas_debiles_con_422_en_espanol(client, db, world, password):
    token = _invitation(db, world)
    res = client.post("/api/portal/register", json={"token": token, "name": "Ana", "password": password})
    assert res.status_code == 422
    assert "La contraseña debe tener al menos 8 caracteres" in res.text
    # la invitación sigue pendiente: se puede reintentar con una válida
    ok = client.post("/api/portal/register", json={"token": token, "name": "Ana", "password": "Portal#2026"})
    assert ok.status_code == 201, ok.text


@pytest.mark.parametrize("password", STRONG)
def test_registro_acepta_contrasenas_validas(client, db, world, password):
    res = client.post(
        "/api/portal/register", json={"token": _invitation(db, world), "name": "Ana", "password": password}
    )
    assert res.status_code == 201, res.text


@pytest.mark.parametrize("password", ["abc", "sinnumero#A", "sin-mayuscula1", "SinEspecial123", "Corta#1"])
def test_reset_rechaza_contrasenas_debiles_y_no_gasta_el_token(client, db, world, password):
    user = make_portal_user(db, world.client_row.id)
    token = _reset_token(db, user)
    res = client.post("/api/portal/reset-password", json={"token": token, "new_password": password})
    assert res.status_code == 422
    assert "La contraseña debe tener al menos 8 caracteres" in res.text
    ok = client.post("/api/portal/reset-password", json={"token": token, "new_password": "Nueva#2026"})
    assert ok.status_code == 200, ok.text


def test_login_de_usuario_existente_con_contrasena_debil_sigue_funcionando(client, db, world):
    user = make_portal_user(db, world.client_row.id, password="debil")
    res = client.post("/api/portal/login", json={"email": user.email, "password": "debil"})
    assert res.status_code == 200, res.text
