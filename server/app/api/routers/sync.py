import hashlib
import json
import logging
import os
import re
import uuid
from datetime import datetime, timezone
from pathlib import Path

log = logging.getLogger(__name__)

from fastapi import APIRouter, Depends, HTTPException, UploadFile, Form
from starlette.concurrency import run_in_threadpool
from sqlalchemy.orm import Session

from app.auth import get_current_active_user
from app.config import get_settings
from app.services.delivery_pdf_service import generate_delivery_pdf
from app.database import get_db
from app.models.area import Area
from app.models.catalog import CatalogModel
from app.models.client import Client
from app.models.file import EntityFile, File
from app.models.plant import Plant
from app.models.policy import Policy, PolicyDelivery, PolicyDeliveryReport, PolicyPrinter, PolicyPrinterAssignment, PolicyVisit
from app.models.printer import Printer
from app.models.report import Report
from app.models.sync import SyncLog
from app.models.user import User
from app.schemas.admin import PolicyDeliveryCreate
from app.services import delivery_email_service
from app.services.visit_service import auto_complete_if_all_delivered
from app.schemas.report import ReportCreate
from app.schemas.sync import (
    BulkSyncRequest,
    BulkSyncResponse,
    EntitiesUpsertRequest,
    EntitiesUpsertResponse,
    SyncPayload,
    SyncResponse,
)

router = APIRouter(prefix="/api", tags=["sync"])

settings = get_settings()


# ---------------------------------------------------------------------------
# Helper utilities
# ---------------------------------------------------------------------------


def _now_utc() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _record_sync_log(
    db: Session,
    *,
    entity_type: str,
    entity_id: str,
    action: str,
    status: str,
    error_message: str | None = None,
    server_response: str | None = None,
) -> None:
    log = SyncLog(
        id=str(uuid.uuid4()),
        entity_type=entity_type,
        entity_id=entity_id,
        action=action,
        status=status,
        error_message=error_message,
        server_response=server_response,
        synced_at=_now_utc(),
    )
    db.add(log)


def _upsert_report(db: Session, data: ReportCreate) -> Report:
    """Insert or update a report record (upsert by primary key id)."""
    existing: Report | None = db.get(Report, data.id)

    photo_paths_json = json.dumps(data.photo_paths)
    checkboxes_json = json.dumps(data.technical_checkboxes)

    if existing:
        # Update all mutable fields
        existing.code = data.code
        existing.printer_id = data.printer_id
        existing.tech_id = data.tech_id
        existing.service_type = data.service_type
        existing.status = data.status
        existing.service_date = data.service_date
        existing.linear_inches_counter = data.linear_inches_counter
        existing.darkness_level = data.darkness_level
        existing.label_type_id = data.label_type_id
        existing.technical_checkboxes = checkboxes_json
        existing.notes = data.notes
        existing.signature_name = data.signature_name
        existing.signature_role = data.signature_role
        existing.signature_image_path = data.signature_image_path
        existing.internal_notes = data.internal_notes
        existing.supersedes_report_id = data.supersedes_report_id
        existing.photo_paths = photo_paths_json
        existing.photo_count = data.photo_count
        existing.signature_block_id = data.signature_block_id
        existing.report_block_status = data.report_block_status
        existing.sync_date = _now_utc()
        report = existing
    else:
        report = Report(
            id=data.id,
            code=data.code,
            printer_id=data.printer_id,
            tech_id=data.tech_id,
            service_type=data.service_type,
            status=data.status,
            service_date=data.service_date,
            linear_inches_counter=data.linear_inches_counter,
            darkness_level=data.darkness_level,
            label_type_id=data.label_type_id,
            technical_checkboxes=checkboxes_json,
            notes=data.notes,
            signature_name=data.signature_name,
            signature_role=data.signature_role,
            signature_image_path=data.signature_image_path,
            internal_notes=data.internal_notes,
            supersedes_report_id=data.supersedes_report_id,
            photo_paths=photo_paths_json,
            photo_count=data.photo_count,
            signature_block_id=data.signature_block_id,
            report_block_status=data.report_block_status,
            sync_date=_now_utc(),
            created_at=data.created_at or _now_utc(),
        )
        db.add(report)

    return report


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


def _user_name(db: Session, user_id: str | None) -> str | None:
    if not user_id:
        return None
    user = db.get(User, user_id)
    return user.name if user else None


@router.post("/reports", response_model=SyncResponse, status_code=200)
def sync_report(
    body: ReportCreate,
    db: Session = Depends(get_db),
    _current_user: dict = Depends(get_current_active_user),
) -> SyncResponse:
    """Upsert a single report received from the mobile app."""
    try:
        action = "update" if db.get(Report, body.id) else "insert"
        report = _upsert_report(db, body)
        db.flush()
        _record_sync_log(
            db,
            entity_type="report",
            entity_id=body.id,
            action=action,
            status="synced",
            server_response=json.dumps({"id": report.id}),
        )
        db.commit()
        return SyncResponse(
            success=True,
            entity_id=body.id,
            server_id=report.id,
            message="Report synced successfully",
        )
    except Exception as exc:
        db.rollback()
        _record_sync_log(
            db,
            entity_type="report",
            entity_id=body.id,
            action="upsert",
            status="error",
            error_message=str(exc),
        )
        try:
            db.commit()
        except Exception:
            db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to sync report: {exc}")


@router.post("/reports/bulk", response_model=BulkSyncResponse, status_code=200)
def sync_reports_bulk(
    body: BulkSyncRequest,
    db: Session = Depends(get_db),
    _current_user: dict = Depends(get_current_active_user),
) -> BulkSyncResponse:
    """Upsert multiple reports in a single request."""
    results: list[SyncResponse] = []
    succeeded = 0
    failed = 0

    for item in body.items:
        try:
            report_data = ReportCreate(**item.payload)
            report = _upsert_report(db, report_data)
            db.flush()
            _record_sync_log(
                db,
                entity_type="report",
                entity_id=item.entity_id,
                action="upsert",
                status="synced",
            )
            results.append(
                SyncResponse(
                    success=True,
                    entity_id=item.entity_id,
                    server_id=report.id,
                    message="Synced",
                )
            )
            succeeded += 1
        except Exception as exc:
            db.rollback()
            _record_sync_log(
                db,
                entity_type="report",
                entity_id=item.entity_id,
                action="upsert",
                status="error",
                error_message=str(exc),
            )
            try:
                db.flush()
            except Exception:
                pass
            results.append(
                SyncResponse(
                    success=False,
                    entity_id=item.entity_id,
                    message="Failed to sync",
                    errors=[str(exc)],
                )
            )
            failed += 1

    try:
        db.commit()
    except Exception as exc:
        db.rollback()
        raise HTTPException(
            status_code=500, detail=f"Failed to commit bulk sync: {exc}"
        )

    return BulkSyncResponse(
        total=len(body.items),
        succeeded=succeeded,
        failed=failed,
        results=results,
    )


_SAFE_SEGMENT = re.compile(r"^[A-Za-z0-9_.-]{1,128}$")
_MAX_FILENAME_LEN = 120


def safe_upload_filename(name: str | None) -> str:
    """Solo el basename, sin separadores ni "..", con caracteres seguros y largo acotado."""
    base = (name or "").replace("\\", "/").split("/")[-1].replace(chr(0), "")
    base = re.sub(r"[^\w.\- ]+", "_", base).strip(" .")
    base = re.sub(r"\.{2,}", ".", base)
    if len(base) > _MAX_FILENAME_LEN:
        stem, dot, ext = base.rpartition(".")
        ext = ext[:10] if dot else ""
        base = (stem[: _MAX_FILENAME_LEN - len(ext) - 1] + "." + ext) if ext else base[:_MAX_FILENAME_LEN]
    return base or f"{uuid.uuid4()}.bin"


def _safe_segment(value: str, field: str) -> str:
    if not _SAFE_SEGMENT.match(value) or value in (".", ".."):
        raise HTTPException(status_code=400, detail=f"{field} no válido")
    return value


@router.post("/files", response_model=SyncResponse, status_code=200)
async def sync_file(
    entity_type: str = Form(...),
    entity_id: str = Form(...),
    file_category: str = Form(...),
    file: UploadFile = ...,
    db: Session = Depends(get_db),
    _current_user: dict = Depends(get_current_active_user),
) -> SyncResponse:
    """Receive a file (photo or signature) from the mobile app and persist it."""
    try:
        contents = await file.read()

        # Compute hash for deduplication
        file_hash = hashlib.sha256(contents).hexdigest()

        # Build storage path.
        # Normal files: UPLOAD_DIR/{entity_type}/{entity_id}/{file_category}/{filename}
        # When entity_type == file_category (e.g. delivery_pdf) skip the redundant subdir:
        #   UPLOAD_DIR/{entity_type}/{entity_id}/{filename}
        # entity_type / entity_id / file_category / filename vienen del cliente y
        # forman la ruta en disco: se validan y se comprueba que no salga de UPLOAD_DIR.
        _safe_segment(entity_type, "entity_type")
        _safe_segment(entity_id, "entity_id")
        _safe_segment(file_category, "file_category")
        filename = safe_upload_filename(file.filename)
        upload_root = Path(settings.upload_dir).resolve()
        if entity_type == file_category:
            dest_dir = upload_root / entity_type / entity_id
        else:
            dest_dir = upload_root / entity_type / entity_id / file_category
        dest_path = (dest_dir / filename).resolve()
        if not dest_path.is_relative_to(upload_root):
            raise HTTPException(status_code=400, detail="Nombre de archivo no válido")
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest_path.write_bytes(contents)

        storage_path = str(dest_path)
        content_type = file.content_type or "application/octet-stream"

        # Check if an identical file (same hash) already exists
        existing_file: File | None = (
            db.query(File).filter(File.file_hash == file_hash).first()
        )

        if existing_file:
            file_record = existing_file
        else:
            file_record = File(
                id=str(uuid.uuid4()),
                file_hash=file_hash,
                file_type=content_type,
                storage_path=storage_path,
                origin="mobile_sync",
                created_at=_now_utc(),
            )
            db.add(file_record)
            db.flush()

        entity_file = EntityFile(
            id=str(uuid.uuid4()),
            file_id=file_record.id,
            entity_id=entity_id,
            entity_type=entity_type,
            file_category=file_category,
        )
        db.add(entity_file)

        # Persist the public-relative path on the delivery so the admin web can link to it.
        if entity_type == "delivery_pdf":
            delivery_record = db.get(PolicyDelivery, entity_id)
            if delivery_record:
                delivery_record.pdf_path = f"uploads/{entity_type}/{entity_id}/{filename}"

        _record_sync_log(
            db,
            entity_type=entity_type,
            entity_id=entity_id,
            action="file_upload",
            status="synced",
            server_response=json.dumps({"storage_path": storage_path}),
        )
        db.commit()

        # When a client signature arrives for a delivery, regenerate the PDF so
        # it includes the signature.  policy_delivery is always processed before
        # signature by the mobile sync queue (priority 3 vs 5), so the first PDF
        # generated at delivery-creation time has no client signature.
        if entity_type == "signature":
            try:
                delivery_record = db.get(PolicyDelivery, entity_id)
                if delivery_record is not None:
                    pdf_relative = generate_delivery_pdf(entity_id, db)
                    if pdf_relative:
                        delivery_record.pdf_path = pdf_relative
                        db.commit()
                        log.info(
                            "sync_file: regenerated delivery PDF for %s → %s",
                            entity_id, pdf_relative,
                        )

                    linked = db.query(PolicyDeliveryReport).filter(
                        PolicyDeliveryReport.delivery_id == entity_id
                    ).all()
                    report_ids = [lr.report_id for lr in linked]
                    if report_ids:
                        db.query(Report).filter(Report.id.in_(report_ids)).update(
                            {
                                "signature_image_path": storage_path,
                                "signature_name": delivery_record.signature_name,
                                "signature_role": delivery_record.signature_role,
                            },
                            synchronize_session=False,
                        )
                        db.commit()

                    # Solo si el PDF se regeneró CON la firma: ¿están ya todos los demás?
                    if pdf_relative:
                        await run_in_threadpool(
                            delivery_email_service.trigger_for_delivery, db, entity_id
                        )
            except Exception:
                log.exception(
                    "sync_file: PDF regeneration failed for signature entity_id=%s (non-fatal)",
                    entity_id,
                )

        # Llegó el PDF de un reporte: si pertenece a una entrega, reintenta el
        # correo único (no envía nada si aún falta otro archivo).
        if entity_type == "report" and file_category == "pdf":
            try:
                await run_in_threadpool(
                    delivery_email_service.trigger_for_report_pdf, db, entity_id
                )
            except Exception:
                db.rollback()
                log.exception("sync_file: delivery email trigger failed (non-fatal)")

        return SyncResponse(
            success=True,
            entity_id=entity_id,
            server_id=file_record.id,
            message=storage_path,
        )
    except HTTPException:
        db.rollback()
        raise
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to upload file: {exc}")


@router.post("/sync/entities", response_model=EntitiesUpsertResponse, status_code=200)
def upsert_entities(
    body: EntitiesUpsertRequest,
    db: Session = Depends(get_db),
    _current_user: dict = Depends(get_current_active_user),
) -> EntitiesUpsertResponse:
    """Upsert a batch of mobile entities (users, clients, plants, areas, printers, catalog_models)
    in topological order so FK constraints are satisfied."""

    # Sort into topological order
    _ORDER = ["catalog_model", "user", "client", "plant", "area", "printer"]
    sorted_entities = sorted(
        body.entities,
        key=lambda e: _ORDER.index(e.type) if e.type in _ORDER else len(_ORDER),
    )

    succeeded = 0
    errors: list[str] = []

    for item in sorted_entities:
        try:
            d = item.data
            etype = item.type

            if etype == "catalog_model":
                existing = db.get(CatalogModel, d["id"])
                if existing:
                    existing.brand = d.get("brand", existing.brand)
                    existing.model_name = d.get("modelName", d.get("model_name", existing.model_name))
                    existing.dpi = d.get("dpi", existing.dpi)
                    existing.is_active = d.get("isActive", d.get("is_active", existing.is_active))
                else:
                    db.add(CatalogModel(
                        id=d["id"],
                        brand=d["brand"],
                        model_name=d.get("modelName", d.get("model_name", "")),
                        dpi=d.get("dpi", 203),
                        is_active=d.get("isActive", d.get("is_active", True)),
                    ))

            elif etype == "user":
                existing = db.get(User, d["id"])
                if existing:
                    existing.name = d.get("name", existing.name)
                    existing.email = d.get("email", existing.email)
                    existing.role = d.get("role", existing.role)
                    existing.code = d.get("code", existing.code)
                    existing.is_active = d.get("isActive", d.get("is_active", existing.is_active))
                else:
                    db.add(User(
                        id=d["id"],
                        name=d["name"],
                        email=d.get("email", f"{d['id']}@local.app"),
                        role=d.get("role", "technician"),
                        code=d.get("code"),
                        is_active=d.get("isActive", d.get("is_active", True)),
                    ))

            elif etype == "client":
                existing = db.get(Client, d["id"])
                if existing:
                    existing.name = d.get("name", existing.name)
                    existing.rfc = d.get("rfc", existing.rfc)
                    existing.address = d.get("address", existing.address)
                    existing.is_active = d.get("isActive", d.get("is_active", existing.is_active))
                else:
                    db.add(Client(
                        id=d["id"],
                        name=d["name"],
                        rfc=d.get("rfc"),
                        address=d.get("address"),
                        is_active=d.get("isActive", d.get("is_active", True)),
                    ))

            elif etype == "plant":
                existing = db.get(Plant, d["id"])
                if existing:
                    existing.name = d.get("name", existing.name)
                    existing.client_id = d.get("clientId", d.get("client_id", existing.client_id))
                    existing.contact_name = d.get("contactName", d.get("contact_name", existing.contact_name))
                    existing.phone = d.get("phone", existing.phone)
                else:
                    db.add(Plant(
                        id=d["id"],
                        client_id=d.get("clientId", d.get("client_id")),
                        name=d["name"],
                        contact_name=d.get("contactName", d.get("contact_name")),
                        phone=d.get("phone"),
                    ))

            elif etype == "area":
                existing = db.get(Area, d["id"])
                if existing:
                    existing.name = d.get("name", existing.name)
                    existing.plant_id = d.get("plantId", d.get("plant_id", existing.plant_id))
                else:
                    db.add(Area(
                        id=d["id"],
                        plant_id=d.get("plantId", d.get("plant_id")),
                        name=d["name"],
                    ))

            elif etype == "printer":
                existing = db.get(Printer, d["id"])
                if existing:
                    existing.code = d.get("code", existing.code)
                    existing.qr_uuid = d.get("qrUuid", d.get("qr_uuid", existing.qr_uuid))
                    existing.serial_number = d.get("serialNumber", d.get("serial_number", existing.serial_number))
                    existing.client_id = d.get("clientId", d.get("client_id", existing.client_id))
                    existing.plant_id = d.get("plantId", d.get("plant_id", existing.plant_id))
                    existing.area_id = d.get("areaId", d.get("area_id", existing.area_id))
                    existing.model_id = d.get("modelId", d.get("model_id", existing.model_id))
                    existing.is_active = d.get("isActive", d.get("is_active", existing.is_active))
                else:
                    db.add(Printer(
                        id=d["id"],
                        code=d.get("code"),
                        qr_uuid=d.get("qrUuid", d.get("qr_uuid", str(uuid.uuid4()))),
                        serial_number=d.get("serialNumber", d.get("serial_number", "")),
                        client_id=d.get("clientId", d.get("client_id")),
                        plant_id=d.get("plantId", d.get("plant_id")),
                        area_id=d.get("areaId", d.get("area_id")),
                        model_id=d.get("modelId", d.get("model_id")),
                        is_active=d.get("isActive", d.get("is_active", True)),
                    ))

            db.flush()
            succeeded += 1

        except Exception as exc:
            db.rollback()
            errors.append(f"{item.type}:{item.data.get('id', '?')} — {exc}")

    try:
        db.commit()
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to commit entities: {exc}")

    return EntitiesUpsertResponse(
        succeeded=succeeded,
        failed=len(errors),
        errors=errors,
    )


@router.get("/sync/download")
def download_data(
    db: Session = Depends(get_db),
    _current_user: dict = Depends(get_current_active_user),
) -> dict:
    """Return all active catalog data for the mobile app to seed its local DB."""
    from datetime import timedelta

    now = datetime.now(timezone.utc).replace(tzinfo=None)

    clients = [
        {"id": c.id, "name": c.name, "rfc": c.rfc, "address": c.address, "isActive": c.is_active}
        for c in db.query(Client).filter(Client.is_active.is_(True)).all()
    ]

    plants = [
        {"id": p.id, "clientId": p.client_id, "name": p.name,
         "contactName": p.contact_name, "phone": p.phone}
        for p in db.query(Plant).all()
    ]

    areas = [
        {"id": a.id, "plantId": a.plant_id, "name": a.name}
        for a in db.query(Area).all()
    ]

    catalog_models = [
        {"id": m.id, "brand": m.brand, "modelName": m.model_name, "dpi": m.dpi, "isActive": m.is_active}
        for m in db.query(CatalogModel).filter(CatalogModel.is_active.is_(True)).all()
    ]

    printers = [
        {
            "id": pr.id, "code": pr.code, "qrUuid": pr.qr_uuid,
            "serialNumber": pr.serial_number, "clientId": pr.client_id,
            "plantId": pr.plant_id, "areaId": pr.area_id,
            "modelId": pr.model_id, "isActive": pr.is_active,
        }
        for pr in db.query(Printer).filter(Printer.is_active.is_(True)).all()
    ]

    policies_q = (
        db.query(Policy)
        .filter(Policy.status != "Deleted")
        .all()
    )
    policies = []
    for p in policies_q:
        printer_ids = [
            pp.printer_id
            for pp in db.query(PolicyPrinter)
            .filter(PolicyPrinter.policy_id == p.id)
            .all()
        ]
        policies.append({
            "id": p.id, "code": p.code, "folio": p.folio,
            "clientId": p.client_id, "coverageType": p.coverage_type,
            "startDate": p.start_date.isoformat(),
            "endDate": p.end_date.isoformat(),
            "status": p.status, "slaNotes": p.sla_notes,
            "frequencyMaintenance": p.frequency_maintenance,
            "printerIds": printer_ids,
        })

    cutoff_90d = now - timedelta(days=90)
    reports = [
        {
            "id": r.id,
            "code": r.code,
            "printerId": r.printer_id,
            "techId": r.tech_id,
            "serviceType": r.service_type,
            "status": r.status,
            "serviceDate": r.service_date.isoformat() if r.service_date else None,
            "linearInchesCounter": r.linear_inches_counter,
            "darknessLevel": r.darkness_level,
            "technicalCheckboxes": r.technical_checkboxes,
            "notes": r.notes,
            "signatureName": r.signature_name,
            "signatureRole": r.signature_role,
            "photoCount": r.photo_count or 0,
        }
        for r in db.query(Report)
        .filter(Report.status != "Deleted", Report.service_date >= cutoff_90d)
        .all()
    ]

    assignments = db.query(PolicyPrinterAssignment).all()
    print(f"[Sync] assignments a enviar: {len(assignments)}")
    policy_assignments = [
        {
            "id": a.id,
            "policyId": a.policy_id,
            "printerId": a.printer_id,
            "technicianId": a.technician_id,
            "assignedAt": a.assigned_at.isoformat(),
        }
        for a in assignments
    ]

    technicians = [
        {
            "id": u.id,
            "code": u.code,
            "name": u.name,
            "email": u.email,
            "role": u.role,
        }
        for u in db.query(User).filter(User.role == "technician", User.is_active.is_(True)).all()
    ]

    policy_visits = [
        {
            "id": v.id,
            "policyId": v.policy_id,
            "visitNumber": v.visit_number,
            "scheduledDate": v.scheduled_date.isoformat() if v.scheduled_date else None,
            "status": v.status,
            "startedAt": v.started_at.isoformat() if v.started_at else None,
            "completedAt": v.completed_at.isoformat() if v.completed_at else None,
            "closedAt": v.closed_at.isoformat() if v.closed_at else None,
            "closedByName": _user_name(db, v.closed_by),
            "closedReason": v.closed_reason,
            "createdAt": v.created_at.isoformat() if v.created_at else None,
        }
        for v in db.query(PolicyVisit).all()
    ]

    return {
        "clients": clients,
        "plants": plants,
        "areas": areas,
        "catalogModels": catalog_models,
        "printers": printers,
        "policies": policies,
        "reports": reports,
        "technicians": technicians,
        "policyPrinterAssignments": policy_assignments,
        "policyVisits": policy_visits,
    }


@router.get("/policies/{policy_id}/assignment")
def check_assignment(
    policy_id: str,
    printer_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_active_user),
) -> dict:
    """Check if a printer in a policy is assigned to a specific technician."""
    assignment = (
        db.query(PolicyPrinterAssignment)
        .filter(
            PolicyPrinterAssignment.policy_id == policy_id,
            PolicyPrinterAssignment.printer_id == printer_id,
        )
        .first()
    )
    if not assignment:
        return {"assigned_tech_id": None, "assigned_tech_name": None,
                "assigned_tech_code": None, "is_assigned_to_me": False}

    tech = db.get(User, assignment.technician_id)
    is_mine = assignment.technician_id == current_user.get("sub")
    return {
        "assigned_tech_id": assignment.technician_id,
        "assigned_tech_name": tech.name if tech else None,
        "assigned_tech_code": tech.code if tech else None,
        "is_assigned_to_me": is_mine,
    }


@router.post("/policy-deliveries", response_model=dict, status_code=201)
def create_policy_delivery(
    body: PolicyDeliveryCreate,
    db: Session = Depends(get_db),
    _current_user: dict = Depends(get_current_active_user),
) -> dict:
    """Create a policy delivery from the mobile app. Marks all reports as 'signed'."""
    policy = db.get(Policy, body.policy_id)
    if not policy:
        raise HTTPException(status_code=404, detail="Policy not found")

    delivery = PolicyDelivery(
        id=body.id or str(uuid.uuid4()),
        policy_id=body.policy_id,
        delivery_date=body.delivery_date,
        signature_name=body.signature_name,
        signature_role=body.signature_role,
        tech_id=body.tech_id,
        signature_image_path=body.signature_image_path,
        visit_id=body.visit_id,
        extra_email=body.extra_email,
    )
    db.add(delivery)
    db.flush()

    reports: list[Report] = []
    for report_id in body.report_ids:
        db.add(PolicyDeliveryReport(
            id=str(uuid.uuid4()),
            delivery_id=delivery.id,
            report_id=report_id,
        ))
        report = db.get(Report, report_id)
        if report:
            report.status = "signed"
            report.signature_name = body.signature_name
            report.signature_role = body.signature_role
            reports.append(report)

    ef = (
        db.query(EntityFile)
        .join(EntityFile.file)
        .filter(
            EntityFile.entity_id == delivery.id,
            EntityFile.entity_type == "signature",
        )
        .order_by(EntityFile.id.desc())
        .first()
    )
    if ef and ef.file:
        for report in reports:
            report.signature_image_path = ef.file.storage_path

    if body.visit_id:
        visit = db.get(PolicyVisit, body.visit_id)
        if visit:
            # La visita solo se completa cuando TODOS los equipos de la póliza
            # tienen su reporte entregado/firmado dentro de esta visita. Si falta
            # alguno, sigue in_progress. Una visita ya completada (o cerrada
            # manualmente) no se vuelve a tocar.
            # SessionLocal usa autoflush=False: sin este flush la consulta no ve
            # los reportes que esta misma entrega acaba de marcar como signed.
            db.flush()
            auto_complete_if_all_delivered(db, visit)

    _record_sync_log(
        db,
        entity_type="policy_delivery",
        entity_id=delivery.id,
        action="insert",
        status="synced",
    )
    db.commit()
    db.refresh(delivery)

    # Generate delivery PDF non-fatally; signature may already be on disk
    # if Flutter re-ordered the queue (signature uploaded before this request).
    try:
        pdf_relative = generate_delivery_pdf(delivery.id, db)
        if pdf_relative:
            delivery.pdf_path = pdf_relative
            db.commit()
    except Exception:
        pass  # PDF generation never blocks the delivery response

    # Normalmente queda diferido (aún no llegan la firma ni los PDFs de los
    # reportes); solo sale si ya estaban todos en el servidor.
    delivery_email_service.trigger_for_delivery(db, delivery.id)

    return {
        "id": delivery.id,
        "policy_id": delivery.policy_id,
        "delivery_date": delivery.delivery_date.isoformat(),
        "signature_name": delivery.signature_name,
        "signature_role": delivery.signature_role,
        "tech_id": delivery.tech_id,
        "signature_image_path": delivery.signature_image_path,
        "report_count": len(body.report_ids),
        "pdf_path": delivery.pdf_path,
        "extra_email": delivery.extra_email,
    }


@router.get("/policies")
def get_policies_for_app(
    client_id: str | None = None,
    db: Session = Depends(get_db),
    _current_user: dict = Depends(get_current_active_user),
) -> list:
    """Return active/expiring policies for a client — consumed by the Flutter app."""
    from datetime import timedelta

    now = datetime.now(timezone.utc).replace(tzinfo=None)

    q = db.query(Policy).filter(Policy.status != "Deleted", Policy.end_date >= now)
    if client_id:
        q = q.filter(Policy.client_id == client_id)

    policies = q.order_by(Policy.end_date).all()

    result = []
    for p in policies:
        printer_ids = [
            pp.printer_id
            for pp in db.query(PolicyPrinter)
            .filter(PolicyPrinter.policy_id == p.id)
            .all()
        ]
        days_left = (p.end_date - now).days
        status = "Expiring" if days_left < 30 else "Active"
        result.append({
            "id": p.id,
            "code": p.code,
            "folio": p.folio,
            "client_id": p.client_id,
            "coverage_type": p.coverage_type,
            "start_date": p.start_date.isoformat(),
            "end_date": p.end_date.isoformat(),
            "status": status,
            "days_left": days_left,
            "sla_notes": p.sla_notes,
            "printer_ids": printer_ids,
        })
    return result


@router.get("/sync/status")
def sync_status(
    db: Session = Depends(get_db),
    _current_user: dict = Depends(get_current_active_user),
) -> dict:
    """Returns sync queue counts useful for the mobile dashboard."""
    from sqlalchemy import func as sa_func
    rows = (
        db.query(SyncLog.status, sa_func.count(SyncLog.id))
        .group_by(SyncLog.status)
        .all()
    )
    counts = {status: count for status, count in rows}
    return {
        "synced_total": counts.get("synced", 0),
        "failed": counts.get("error", 0),
        "pending_reports": 0,  # server has no pending queue; app owns that
    }


@router.get("/health")
def health_check(db: Session = Depends(get_db)) -> dict:
    """Simple liveness + DB connectivity check."""
    try:
        db.execute(__import__("sqlalchemy").text("SELECT 1"))
        db_status = "connected"
    except Exception:
        db_status = "error"
    return {"status": "ok", "db": db_status}
