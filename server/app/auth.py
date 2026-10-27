"""JWT authentication utilities for the FastAPI backend."""

from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User

from app.config import get_settings

security = HTTPBearer(auto_error=False)


def create_access_token(
    data: dict, expires_delta: Optional[timedelta] = None
) -> str:
    """Return a signed JWT with the given payload."""
    settings = get_settings()
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (
        expires_delta or timedelta(minutes=settings.access_token_expire_minutes)
    )
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.secret_key, algorithm=settings.algorithm)


def verify_token(token: str) -> dict:
    """Decode and validate a JWT; raises 401 on failure."""
    settings = get_settings()
    try:
        payload = jwt.decode(
            token, settings.secret_key, algorithms=[settings.algorithm]
        )
        return payload
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido o expirado",
            headers={"WWW-Authenticate": "Bearer"},
        )


def _bearer_token(credentials: Optional[HTTPAuthorizationCredentials]) -> str:
    """Sin header Authorization: 401 (HTTPBearer por defecto respondería 403)."""
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No autenticado",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return credentials.credentials


def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
) -> dict:
    """FastAPI dependency — returns the decoded JWT payload."""
    return verify_token(_bearer_token(credentials))


def get_current_active_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: Session = Depends(get_db),
) -> dict:
    """Like [get_current_user] but also checks the user in the database.

    Rejects the request when the user no longer exists, was deactivated from
    the admin (403) or when the token was revoked via ``token_version`` (401).
    Tokens issued before ``token_version`` existed carry no ``tv`` claim and are
    treated as version 0.
    """
    payload = verify_token(_bearer_token(credentials))
    user = db.get(User, payload.get("sub"))
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario no encontrado",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Usuario desactivado",
        )
    if int(payload.get("tv", 0)) != (user.token_version or 0):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Sesión revocada",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return payload


# Cualquier usuario interno activo (técnico o admin).
require_internal = get_current_active_user


def require_admin(payload: dict = Depends(get_current_active_user)) -> dict:
    """Solo usuarios internos con role == 'admin'; 403 en otro caso."""
    if payload.get("role") != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acceso restringido a administradores",
        )
    return payload
