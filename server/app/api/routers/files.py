"""Descarga de archivos de UPLOAD_DIR mediante URL firmada con expiración."""
import re

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import FileResponse

from app.services import file_signing_service as signing

router = APIRouter(prefix="/api/files", tags=["files"])

_MEDIA_TYPES = {
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".pdf": "application/pdf",
}
_FORBIDDEN = HTTPException(status_code=403, detail="Enlace no válido o vencido")
_NOT_FOUND = HTTPException(status_code=404, detail="No encontrado")


def _safe_filename(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "_", name) or "archivo"


@router.get("/signed")
def get_signed_file(
    p: str = Query(..., max_length=1024),
    e: int = Query(...),
    s: str = Query(..., max_length=128),
) -> FileResponse:
    """403 si la firma no coincide, venció o la ruta es insegura (sin decir cuál);
    404 si el archivo ya no existe."""
    if not signing.is_safe_relative(p) or not signing.verify_signature(p, e, s):
        raise _FORBIDDEN
    path = signing.resolve_inside_uploads(p)
    if path is None:
        raise _NOT_FOUND

    media_type = _MEDIA_TYPES.get(path.suffix.lower())
    disposition = "inline" if media_type else "attachment"
    return FileResponse(
        path,
        media_type=media_type or "application/octet-stream",
        headers={
            "Content-Disposition": f'{disposition}; filename="{_safe_filename(path.name)}"',
            "X-Content-Type-Options": "nosniff",
            "Cache-Control": "private, no-store",
            "X-Robots-Tag": "noindex, nofollow",
        },
    )
