"""Ligas públicas (token aleatorio) a PDFs de reportes y entregas."""
import secrets
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

from sqlalchemy.orm import Session

from app.config import get_settings
from app.models.file import EntityFile, File
from app.models.policy import PolicyDelivery
from app.models.share_link import (
    TARGET_DELIVERY_PDF,
    TARGET_REPORT_PDF,
    FileShareLink,
)

_TOKEN_BYTES = 32  # secrets.token_urlsafe(32) -> 43 caracteres, 256 bits


def _now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def resolve_upload_path(raw_path: str) -> Path:
    """Ruta absoluta de un path guardado. Los paths relativos pueden traer el
    prefijo "uploads/" (el PDF de entrega lo escribe fijo así) o el nombre real
    de la carpeta configurada en UPLOAD_DIR; ambos se quitan antes de unir."""
    p = Path(raw_path)
    if p.is_absolute():
        return p
    upload_dir = Path(get_settings().upload_dir)
    parts = p.parts
    if parts and parts[0] in ("uploads", upload_dir.name):
        p = Path(*parts[1:])
    return upload_dir / p


def link_url(link: FileShareLink) -> str:
    return f"{get_settings().api_base_url.rstrip('/')}/api/public/files/{link.token}"


def link_expire_days() -> int:
    return get_settings().public_link_expire_days


def create_link(db: Session, target_type: str, target_id: str) -> FileShareLink:
    link = FileShareLink(
        id=str(uuid.uuid4()),
        token=secrets.token_urlsafe(_TOKEN_BYTES),
        target_type=target_type,
        target_id=target_id,
        created_at=_now(),
        expires_at=_now() + timedelta(days=link_expire_days()),
        access_count=0,
    )
    db.add(link)
    db.flush()
    return link


def get_or_create_active_link(
    db: Session, target_type: str, target_id: str
) -> FileShareLink:
    """Liga vigente del destino (la más reciente) o una nueva."""
    now = _now()
    link = (
        db.query(FileShareLink)
        .filter(
            FileShareLink.target_type == target_type,
            FileShareLink.target_id == target_id,
            FileShareLink.revoked_at.is_(None),
            FileShareLink.expires_at > now,
        )
        .order_by(FileShareLink.created_at.desc())
        .first()
    )
    return link or create_link(db, target_type, target_id)


def revoke_links(db: Session, target_type: str, target_id: str) -> int:
    """Revoca todas las ligas activas del destino. Devuelve cuántas."""
    return (
        db.query(FileShareLink)
        .filter(
            FileShareLink.target_type == target_type,
            FileShareLink.target_id == target_id,
            FileShareLink.revoked_at.is_(None),
        )
        .update({"revoked_at": _now()}, synchronize_session=False)
    )


def regenerate_link(db: Session, target_type: str, target_id: str) -> FileShareLink:
    """Revoca las ligas anteriores y crea una nueva."""
    revoke_links(db, target_type, target_id)
    return create_link(db, target_type, target_id)


def find_valid_link(db: Session, token: str) -> FileShareLink | None:
    """Liga existente, no revocada y no vencida; None en cualquier otro caso."""
    if not token or len(token) > 128:
        return None
    link = db.query(FileShareLink).filter(FileShareLink.token == token).first()
    if link is None or link.revoked_at is not None or link.expires_at <= _now():
        return None
    return link


def report_pdf_file(db: Session, report_id: str) -> File | None:
    """PDF más reciente del reporte (EntityFile file_category='pdf')."""
    return (
        db.query(File)
        .join(EntityFile, EntityFile.file_id == File.id)
        .filter(EntityFile.entity_id == report_id, EntityFile.file_category == "pdf")
        .order_by(File.created_at.desc())
        .first()
    )


def report_pdf_path(db: Session, report_id: str) -> Path | None:
    f = report_pdf_file(db, report_id)
    if f is None:
        return None
    path = resolve_upload_path(f.storage_path)
    return path if path.exists() else None


def delivery_pdf_path(db: Session, delivery_id: str) -> Path | None:
    delivery = db.get(PolicyDelivery, delivery_id)
    if delivery is None or not delivery.pdf_path:
        return None
    path = resolve_upload_path(delivery.pdf_path)
    return path if path.exists() else None


def resolve_link_file(db: Session, link: FileShareLink) -> Path | None:
    if link.target_type == TARGET_REPORT_PDF:
        return report_pdf_path(db, link.target_id)
    if link.target_type == TARGET_DELIVERY_PDF:
        return delivery_pdf_path(db, link.target_id)
    return None
