"""JWT authentication for the client portal.

Provides get_current_portal_user() — a FastAPI dependency that validates a
portal-specific JWT (role == "portal_client") and returns the decoded payload.

Kept separate from app.auth (which handles internal technician/admin tokens)
so the two token namespaces cannot be cross-used.
"""

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.auth import verify_token  # reuse existing decode/validate logic

_portal_bearer = HTTPBearer(scheme_name="PortalBearer")

_PORTAL_ROLE = "portal_client"


def get_current_portal_user(
    credentials: HTTPAuthorizationCredentials = Depends(_portal_bearer),
) -> dict:
    """FastAPI dependency — validates a portal JWT and returns its payload.

    Raises 403 if the token is valid but was issued for an internal user
    (role != 'portal_client'), preventing cross-use of token namespaces.
    """
    payload = verify_token(credentials.credentials)  # raises 401 on bad/expired token

    if payload.get("role") != _PORTAL_ROLE:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Token no válido para el portal de clientes",
        )

    return payload
