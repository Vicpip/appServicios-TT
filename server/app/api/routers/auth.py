import hashlib
from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.auth import create_access_token
from app.database import get_db
from app.models.user import User

router = APIRouter(prefix="/api/auth", tags=["auth"])

# 7 days for mobile clients — supports full offline week without re-login.
_MOBILE_TOKEN_EXPIRE = timedelta(minutes=10080)


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------


class LoginRequest(BaseModel):
    email: str
    password: str
    # "mobile" → 7-day token; anything else → default from settings
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

    expires = _MOBILE_TOKEN_EXPIRE if body.client_type == "mobile" else None
    token = create_access_token(
        data={"sub": user.id, "email": user.email, "role": user.role, "name": user.name},
        expires_delta=expires,
    )

    return LoginResponse(
        access_token=token,
        token_type="bearer",
        user=UserInfo(id=user.id, code=user.code, name=user.name, role=user.role),
    )
