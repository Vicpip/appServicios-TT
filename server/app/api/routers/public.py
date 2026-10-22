"""Endpoints públicos (sin login). Hoy: descarga de PDFs por liga con token."""
import re
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import FileResponse, JSONResponse
from sqlalchemy.orm import Session

from app.config import get_settings
from app.database import get_db
from app.services.rate_limit import public_link_limiter
from app.services.share_link_service import find_valid_link, resolve_link_file

router = APIRouter(prefix="/api/public", tags=["public"])

_NOT_FOUND = HTTPException(status_code=404, detail="No encontrado")


def _client_ip(request: Request) -> str:
    # Detrás de Nginx, uvicorn reescribe request.client con X-Forwarded-For
    # (proxy_headers=True, forwarded-allow-ips=127.0.0.1 por defecto).
    return request.client.host if request.client else "unknown"


def _safe_filename(name: str) -> str:
    return re.sub(r'[^A-Za-z0-9._-]+', "_", name) or "documento.pdf"


@router.get("/files/{token}")
def get_public_file(
    token: str, request: Request, db: Session = Depends(get_db)
) -> FileResponse:
    """Sirve el PDF ligado al token. 404 genérico si el token no existe,
    venció, fue revocado o el archivo ya no está (sin distinguir cuál)."""
    settings = get_settings()
    if not public_link_limiter.allow(
        _client_ip(request),
        settings.public_link_rate_limit,
        settings.public_link_rate_window_seconds,
    ):
        return JSONResponse(  # type: ignore[return-value]
            status_code=429,
            content={"detail": "Demasiadas peticiones"},
            headers={
                "Retry-After": str(settings.public_link_rate_window_seconds),
                "Cache-Control": "no-store",
            },
        )

    link = find_valid_link(db, token)
    path = resolve_link_file(db, link) if link else None
    if link is None or path is None:
        raise _NOT_FOUND

    link.last_access_at = datetime.now(timezone.utc).replace(tzinfo=None)
    link.access_count = (link.access_count or 0) + 1
    db.commit()

    return FileResponse(
        path,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'inline; filename="{_safe_filename(path.name)}"',
            "X-Robots-Tag": "noindex, nofollow",
            "Cache-Control": "private, no-store",
            "X-Content-Type-Options": "nosniff",
        },
    )
