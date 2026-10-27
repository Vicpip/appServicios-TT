"""URLs firmadas (HMAC-SHA256 + expiración) a archivos de UPLOAD_DIR.

La URL lleva la ruta *relativa a UPLOAD_DIR* (``p``), la expiración en epoch
(``e``) y la firma (``s``). Quien emite la URL (admin/portal) ya validó el
acceso al recurso; el endpoint solo comprueba firma, vigencia y que el archivo
quede dentro de UPLOAD_DIR.
"""
import hashlib
import hmac
import time
from pathlib import Path, PurePosixPath
from urllib.parse import urlencode

from app.config import get_settings

SIGNED_PATH = "/api/files/signed"


def _secret() -> bytes:
    return get_settings().file_signing_secret.encode("utf-8")


def _upload_root() -> Path:
    return Path(get_settings().upload_dir).resolve()


def _message(rel: str, exp: int) -> bytes:
    return f"{rel}\n{exp}".encode("utf-8")


def compute_signature(rel: str, exp: int) -> str:
    return hmac.new(_secret(), _message(rel, exp), hashlib.sha256).hexdigest()


def is_safe_relative(rel: str) -> bool:
    """Ruta relativa sin "..", sin absolutos, sin backslash ni bytes nulos."""
    if not rel or "\x00" in rel or "\\" in rel or rel.startswith("/"):
        return False
    parts = PurePosixPath(rel).parts
    return bool(parts) and all(part not in ("", ".", "..") for part in parts)


def to_relative_upload_path(raw: str | None) -> str | None:
    """Convierte una ruta guardada en BD a ruta relativa a UPLOAD_DIR.

    Formatos reales: ``uploads/report/<id>/photo/x.jpg`` (files.storage_path,
    reports.signature_image_path), ``/uploads/...``, ``logos/<id>.png``,
    absolutas dentro de UPLOAD_DIR y, en reports.signature_image_path /
    photo_paths, rutas locales del teléfono (``/data/user/0/...``) que no
    existen en el servidor (devuelven None).
    """
    if not raw:
        return None
    text = raw.strip().replace("\\", "/")
    root = _upload_root()
    if text.startswith("/") or (len(text) > 1 and text[1] == ":"):
        try:
            return Path(text).resolve().relative_to(root).as_posix()
        except (ValueError, OSError):
            pass
        # "/uploads/x" (URL vieja): quitar el prefijo como si fuera relativa.
        text = text.lstrip("/")
        if not text.startswith("uploads/"):
            return None
    parts = text.split("/")
    if parts[0] in ("uploads", Path(get_settings().upload_dir).name) and len(parts) > 1:
        parts = parts[1:]
    rel = "/".join(parts)
    return rel if is_safe_relative(rel) else None


def signed_upload_url(raw: str | None, ttl: int | None = None) -> str | None:
    """URL relativa firmada (``/api/files/signed?p=..&e=..&s=..``) o None."""
    rel = to_relative_upload_path(raw)
    if rel is None:
        return None
    exp = int(time.time()) + (ttl if ttl is not None else get_settings().file_url_ttl_seconds)
    query = urlencode({"p": rel, "e": exp, "s": compute_signature(rel, exp)})
    return f"{SIGNED_PATH}?{query}"


def verify_signature(rel: str, exp: int, sig: str) -> bool:
    """Firma válida y no vencida (comparación en tiempo constante)."""
    expected = compute_signature(rel, exp)
    ok = hmac.compare_digest(expected.encode("ascii"), sig.encode("utf-8", "ignore"))
    return ok and exp >= int(time.time())


def resolve_inside_uploads(rel: str) -> Path | None:
    """Ruta absoluta del archivo si existe y está dentro de UPLOAD_DIR."""
    if not is_safe_relative(rel):
        return None
    root = _upload_root()
    try:
        target = (root / rel).resolve()
    except OSError:
        return None
    if not target.is_relative_to(root) or not target.is_file():
        return None
    return target
