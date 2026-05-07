"""Non-admin report endpoints: GET and PATCH /api/reports/{report_id}."""
from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.auth import get_current_user
from app.config import get_settings
from app.database import get_db
from app.models.client import Client
from app.models.file import EntityFile, File
from app.models.printer import Printer
from app.models.report import Report
from app.models.user import User
from app.schemas.report import ReportUpdate

router = APIRouter(prefix="/api/reports", tags=["reports"])
settings = get_settings()


def _now_utc() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _build_report_response(report: Report, db: Session) -> dict:
    """Return a flat dict of report fields sufficient for Flutter to update Drift."""
    printer = db.get(Printer, report.printer_id) if report.printer_id else None
    client = db.get(Client, printer.client_id) if printer and printer.client_id else None
    tech = db.get(User, report.tech_id) if report.tech_id else None

    # Collect associated file URLs
    rows = (
        db.query(EntityFile, File)
        .join(File, EntityFile.file_id == File.id)
        .filter(
            EntityFile.entity_id == report.id,
            EntityFile.entity_type == "report",
        )
        .all()
    )
    upload_path = Path(settings.upload_dir)
    photos: list[str] = []
    signature_url: str | None = None
    pdf_url: str | None = None
    for ef, f in rows:
        try:
            rel = Path(f.storage_path).relative_to(upload_path)
            url = f"/uploads/{rel.as_posix()}"
        except ValueError:
            url = f"/uploads/{f.storage_path.lstrip('/')}"
        if ef.file_category == "photo":
            photos.append(url)
        elif ef.file_category == "signature":
            signature_url = url
        elif ef.file_category == "pdf":
            pdf_url = url

    return {
        "id": report.id,
        "code": report.code,
        "printer_id": report.printer_id,
        "tech_id": report.tech_id,
        "service_type": report.service_type,
        "status": report.status,
        "service_date": report.service_date.isoformat() if report.service_date else None,
        "linear_inches_counter": report.linear_inches_counter,
        "darkness_level": report.darkness_level,
        "notes": report.notes,
        "technical_checkboxes": report.technical_checkboxes,
        "signature_name": report.signature_name,
        "signature_role": report.signature_role,
        "signature_image_path": report.signature_image_path,
        "photo_paths": report.photo_paths,
        "photo_count": report.photo_count,
        "internal_notes": report.internal_notes,
        "sync_date": report.sync_date.isoformat() if report.sync_date else None,
        "created_at": report.created_at.isoformat() if report.created_at else None,
        "printer_serial": printer.serial_number if printer else None,
        "client_name": client.name if client else None,
        "tech_name": tech.name if tech else None,
        "photos": photos,
        "signature_url": signature_url,
        "pdf_url": pdf_url,
    }


# ---------------------------------------------------------------------------
# GET /api/reports/{report_id}
# ---------------------------------------------------------------------------

@router.get("/{report_id}", response_model=dict)
def get_report(
    report_id: str,
    db: Session = Depends(get_db),
) -> dict:
    """Return full report detail including associated file URLs."""
    report: Report | None = db.get(Report, report_id)
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    return _build_report_response(report, db)


# ---------------------------------------------------------------------------
# PATCH /api/reports/{report_id}
# ---------------------------------------------------------------------------

@router.patch("/{report_id}", response_model=dict)
def update_report(
    report_id: str,
    body: ReportUpdate,
    db: Session = Depends(get_db),
    _current_user: dict = Depends(get_current_user),
) -> dict:
    """Partially update editable fields and regenerate PDF if the report is signed."""
    report: Report | None = db.get(Report, report_id)
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")

    # Apply only the fields explicitly provided in the request body
    update_data = body.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(report, field, value)

    db.commit()
    db.refresh(report)

    return _build_report_response(report, db)
