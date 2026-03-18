import hashlib
import json
import secrets
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.config import get_settings
from app.database import get_db
from app.models.area import Area
from app.models.catalog import CatalogModel
from app.models.client import Client
from app.models.file import EntityFile, File
from app.models.plant import Plant
from app.models.policy import Policy, PolicyPrinter
from app.models.printer import Printer
from app.models.report import Report
from app.models.sync import SyncLog
from app.models.user import User

settings = get_settings()
from app.schemas.admin import (
    AreaCreate,
    AreaListItem,
    AssignPrintersRequest,
    CatalogModelCreate,
    CatalogModelItem,
    ClientCreate,
    ClientListItem,
    ClientUpdate,
    PlantCreate,
    PlantListItem,
    PolicyCreate,
    PolicyDetail,
    PolicyListItem,
    PolicyPrinterItem,
    PolicyUpdate,
    PrinterCreate,
    PrinterListItem,
    PrinterUpdate,
    ReportDetail,
    ReportListItem,
    ReviewRequest,
    SyncHistoryItem,
    TechnicianCreate,
    TechnicianListItem,
    TechnicianUpdate,
)

router = APIRouter(prefix="/api/admin", tags=["admin"])

# Checkbox keys from the Flutter app that indicate equipment damage
_DAMAGE_KEYS = {"Rodillo dañado", "Cabezal dañado", "Sensor ribbon dañado", "Sensor papel dañado"}


def _now_utc() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _policy_status(end_date: datetime) -> str:
    now = _now_utc()
    if end_date < now:
        return "Expired"
    if end_date < now + timedelta(days=30):
        return "Expiring"
    return "Active"


def _printer_status(last_checkboxes_json: str | None) -> str:
    if not last_checkboxes_json:
        return "Sin Historial"
    try:
        checkboxes: dict = json.loads(last_checkboxes_json)
        for key in _DAMAGE_KEYS:
            if checkboxes.get(key) is True:
                return "En Atención"
        return "Correcto"
    except (json.JSONDecodeError, AttributeError):
        return "Sin Historial"


# ---------------------------------------------------------------------------
# GET /api/admin/reports
# ---------------------------------------------------------------------------

@router.get("/reports", response_model=dict)
def list_reports(
    client_id: str | None = Query(None),
    tech_id: str | None = Query(None),
    status: str | None = Query(None),
    date_from: datetime | None = Query(None),
    date_to: datetime | None = Query(None),
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=200),
    db: Session = Depends(get_db),
) -> dict:
    """List reports with optional filters and pagination."""
    q = (
        db.query(
            Report.id,
            Report.code,
            Report.service_type,
            Report.status,
            Report.service_date,
            Report.sync_date,
            Printer.serial_number.label("printer_serial"),
            Client.name.label("client_name"),
            User.name.label("tech_name"),
        )
        .outerjoin(Printer, Report.printer_id == Printer.id)
        .outerjoin(Client, Printer.client_id == Client.id)
        .outerjoin(User, Report.tech_id == User.id)
    )

    if client_id:
        q = q.filter(Client.id == client_id)
    if tech_id:
        q = q.filter(Report.tech_id == tech_id)
    if status:
        q = q.filter(Report.status == status)
    if date_from:
        q = q.filter(Report.service_date >= date_from)
    if date_to:
        q = q.filter(Report.service_date <= date_to)

    total = q.count()
    rows = q.order_by(Report.service_date.desc()).offset(offset).limit(limit).all()

    items = [
        ReportListItem(
            id=r.id,
            code=r.code,
            service_type=r.service_type,
            status=r.status,
            service_date=r.service_date,
            sync_date=r.sync_date,
            printer_serial=r.printer_serial,
            client_name=r.client_name,
            tech_name=r.tech_name,
        )
        for r in rows
    ]

    return {"total": total, "offset": offset, "limit": limit, "items": [i.model_dump() for i in items]}


# ---------------------------------------------------------------------------
# GET /api/admin/reports/{report_id}
# ---------------------------------------------------------------------------

@router.get("/reports/{report_id}", response_model=ReportDetail)
def get_report(report_id: str, db: Session = Depends(get_db)) -> ReportDetail:
    """Get full detail of a single report."""
    row = (
        db.query(
            Report,
            Printer.serial_number.label("printer_serial"),
            Printer.code.label("printer_code"),
            Client.name.label("client_name"),
            User.name.label("tech_name"),
            User.code.label("tech_code"),
        )
        .outerjoin(Printer, Report.printer_id == Printer.id)
        .outerjoin(Client, Printer.client_id == Client.id)
        .outerjoin(User, Report.tech_id == User.id)
        .filter(Report.id == report_id)
        .first()
    )

    if not row:
        raise HTTPException(status_code=404, detail="Report not found")

    report, printer_serial, printer_code, client_name, tech_name, tech_code = row

    return ReportDetail(
        id=report.id,
        code=report.code,
        printer_id=report.printer_id,
        tech_id=report.tech_id,
        service_type=report.service_type,
        status=report.status,
        service_date=report.service_date,
        linear_inches_counter=report.linear_inches_counter,
        darkness_level=report.darkness_level,
        label_type_id=report.label_type_id,
        technical_checkboxes=report.technical_checkboxes,
        notes=report.notes,
        signature_name=report.signature_name,
        signature_role=report.signature_role,
        signature_image_path=report.signature_image_path,
        photo_paths=report.photo_paths,
        photo_count=report.photo_count,
        internal_notes=report.internal_notes,
        sync_date=report.sync_date,
        created_at=report.created_at,
        printer_serial=printer_serial,
        printer_code=printer_code,
        client_name=client_name,
        tech_name=tech_name,
        tech_code=tech_code,
    )


# ---------------------------------------------------------------------------
# POST /api/admin/reports/{report_id}/review
# ---------------------------------------------------------------------------

@router.post("/reports/{report_id}/review")
def review_report(
    report_id: str,
    body: ReviewRequest,
    db: Session = Depends(get_db),
) -> dict:
    """Approve or reject a report and optionally add internal notes."""
    report: Report | None = db.get(Report, report_id)
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")

    if body.status not in ("approved", "rejected"):
        raise HTTPException(status_code=422, detail="status must be 'approved' or 'rejected'")

    report.status = "Reviewed-" + body.status.capitalize()
    if body.notes:
        report.internal_notes = body.notes

    db.commit()
    return {"success": True, "id": report_id, "status": report.status}


# ---------------------------------------------------------------------------
# GET /api/admin/reports/{report_id}/files
# ---------------------------------------------------------------------------

@router.get("/reports/{report_id}/files")
def get_report_files(report_id: str, db: Session = Depends(get_db)) -> dict:
    """Return URLs for photos, signature and PDF associated with a report."""
    rows = (
        db.query(EntityFile, File)
        .join(File, EntityFile.file_id == File.id)
        .filter(
            EntityFile.entity_id == report_id,
            EntityFile.entity_type == "report",
        )
        .all()
    )

    upload_dir = settings.upload_dir.rstrip("/")
    photos: list[str] = []
    signature: str | None = None
    pdf: str | None = None

    for ef, f in rows:
        rel = f.storage_path.removeprefix(upload_dir).lstrip("/")
        url = f"/uploads/{rel}"
        if ef.file_category == "photo":
            photos.append(url)
        elif ef.file_category == "signature":
            signature = url
        elif ef.file_category == "pdf":
            pdf = url

    return {"photos": photos, "signature": signature, "pdf": pdf}


# ---------------------------------------------------------------------------
# GET /api/admin/clients
# ---------------------------------------------------------------------------

@router.get("/clients", response_model=dict)
def list_clients(
    search: str | None = Query(None),
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=200),
    db: Session = Depends(get_db),
) -> dict:
    """List clients with plant/printer/policy counts."""
    plant_count_sq = (
        db.query(Plant.client_id, func.count(Plant.id).label("cnt"))
        .group_by(Plant.client_id)
        .subquery()
    )
    printer_count_sq = (
        db.query(Printer.client_id, func.count(Printer.id).label("cnt"))
        .group_by(Printer.client_id)
        .subquery()
    )
    policy_count_sq = (
        db.query(Policy.client_id, func.count(Policy.id).label("cnt"))
        .filter(Policy.status == "Active")
        .group_by(Policy.client_id)
        .subquery()
    )

    q = (
        db.query(
            Client,
            func.coalesce(plant_count_sq.c.cnt, 0).label("plant_count"),
            func.coalesce(printer_count_sq.c.cnt, 0).label("printer_count"),
            func.coalesce(policy_count_sq.c.cnt, 0).label("active_policy_count"),
        )
        .outerjoin(plant_count_sq, Client.id == plant_count_sq.c.client_id)
        .outerjoin(printer_count_sq, Client.id == printer_count_sq.c.client_id)
        .outerjoin(policy_count_sq, Client.id == policy_count_sq.c.client_id)
    )

    if search:
        q = q.filter(Client.name.ilike(f"%{search}%") | Client.rfc.ilike(f"%{search}%"))

    total = q.count()
    rows = q.order_by(Client.name).offset(offset).limit(limit).all()

    items = [
        ClientListItem(
            id=client.id,
            name=client.name,
            rfc=client.rfc,
            address=client.address,
            is_active=client.is_active,
            plant_count=plant_count,
            printer_count=printer_count,
            active_policy_count=active_policy_count,
        )
        for client, plant_count, printer_count, active_policy_count in rows
    ]

    return {"total": total, "offset": offset, "limit": limit, "items": [i.model_dump() for i in items]}


# ---------------------------------------------------------------------------
# GET /api/admin/technicians
# ---------------------------------------------------------------------------

@router.get("/technicians", response_model=dict)
def list_technicians(
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=200),
    db: Session = Depends(get_db),
) -> dict:
    """List technicians with their report count and last sync."""
    report_count_sq = (
        db.query(Report.tech_id, func.count(Report.id).label("cnt"))
        .group_by(Report.tech_id)
        .subquery()
    )

    q = (
        db.query(
            User,
            func.coalesce(report_count_sq.c.cnt, 0).label("reports_count"),
        )
        .outerjoin(report_count_sq, User.id == report_count_sq.c.tech_id)
        .filter(User.role == "technician")
    )

    total = q.count()
    rows = q.order_by(User.name).offset(offset).limit(limit).all()

    items = [
        TechnicianListItem(
            id=user.id,
            code=user.code,
            name=user.name,
            email=user.email,
            role=user.role,
            reports_count=reports_count,
            last_sync_at=user.last_sync_at,
        )
        for user, reports_count in rows
    ]

    return {"total": total, "offset": offset, "limit": limit, "items": [i.model_dump() for i in items]}


# ---------------------------------------------------------------------------
# GET /api/admin/printers
# ---------------------------------------------------------------------------

@router.get("/printers", response_model=dict)
def list_printers(
    client_id: str | None = Query(None),
    printer_status: str | None = Query(None),
    search: str | None = Query(None),
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=200),
    db: Session = Depends(get_db),
) -> dict:
    """List printers with their last service status, model info, and optional search."""
    # Subquery: latest report per printer
    latest_report_sq = (
        db.query(
            Report.printer_id,
            func.max(Report.service_date).label("max_date"),
        )
        .group_by(Report.printer_id)
        .subquery()
    )
    latest_full_sq = (
        db.query(Report.printer_id, Report.service_date, Report.technical_checkboxes)
        .join(
            latest_report_sq,
            (Report.printer_id == latest_report_sq.c.printer_id)
            & (Report.service_date == latest_report_sq.c.max_date),
        )
        .subquery()
    )

    q = (
        db.query(
            Printer,
            Client.name.label("client_name"),
            Plant.name.label("plant_name"),
            Area.name.label("area_name"),
            CatalogModel.brand.label("model_brand"),
            CatalogModel.model_name.label("model_name"),
            CatalogModel.dpi.label("model_dpi"),
            latest_full_sq.c.service_date.label("last_service_date"),
            latest_full_sq.c.technical_checkboxes.label("last_checkboxes"),
        )
        .outerjoin(Client, Printer.client_id == Client.id)
        .outerjoin(Plant, Printer.plant_id == Plant.id)
        .outerjoin(Area, Printer.area_id == Area.id)
        .outerjoin(CatalogModel, Printer.model_id == CatalogModel.id)
        .outerjoin(latest_full_sq, Printer.id == latest_full_sq.c.printer_id)
    )

    if client_id:
        q = q.filter(Printer.client_id == client_id)
    if search:
        pattern = f"%{search}%"
        q = q.filter(
            Printer.serial_number.ilike(pattern)
            | Printer.code.ilike(pattern)
            | CatalogModel.model_name.ilike(pattern)
            | CatalogModel.brand.ilike(pattern)
        )

    rows = q.order_by(Printer.serial_number).offset(offset).limit(limit).all()
    total = q.count()

    items = []
    for printer, client_name, plant_name, area_name, model_brand, model_name, model_dpi, last_service_date, last_checkboxes in rows:
        status = _printer_status(last_checkboxes)
        if printer_status and status != printer_status:
            continue
        items.append(
            PrinterListItem(
                id=printer.id,
                code=printer.code,
                serial_number=printer.serial_number,
                client_name=client_name,
                plant_name=plant_name,
                area_name=area_name,
                model_brand=model_brand,
                model_name=model_name,
                model_dpi=model_dpi,
                last_service_date=last_service_date,
                printer_status=status,
            )
        )

    return {"total": total, "offset": offset, "limit": limit, "items": [i.model_dump() for i in items]}


# ---------------------------------------------------------------------------
# GET /api/admin/policies
# ---------------------------------------------------------------------------

@router.get("/policies", response_model=dict)
def list_policies(
    client_id: str | None = Query(None),
    status: str | None = Query(None),
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=200),
    db: Session = Depends(get_db),
) -> dict:
    """List policies with computed status and printer count."""
    printer_count_sq = (
        db.query(PolicyPrinter.policy_id, func.count(PolicyPrinter.id).label("cnt"))
        .group_by(PolicyPrinter.policy_id)
        .subquery()
    )

    q = (
        db.query(
            Policy,
            Client.name.label("client_name"),
            func.coalesce(printer_count_sq.c.cnt, 0).label("printer_count"),
        )
        .join(Client, Policy.client_id == Client.id)
        .outerjoin(printer_count_sq, Policy.id == printer_count_sq.c.policy_id)
    )

    if client_id:
        q = q.filter(Policy.client_id == client_id)

    rows = q.order_by(Policy.end_date).offset(offset).limit(limit).all()
    total = q.count()

    items = []
    for policy, client_name, printer_count in rows:
        computed_status = _policy_status(policy.end_date)
        if status and computed_status != status:
            continue
        items.append(
            PolicyListItem(
                id=policy.id,
                code=policy.code,
                folio=policy.folio,
                client_name=client_name,
                coverage_type=policy.coverage_type,
                start_date=policy.start_date,
                end_date=policy.end_date,
                status=computed_status,
                printer_count=printer_count,
                sla_notes=policy.sla_notes,
            )
        )

    return {"total": total, "offset": offset, "limit": limit, "items": [i.model_dump() for i in items]}


# ---------------------------------------------------------------------------
# GET /api/admin/sync/history
# ---------------------------------------------------------------------------

@router.get("/sync/history", response_model=dict)
def sync_history(
    status: str | None = Query(None),
    entity_type: str | None = Query(None),
    offset: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    db: Session = Depends(get_db),
) -> dict:
    """Paginated sync log history."""
    q = db.query(SyncLog)

    if status:
        q = q.filter(SyncLog.status == status)
    if entity_type:
        q = q.filter(SyncLog.entity_type == entity_type)

    total = q.count()
    rows = q.order_by(SyncLog.synced_at.desc()).offset(offset).limit(limit).all()

    items = [
        SyncHistoryItem(
            id=row.id,
            entity_type=row.entity_type,
            entity_id=row.entity_id,
            action=row.action,
            status=row.status,
            error_message=row.error_message,
            synced_at=row.synced_at,
            server_response=row.server_response,
        )
        for row in rows
    ]

    return {"total": total, "offset": offset, "limit": limit, "items": [i.model_dump() for i in items]}


# ===========================================================================
# Shared helpers
# ===========================================================================

def _next_code(db: Session, model, prefix: str, digits: int = 4) -> str:
    """Generate the next incremental readable code like C-0001, I-0001..."""
    pattern = f"{prefix}-%"
    rows = db.query(model.code).filter(model.code.like(pattern)).all()
    nums = []
    for (code,) in rows:
        if code:
            try:
                nums.append(int(code[len(prefix) + 1:]))
            except ValueError:
                pass
    return f"{prefix}-{max(nums, default=0) + 1:0{digits}d}"


def _hash_password(password: str) -> str:
    """Hash a password using PBKDF2-HMAC-SHA256 with a random salt."""
    salt = secrets.token_hex(16)
    dk = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 260_000)
    return f"{salt}${dk.hex()}"


# ===========================================================================
# FASE 3 — Gestión de Pólizas
# ===========================================================================

def _next_policy_code(db: Session) -> str:
    """Generate the next incremental code P-001, P-002..."""
    rows = db.query(Policy.code).filter(Policy.code.like("P-%")).all()
    nums = []
    for (code,) in rows:
        if code:
            try:
                nums.append(int(code[2:]))
            except ValueError:
                pass
    return f"P-{max(nums, default=0) + 1:03d}"


def _policy_detail(policy: Policy, db: Session) -> PolicyDetail:
    """Build a PolicyDetail response with assigned printers."""
    printer_rows = (
        db.query(Printer, Plant.name.label("plant_name"), Area.name.label("area_name"))
        .join(PolicyPrinter, PolicyPrinter.printer_id == Printer.id)
        .outerjoin(Plant, Printer.plant_id == Plant.id)
        .outerjoin(Area, Printer.area_id == Area.id)
        .filter(PolicyPrinter.policy_id == policy.id)
        .all()
    )
    printers = [
        PolicyPrinterItem(
            id=p.id,
            code=p.code,
            serial_number=p.serial_number,
            plant_name=plant_name,
            area_name=area_name,
        )
        for p, plant_name, area_name in printer_rows
    ]
    client = db.get(Client, policy.client_id)
    return PolicyDetail(
        id=policy.id,
        code=policy.code,
        folio=policy.folio,
        client_id=policy.client_id,
        client_name=client.name if client else policy.client_id,
        coverage_type=policy.coverage_type,
        start_date=policy.start_date,
        end_date=policy.end_date,
        status=_policy_status(policy.end_date),
        printer_count=len(printers),
        sla_notes=policy.sla_notes,
        printers=printers,
    )


# ---------------------------------------------------------------------------
# POST /api/admin/policies  — Crear póliza
# ---------------------------------------------------------------------------

@router.post("/policies", response_model=dict, status_code=201)
def create_policy(body: PolicyCreate, db: Session = Depends(get_db)) -> dict:
    """Create a new maintenance policy."""
    if not db.get(Client, body.client_id):
        raise HTTPException(status_code=404, detail="Client not found")

    if body.start_date >= body.end_date:
        raise HTTPException(status_code=422, detail="start_date must be before end_date")

    if db.query(Policy).filter(Policy.folio == body.folio).first():
        raise HTTPException(status_code=409, detail=f"Folio '{body.folio}' already exists")

    policy = Policy(
        id=str(uuid.uuid4()),
        code=_next_policy_code(db),
        client_id=body.client_id,
        folio=body.folio,
        start_date=body.start_date,
        end_date=body.end_date,
        coverage_type=body.coverage_type,
        sla_notes=body.sla_notes,
        status=_policy_status(body.end_date),
    )
    db.add(policy)
    db.commit()
    db.refresh(policy)
    return _policy_detail(policy, db).model_dump()


# ---------------------------------------------------------------------------
# GET /api/admin/policies/{policy_id}  — Detalle
# ---------------------------------------------------------------------------

@router.get("/policies/{policy_id}", response_model=dict)
def get_policy(policy_id: str, db: Session = Depends(get_db)) -> dict:
    """Get policy detail including assigned printers."""
    policy = db.get(Policy, policy_id)
    if not policy:
        raise HTTPException(status_code=404, detail="Policy not found")
    return _policy_detail(policy, db).model_dump()


# ---------------------------------------------------------------------------
# PUT /api/admin/policies/{policy_id}  — Editar
# ---------------------------------------------------------------------------

@router.put("/policies/{policy_id}", response_model=dict)
def update_policy(
    policy_id: str, body: PolicyUpdate, db: Session = Depends(get_db)
) -> dict:
    """Update mutable fields of a policy and recalculate status."""
    policy = db.get(Policy, policy_id)
    if not policy:
        raise HTTPException(status_code=404, detail="Policy not found")

    if body.folio is not None:
        conflict = (
            db.query(Policy)
            .filter(Policy.folio == body.folio, Policy.id != policy_id)
            .first()
        )
        if conflict:
            raise HTTPException(status_code=409, detail=f"Folio '{body.folio}' already exists")
        policy.folio = body.folio

    if body.start_date is not None:
        policy.start_date = body.start_date
    if body.end_date is not None:
        policy.end_date = body.end_date
    if body.coverage_type is not None:
        policy.coverage_type = body.coverage_type
    if body.sla_notes is not None:
        policy.sla_notes = body.sla_notes

    if policy.start_date >= policy.end_date:
        raise HTTPException(status_code=422, detail="start_date must be before end_date")

    policy.status = _policy_status(policy.end_date)
    db.commit()
    db.refresh(policy)
    return _policy_detail(policy, db).model_dump()


# ---------------------------------------------------------------------------
# DELETE /api/admin/policies/{policy_id}  — Soft delete
# ---------------------------------------------------------------------------

@router.delete("/policies/{policy_id}", status_code=200)
def delete_policy(policy_id: str, db: Session = Depends(get_db)) -> dict:
    """Soft-delete a policy by setting its status to 'Deleted'."""
    policy = db.get(Policy, policy_id)
    if not policy:
        raise HTTPException(status_code=404, detail="Policy not found")
    if policy.status == "Deleted":
        raise HTTPException(status_code=409, detail="Policy is already deleted")

    policy.status = "Deleted"
    db.commit()
    return {"success": True, "id": policy_id}


# ---------------------------------------------------------------------------
# POST /api/admin/policies/{policy_id}/printers  — Asignar impresoras
# ---------------------------------------------------------------------------

@router.post("/policies/{policy_id}/printers", status_code=200)
def assign_printers(
    policy_id: str, body: AssignPrintersRequest, db: Session = Depends(get_db)
) -> dict:
    """Assign one or more printers to a policy. Validates same client."""
    policy = db.get(Policy, policy_id)
    if not policy:
        raise HTTPException(status_code=404, detail="Policy not found")

    added, skipped, invalid = [], [], []

    for printer_id in body.printer_ids:
        printer = db.get(Printer, printer_id)
        if not printer:
            invalid.append(printer_id)
            continue

        if printer.client_id != policy.client_id:
            raise HTTPException(
                status_code=422,
                detail=f"Printer {printer.serial_number} belongs to a different client",
            )

        already = (
            db.query(PolicyPrinter)
            .filter(
                PolicyPrinter.policy_id == policy_id,
                PolicyPrinter.printer_id == printer_id,
            )
            .first()
        )
        if already:
            skipped.append(printer_id)
            continue

        db.add(PolicyPrinter(id=str(uuid.uuid4()), policy_id=policy_id, printer_id=printer_id))
        added.append(printer_id)

    db.commit()
    return {"success": True, "added": added, "skipped": skipped, "invalid": invalid}


# ---------------------------------------------------------------------------
# DELETE /api/admin/policies/{policy_id}/printers/{printer_id}  — Quitar impresora
# ---------------------------------------------------------------------------

@router.delete("/policies/{policy_id}/printers/{printer_id}", status_code=200)
def remove_printer_from_policy(
    policy_id: str, printer_id: str, db: Session = Depends(get_db)
) -> dict:
    """Remove a printer from a policy."""
    link = (
        db.query(PolicyPrinter)
        .filter(
            PolicyPrinter.policy_id == policy_id,
            PolicyPrinter.printer_id == printer_id,
        )
        .first()
    )
    if not link:
        raise HTTPException(status_code=404, detail="Printer not assigned to this policy")

    db.delete(link)
    db.commit()
    return {"success": True, "policy_id": policy_id, "printer_id": printer_id}


# ===========================================================================
# CRUD — Técnicos
# ===========================================================================

@router.post("/technicians", response_model=dict, status_code=201)
def create_technician(body: TechnicianCreate, db: Session = Depends(get_db)) -> dict:
    """Create a new technician user."""
    if db.query(User).filter(User.email == body.email).first():
        raise HTTPException(status_code=409, detail=f"Email '{body.email}' already exists")

    tech = User(
        id=str(uuid.uuid4()),
        code=_next_code(db, User, "T"),
        name=body.name,
        email=body.email,
        password_hash=_hash_password(body.password),
        role=body.role,
        is_active=True,
    )
    db.add(tech)
    db.commit()
    db.refresh(tech)
    return TechnicianListItem(
        id=tech.id,
        code=tech.code,
        name=tech.name,
        email=tech.email,
        role=tech.role,
        reports_count=0,
        last_sync_at=None,
    ).model_dump()


@router.put("/technicians/{tech_id}", response_model=dict)
def update_technician(
    tech_id: str, body: TechnicianUpdate, db: Session = Depends(get_db)
) -> dict:
    """Update a technician's mutable fields."""
    tech = db.get(User, tech_id)
    if not tech:
        raise HTTPException(status_code=404, detail="Technician not found")

    if body.email is not None:
        conflict = db.query(User).filter(User.email == body.email, User.id != tech_id).first()
        if conflict:
            raise HTTPException(status_code=409, detail=f"Email '{body.email}' already exists")
        tech.email = body.email
    if body.name is not None:
        tech.name = body.name
    if body.role is not None:
        tech.role = body.role

    db.commit()
    db.refresh(tech)

    reports_count = (
        db.query(func.count(Report.id)).filter(Report.tech_id == tech_id).scalar() or 0
    )
    return TechnicianListItem(
        id=tech.id,
        code=tech.code,
        name=tech.name,
        email=tech.email,
        role=tech.role,
        reports_count=reports_count,
        last_sync_at=tech.last_sync_at,
    ).model_dump()


@router.delete("/technicians/{tech_id}", status_code=200)
def delete_technician(tech_id: str, db: Session = Depends(get_db)) -> dict:
    """Soft-delete a technician (set is_active=False)."""
    tech = db.get(User, tech_id)
    if not tech:
        raise HTTPException(status_code=404, detail="Technician not found")
    if not tech.is_active:
        raise HTTPException(status_code=409, detail="Technician is already inactive")

    tech.is_active = False
    db.commit()
    return {"success": True, "id": tech_id}


# ===========================================================================
# CRUD — Clientes
# ===========================================================================

@router.post("/clients", response_model=dict, status_code=201)
def create_client(body: ClientCreate, db: Session = Depends(get_db)) -> dict:
    """Create a new client."""
    client = Client(
        id=str(uuid.uuid4()),
        name=body.name,
        rfc=body.rfc,
        address=body.address,
        is_active=True,
    )
    db.add(client)
    db.commit()
    db.refresh(client)
    return ClientListItem(
        id=client.id,
        name=client.name,
        rfc=client.rfc,
        address=client.address,
        is_active=client.is_active,
        plant_count=0,
        printer_count=0,
        active_policy_count=0,
    ).model_dump()


@router.put("/clients/{client_id}", response_model=dict)
def update_client(
    client_id: str, body: ClientUpdate, db: Session = Depends(get_db)
) -> dict:
    """Update a client's mutable fields."""
    client = db.get(Client, client_id)
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")

    if body.name is not None:
        client.name = body.name
    if body.rfc is not None:
        client.rfc = body.rfc
    if body.address is not None:
        client.address = body.address

    db.commit()
    db.refresh(client)

    plant_count = db.query(func.count(Plant.id)).filter(Plant.client_id == client_id).scalar() or 0
    printer_count = db.query(func.count(Printer.id)).filter(Printer.client_id == client_id).scalar() or 0
    active_policy_count = (
        db.query(func.count(Policy.id))
        .filter(Policy.client_id == client_id, Policy.status == "Active")
        .scalar() or 0
    )
    return ClientListItem(
        id=client.id,
        name=client.name,
        rfc=client.rfc,
        address=client.address,
        is_active=client.is_active,
        plant_count=plant_count,
        printer_count=printer_count,
        active_policy_count=active_policy_count,
    ).model_dump()


@router.delete("/clients/{client_id}", status_code=200)
def delete_client(client_id: str, db: Session = Depends(get_db)) -> dict:
    """Soft-delete a client (set is_active=False)."""
    client = db.get(Client, client_id)
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")
    if not client.is_active:
        raise HTTPException(status_code=409, detail="Client is already inactive")

    client.is_active = False
    db.commit()
    return {"success": True, "id": client_id}


# ===========================================================================
# Plants & Areas (auxiliares para crear impresoras)
# ===========================================================================

@router.get("/plants", response_model=dict)
def list_plants(
    client_id: str | None = Query(None),
    db: Session = Depends(get_db),
) -> dict:
    """List plants, optionally filtered by client."""
    q = db.query(Plant)
    if client_id:
        q = q.filter(Plant.client_id == client_id)
    rows = q.order_by(Plant.name).all()
    items = [PlantListItem(id=p.id, name=p.name, client_id=p.client_id).model_dump() for p in rows]
    return {"total": len(items), "items": items}


@router.post("/plants", response_model=dict, status_code=201)
def create_plant(body: PlantCreate, db: Session = Depends(get_db)) -> dict:
    """Create a new plant for a client."""
    if not db.get(Client, body.client_id):
        raise HTTPException(status_code=404, detail="Client not found")

    plant = Plant(
        id=str(uuid.uuid4()),
        client_id=body.client_id,
        name=body.name,
    )
    db.add(plant)
    db.commit()
    db.refresh(plant)
    return PlantListItem(id=plant.id, name=plant.name, client_id=plant.client_id).model_dump()


@router.get("/areas", response_model=dict)
def list_areas(
    plant_id: str | None = Query(None),
    db: Session = Depends(get_db),
) -> dict:
    """List areas, optionally filtered by plant."""
    q = db.query(Area)
    if plant_id:
        q = q.filter(Area.plant_id == plant_id)
    rows = q.order_by(Area.name).all()
    items = [AreaListItem(id=a.id, name=a.name, plant_id=a.plant_id).model_dump() for a in rows]
    return {"total": len(items), "items": items}


@router.post("/areas", response_model=dict, status_code=201)
def create_area(body: AreaCreate, db: Session = Depends(get_db)) -> dict:
    """Create a new area inside a plant."""
    if not db.get(Plant, body.plant_id):
        raise HTTPException(status_code=404, detail="Plant not found")

    area = Area(
        id=str(uuid.uuid4()),
        plant_id=body.plant_id,
        name=body.name,
    )
    db.add(area)
    db.commit()
    db.refresh(area)
    return AreaListItem(id=area.id, name=area.name, plant_id=area.plant_id).model_dump()


@router.get("/catalog/models", response_model=dict)
def list_catalog_models(db: Session = Depends(get_db)) -> dict:
    """List active printer models from the catalog."""
    rows = db.query(CatalogModel).filter(CatalogModel.is_active.is_(True)).order_by(
        CatalogModel.brand, CatalogModel.model_name
    ).all()
    items = [
        CatalogModelItem(id=m.id, brand=m.brand, model_name=m.model_name, dpi=m.dpi).model_dump()
        for m in rows
    ]
    return {"total": len(items), "items": items}


@router.post("/catalog/models", response_model=dict, status_code=201)
def create_catalog_model(body: CatalogModelCreate, db: Session = Depends(get_db)) -> dict:
    """Create a new printer model in the catalog."""
    model = CatalogModel(
        id=str(uuid.uuid4()),
        brand=body.brand,
        model_name=body.model_name,
        dpi=body.dpi,
        is_active=True,
    )
    db.add(model)
    db.commit()
    db.refresh(model)
    return CatalogModelItem(id=model.id, brand=model.brand, model_name=model.model_name, dpi=model.dpi).model_dump()


# ===========================================================================
# CRUD — Impresoras
# ===========================================================================

@router.post("/printers", response_model=dict, status_code=201)
def create_printer(body: PrinterCreate, db: Session = Depends(get_db)) -> dict:
    """Create a new printer."""
    if not db.get(Client, body.client_id):
        raise HTTPException(status_code=404, detail="Client not found")
    if not db.get(Plant, body.plant_id):
        raise HTTPException(status_code=404, detail="Plant not found")
    if not db.get(Area, body.area_id):
        raise HTTPException(status_code=404, detail="Area not found")
    if not db.get(CatalogModel, body.model_id):
        raise HTTPException(status_code=404, detail="Model not found")

    if db.query(Printer).filter(Printer.serial_number == body.serial_number).first():
        raise HTTPException(status_code=409, detail=f"Serial '{body.serial_number}' already exists")

    printer = Printer(
        id=str(uuid.uuid4()),
        code=_next_code(db, Printer, "I"),
        qr_uuid=body.qr_uuid or str(uuid.uuid4()),
        serial_number=body.serial_number,
        client_id=body.client_id,
        plant_id=body.plant_id,
        area_id=body.area_id,
        model_id=body.model_id,
        is_active=True,
    )
    db.add(printer)
    db.commit()
    db.refresh(printer)

    plant = db.get(Plant, body.plant_id)
    area = db.get(Area, body.area_id)
    client = db.get(Client, body.client_id)
    catalog_model = db.get(CatalogModel, body.model_id)
    return PrinterListItem(
        id=printer.id,
        code=printer.code,
        serial_number=printer.serial_number,
        client_name=client.name if client else None,
        plant_name=plant.name if plant else None,
        area_name=area.name if area else None,
        model_brand=catalog_model.brand if catalog_model else None,
        model_name=catalog_model.model_name if catalog_model else None,
        last_service_date=None,
        printer_status="Sin Historial",
    ).model_dump()


@router.put("/printers/{printer_id}", response_model=dict)
def update_printer(
    printer_id: str, body: PrinterUpdate, db: Session = Depends(get_db)
) -> dict:
    """Update a printer's mutable fields."""
    printer = db.get(Printer, printer_id)
    if not printer:
        raise HTTPException(status_code=404, detail="Printer not found")

    if body.serial_number is not None:
        conflict = (
            db.query(Printer)
            .filter(Printer.serial_number == body.serial_number, Printer.id != printer_id)
            .first()
        )
        if conflict:
            raise HTTPException(status_code=409, detail=f"Serial '{body.serial_number}' already exists")
        printer.serial_number = body.serial_number
    if body.client_id is not None:
        if not db.get(Client, body.client_id):
            raise HTTPException(status_code=404, detail="Client not found")
        printer.client_id = body.client_id
    if body.plant_id is not None:
        if not db.get(Plant, body.plant_id):
            raise HTTPException(status_code=404, detail="Plant not found")
        printer.plant_id = body.plant_id
    if body.area_id is not None:
        if not db.get(Area, body.area_id):
            raise HTTPException(status_code=404, detail="Area not found")
        printer.area_id = body.area_id
    if body.model_id is not None:
        if not db.get(CatalogModel, body.model_id):
            raise HTTPException(status_code=404, detail="Model not found")
        printer.model_id = body.model_id

    db.commit()
    db.refresh(printer)

    plant = db.get(Plant, printer.plant_id)
    area = db.get(Area, printer.area_id)
    client = db.get(Client, printer.client_id)
    catalog_model = db.get(CatalogModel, printer.model_id)
    return PrinterListItem(
        id=printer.id,
        code=printer.code,
        serial_number=printer.serial_number,
        client_name=client.name if client else None,
        plant_name=plant.name if plant else None,
        area_name=area.name if area else None,
        model_brand=catalog_model.brand if catalog_model else None,
        model_name=catalog_model.model_name if catalog_model else None,
        last_service_date=None,
        printer_status="Sin Historial",
    ).model_dump()


@router.delete("/printers/{printer_id}", status_code=200)
def delete_printer(printer_id: str, db: Session = Depends(get_db)) -> dict:
    """Soft-delete a printer (set is_active=False)."""
    printer = db.get(Printer, printer_id)
    if not printer:
        raise HTTPException(status_code=404, detail="Printer not found")
    if not printer.is_active:
        raise HTTPException(status_code=409, detail="Printer is already inactive")

    printer.is_active = False
    db.commit()
    return {"success": True, "id": printer_id}
