import hashlib
from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.auth import create_access_token, get_current_active_user
from app.config import get_settings
from app.database import get_db
from app.models.user import User

router = APIRouter(prefix="/api/auth", tags=["auth"])

def _mobile_token_expire() -> timedelta:
    """Mobile token lifetime (Settings.mobile_token_expire_days, default 365)."""
    return timedelta(days=get_settings().mobile_token_expire_days)


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------


class LoginRequest(BaseModel):
    email: str
    password: str
    # "mobile" → long-lived (sliding) token; anything else → default from settings
    client_type: str = "mobile"


class UserInfo(BaseModel):
    id: str
    code: str | None
    name: str
    role: str


class LoginResponse(BaseModel):
    access_token: str
    token_type: str
    user: UserInfo


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _verify_password(plain: str, stored_hash: str) -> bool:
    """Verify PBKDF2-HMAC-SHA256 password.

    Stored format: ``{salt}${dk_hex}``  (same as _hash_password in admin.py)
    """
    try:
        salt, dk_hex = stored_hash.split("$", 1)
        dk = hashlib.pbkdf2_hmac("sha256", plain.encode(), salt.encode(), 260_000)
        return dk.hex() == dk_hex
    except Exception:
        return False


# ---------------------------------------------------------------------------
# Endpoint
# ---------------------------------------------------------------------------


def _issue_token(user: User, expires: timedelta | None) -> str:
    return create_access_token(
        data={
            "sub": user.id,
            "email": user.email,
            "role": user.role,
            "name": user.name,
            "tv": user.token_version or 0,
        },
        expires_delta=expires,
    )


@router.post("/login", response_model=LoginResponse)
def login(body: LoginRequest, db: Session = Depends(get_db)) -> LoginResponse:
    """Validate credentials and return a signed JWT."""
    user: User | None = (
        db.query(User).filter(User.email == body.email.strip()).first()
    )

    if not user or not user.password_hash:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciales incorrectas",
        )

    if not _verify_password(body.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciales incorrectas",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Usuario desactivado",
        )

    expires = _mobile_token_expire() if body.client_type == "mobile" else None
    token = _issue_token(user, expires)

    return LoginResponse(
        access_token=token,
        token_type="bearer",
        user=UserInfo(id=user.id, code=user.code, name=user.name, role=user.role),
    )


@router.post("/refresh", response_model=LoginResponse)
def refresh(
    payload: dict = Depends(get_current_active_user),
    db: Session = Depends(get_db),
) -> LoginResponse:
    """Sliding renewal: return a fresh mobile token (new full lifetime).

    The app calls this after every successful sync. Deactivated or revoked
    users get 403/401 from [get_current_active_user] and cannot renew.
    """
    user = db.get(User, payload["sub"])
    token = _issue_token(user, _mobile_token_expire())
    return LoginResponse(
        access_token=token,
        token_type="bearer",
        user=UserInfo(id=user.id, code=user.code, name=user.name, role=user.role),
    )
