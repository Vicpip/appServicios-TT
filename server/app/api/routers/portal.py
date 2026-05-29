"""Client portal router — /api/portal

Auth endpoints (open):
  POST /api/portal/invite           Admin sends invite (requires internal JWT)
  POST /api/portal/register         Client registers via invite token
  POST /api/portal/login            Portal client login → JWT
  POST /api/portal/forgot-password  Request password-reset email
  POST /api/portal/reset-password   Apply new password via reset token

Portal data endpoints (require portal JWT via get_current_portal_user):
  GET  /api/portal/me
  GET  /api/portal/printers
  GET  /api/portal/printers/{id}
  GET  /api/portal/reports
  GET  /api/portal/reports/{id}
  GET  /api/portal/policies
"""

from __future__ import annotations

import secrets
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path
from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import RedirectResponse
from passlib.context import CryptContext
from sqlalchemy import func
from sqlalchemy.orm import Session


from app.auth import create_access_token, get_current_user
from app.config import get_settings
from app.database import get_db
from app.models.catalog import CatalogModel
from app.models.client import Client
from app.models.file import EntityFile, File
from app.models.plant import Plant
from app.models.policy import Policy, PolicyDelivery, PolicyDeliveryReport, PolicyPrinter
from app.models.portal import PortalInvitation, PortalPasswordReset, PortalUser
from app.models.printer import Printer
from app.models.report import Report
from app.models.area import Area
from app.models.user import User
from app.portal_auth import get_current_portal_user
from app.schemas.portal import (
    ForgotPasswordRequest,
    ForgotPasswordResponse,
    InviteInfoResponse,
    InviteRequest,
    InviteResponse,
    PortalDeliveryReportItem,
    PortalLoginRequest,
    PortalLoginResponse,
    PortalPolicyDeliveryDetail,
    PortalPolicyDeliveryItem,
    PortalPolicyDetail,
    PortalPolicyDetailPrinter,
    PortalPolicyItem,
    PortalPrinterDetail,
    PortalPrinterListItem,
    PortalReportDetail,
    PortalReportFiles,
    PortalReportListItem,
    PortalReportListResponse,
    PortalUserAdminItem,
    PortalUserInfo,
    PortalUserToggleRequest,
    PortalUserToggleResponse,
    RegisterRequest,
    RegisterResponse,
    ResetPasswordRequest,
    ResetPasswordResponse,
)
from app.services import email_service

_settings = get_settings()

router = APIRouter(prefix="/api/portal", tags=["portal"])

_pwd_ctx = CryptContext(schemes=["bcrypt"], deprecated="auto")

_PORTAL_ROLE = "portal_client"
_INVITE_TTL_HOURS = 48
_RESET_TTL_HOURS = 1


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _now_utc() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _hash_password(plain: str) -> str:
    return _pwd_ctx.hash(plain)


def _verify_password(plain: str, hashed: str) -> bool:
    return _pwd_ctx.verify(plain, hashed)


def _portal_token(portal_user: PortalUser, db: Session) -> str:
    """Create a JWT for a portal user with role='portal_client'."""
    client: Client | None = db.get(Client, portal_user.client_id)
    plant: Plant | None = db.get(Plant, portal_user.plant_id) if portal_user.plant_id else None
    return create_access_token(
        data={
            "sub": portal_user.id,
            "email": portal_user.email,
            "role": _PORTAL_ROLE,
            "client_id": portal_user.client_id,
            "plant_id": portal_user.plant_id,
            "name": portal_user.name,
            "client_name": client.name if client else "",
            "plant_name": plant.name if plant else None,
        }
    )


def _get_printer_ids_in_scope(portal_user: PortalUser, db: Session) -> list[str]:
    """Return the list of printer IDs visible to this portal user."""
    q = db.query(Printer.id).filter(
        Printer.client_id == portal_user.client_id,
        Printer.is_active.is_(True),
    )
    if portal_user.plant_id is not None:
        q = q.filter(Printer.plant_id == portal_user.plant_id)
    return [row[0] for row in q.all()]


def _resolve_portal_user(payload: dict, db: Session) -> PortalUser:
    """Load and validate a PortalUser from a decoded JWT payload."""
    portal_user: PortalUser | None = db.get(PortalUser, payload["sub"])
    if not portal_user or not portal_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario del portal no encontrado o inactivo",
        )
    return portal_user


# ---------------------------------------------------------------------------
# GET /api/portal/client-logo  (public — no auth required)
# ---------------------------------------------------------------------------

@router.get("/client-logo")
def get_client_logo(
    client_id: str = Query(...),
    db: Session = Depends(get_db),
) -> RedirectResponse:
    client = db.get(Client, client_id)
    if not client or not client.logo_path:
        raise HTTPException(status_code=404, detail="Logo not found")
    return RedirectResponse(url=f"/uploads/{client.logo_path}", status_code=302)


# ---------------------------------------------------------------------------
# GET /api/portal/invite/info
# ---------------------------------------------------------------------------


@router.get("/invite/info", response_model=InviteInfoResponse)
def get_invite_info(
    token: str = Query(...),
    db: Session = Depends(get_db),
) -> InviteInfoResponse:
    """Public: return email and client name for a valid pending invite token."""
    invitation: PortalInvitation | None = (
        db.query(PortalInvitation)
        .filter(PortalInvitation.token == token)
        .first()
    )

    if (
        not invitation
        or invitation.status != "pending"
        or invitation.expires_at < _now_utc()
    ):
        raise HTTPException(status_code=404, detail="Invitación no válida o expirada")

    client: Client | None = db.get(Client, invitation.client_id)

    return InviteInfoResponse(
        email=invitation.email,
        client_name=client.name if client else "",
    )


# ---------------------------------------------------------------------------
# POST /api/portal/invite
# ---------------------------------------------------------------------------


@router.post("/invite", response_model=InviteResponse, status_code=status.HTTP_201_CREATED)
def invite_client(
    body: InviteRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
) -> InviteResponse:
    """Internal-only: admin/technician invites a client contact to the portal."""

    # Validate client exists
    client: Client | None = db.get(Client, body.client_id)
    if not client:
        raise HTTPException(status_code=404, detail="Cliente no encontrado")

    # Validate plant if provided
    if body.plant_id:
        plant: Plant | None = db.get(Plant, body.plant_id)
        if not plant or plant.client_id != body.client_id:
            raise HTTPException(
                status_code=400, detail="Planta no pertenece al cliente"
            )

    # Check inviter exists
    inviter: User | None = db.get(User, current_user["sub"])
    if not inviter:
        raise HTTPException(status_code=404, detail="Técnico no encontrado")

    # Expire previous pending invitations for this email + client
    (
        db.query(PortalInvitation)
        .filter(
            PortalInvitation.email == body.email,
            PortalInvitation.client_id == body.client_id,
            PortalInvitation.status == "pending",
        )
        .update({"status": "expired"})
    )

    token = secrets.token_urlsafe(32)
    now = _now_utc()
    invitation = PortalInvitation(
        id=str(uuid.uuid4()),
        client_id=body.client_id,
        plant_id=body.plant_id,
        invited_by=current_user["sub"],
        email=body.email,
        token=token,
        status="pending",
        expires_at=now + timedelta(hours=_INVITE_TTL_HOURS),
        created_at=now,
    )
    db.add(invitation)
    db.commit()
    db.refresh(invitation)

    # Send email (non-blocking — errors are logged, not raised)
    email_service.send_invitation_email(body.email, token, client.name)

    return InviteResponse(
        id=invitation.id,
        email=invitation.email,
        client_id=invitation.client_id,
        plant_id=invitation.plant_id,
        status=invitation.status,
        expires_at=invitation.expires_at,
        created_at=invitation.created_at,
    )


# ---------------------------------------------------------------------------
# POST /api/portal/register
# ---------------------------------------------------------------------------


@router.post("/register", response_model=RegisterResponse, status_code=status.HTTP_201_CREATED)
def register(body: RegisterRequest, db: Session = Depends(get_db)) -> RegisterResponse:
    """Client registers using a valid invite token."""

    invitation: PortalInvitation | None = (
        db.query(PortalInvitation)
        .filter(PortalInvitation.token == body.token)
        .first()
    )

    if not invitation:
        raise HTTPException(status_code=404, detail="Token de invitación no encontrado")

    if invitation.status != "pending":
        raise HTTPException(
            status_code=400,
            detail="El token de invitación ya fue utilizado o ha expirado",
        )

    if invitation.expires_at < _now_utc():
        invitation.status = "expired"
        db.commit()
        raise HTTPException(status_code=400, detail="El token de invitación ha expirado")

    # Ensure email is not already registered
    existing: PortalUser | None = (
        db.query(PortalUser).filter(PortalUser.email == invitation.email).first()
    )
    if existing:
        raise HTTPException(
            status_code=409, detail="Ya existe una cuenta con este correo electrónico"
        )

    now = _now_utc()
    portal_user = PortalUser(
        id=str(uuid.uuid4()),
        client_id=invitation.client_id,
        plant_id=invitation.plant_id,
        email=invitation.email,
        password_hash=_hash_password(body.password),
        name=body.name,
        is_active=True,
        created_at=now,
    )
    db.add(portal_user)

    invitation.status = "accepted"
    invitation.accepted_at = now
    db.commit()
    db.refresh(portal_user)

    email_service.send_welcome_email(portal_user.email, portal_user.name)

    return RegisterResponse(
        id=portal_user.id,
        email=portal_user.email,
        name=portal_user.name,
        client_id=portal_user.client_id,
        plant_id=portal_user.plant_id,
        created_at=portal_user.created_at,
    )


# ---------------------------------------------------------------------------
# POST /api/portal/login
# ---------------------------------------------------------------------------


@router.post("/login", response_model=PortalLoginResponse)
def login(body: PortalLoginRequest, db: Session = Depends(get_db)) -> PortalLoginResponse:
    """Portal client login. Returns a JWT with role='portal_client'."""

    portal_user: PortalUser | None = (
        db.query(PortalUser).filter(PortalUser.email == body.email).first()
    )

    if not portal_user or not portal_user.password_hash:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciales incorrectas",
        )

    if not _verify_password(body.password, portal_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciales incorrectas",
        )

    if not portal_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cuenta desactivada",
        )

    # Update last_login_at
    portal_user.last_login_at = _now_utc()
    db.commit()

    # Resolve names for UserInfo
    client: Client | None = db.get(Client, portal_user.client_id)
    plant: Plant | None = (
        db.get(Plant, portal_user.plant_id) if portal_user.plant_id else None
    )

    token = _portal_token(portal_user, db)

    return PortalLoginResponse(
        access_token=token,
        token_type="bearer",
        user=PortalUserInfo(
            id=portal_user.id,
            email=portal_user.email,
            name=portal_user.name,
            client_id=portal_user.client_id,
            client_name=client.name if client else "",
            plant_id=portal_user.plant_id,
            plant_name=plant.name if plant else None,
            is_active=portal_user.is_active,
            last_login_at=portal_user.last_login_at,
        ),
    )


# ---------------------------------------------------------------------------
# POST /api/portal/forgot-password
# ---------------------------------------------------------------------------


@router.post("/forgot-password", response_model=ForgotPasswordResponse)
def forgot_password(
    body: ForgotPasswordRequest, db: Session = Depends(get_db)
) -> ForgotPasswordResponse:
    """Request a password-reset email. Always returns 200 to avoid email enumeration."""

    portal_user: PortalUser | None = (
        db.query(PortalUser).filter(PortalUser.email == body.email).first()
    )

    if portal_user and portal_user.is_active:
        token = secrets.token_urlsafe(32)
        now = _now_utc()
        reset = PortalPasswordReset(
            id=str(uuid.uuid4()),
            portal_user_id=portal_user.id,
            token=token,
            used=False,
            expires_at=now + timedelta(hours=_RESET_TTL_HOURS),
            created_at=now,
        )
        db.add(reset)
        db.commit()

        email_service.send_password_reset_email(portal_user.email, token)

    return ForgotPasswordResponse(
        message="Si el correo existe en nuestro sistema, recibirá un enlace de restablecimiento."
    )


# ---------------------------------------------------------------------------
# POST /api/portal/reset-password
# ---------------------------------------------------------------------------


@router.post("/reset-password", response_model=ResetPasswordResponse)
def reset_password(
    body: ResetPasswordRequest, db: Session = Depends(get_db)
) -> ResetPasswordResponse:
    """Apply a new password using a valid reset token."""

    reset: PortalPasswordReset | None = (
        db.query(PortalPasswordReset)
        .filter(PortalPasswordReset.token == body.token)
        .first()
    )

    if not reset:
        raise HTTPException(status_code=404, detail="Token de restablecimiento no encontrado")

    if reset.used:
        raise HTTPException(status_code=400, detail="El token ya fue utilizado")

    if reset.expires_at < _now_utc():
        raise HTTPException(status_code=400, detail="El token ha expirado")

    portal_user: PortalUser | None = db.get(PortalUser, reset.portal_user_id)
    if not portal_user or not portal_user.is_active:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    portal_user.password_hash = _hash_password(body.new_password)
    reset.used = True
    db.commit()

    return ResetPasswordResponse(message="Contraseña actualizada correctamente")


# ===========================================================================
# Portal data endpoints — all require a valid portal JWT
# ===========================================================================


# ---------------------------------------------------------------------------
# GET /api/portal/me
# ---------------------------------------------------------------------------


@router.get("/me", response_model=PortalUserInfo)
def get_me(
    db: Session = Depends(get_db),
    payload: dict = Depends(get_current_portal_user),
) -> PortalUserInfo:
    """Return authenticated portal user info including client and plant names."""
    portal_user = _resolve_portal_user(payload, db)

    client: Client | None = db.get(Client, portal_user.client_id)
    plant: Plant | None = (
        db.get(Plant, portal_user.plant_id) if portal_user.plant_id else None
    )

    return PortalUserInfo(
        id=portal_user.id,
        email=portal_user.email,
        name=portal_user.name,
        client_id=portal_user.client_id,
        client_name=client.name if client else "",
        plant_id=portal_user.plant_id,
        plant_name=plant.name if plant else None,
        is_active=portal_user.is_active,
        last_login_at=portal_user.last_login_at,
    )


# ---------------------------------------------------------------------------
# GET /api/portal/printers
# ---------------------------------------------------------------------------


@router.get("/printers", response_model=list[PortalPrinterListItem])
def list_printers(
    db: Session = Depends(get_db),
    payload: dict = Depends(get_current_portal_user),
) -> list[PortalPrinterListItem]:
    """Return printers in scope filtered by the portal user's plant access."""
    portal_user = _resolve_portal_user(payload, db)

    q = (
        db.query(Printer)
        .filter(
            Printer.client_id == portal_user.client_id,
            Printer.is_active.is_(True),
        )
    )
    if portal_user.plant_id is not None:
        q = q.filter(Printer.plant_id == portal_user.plant_id)

    printers = q.all()

    items: list[PortalPrinterListItem] = []
    for p in printers:
        plant = db.get(Plant, p.plant_id)
        area = db.get(Area, p.area_id)
        catalog_model = db.get(CatalogModel, p.model_id)

        # Latest service date
        latest_report = (
            db.query(Report.service_date)
            .filter(Report.printer_id == p.id)
            .order_by(Report.service_date.desc())
            .first()
        )

        items.append(
            PortalPrinterListItem(
                id=p.id,
                serial_number=p.serial_number,
                code=p.code,
                plant_id=p.plant_id,
                plant_name=plant.name if plant else None,
                area_id=p.area_id,
                area_name=area.name if area else None,
                model_brand=catalog_model.brand if catalog_model else None,
                model_name=catalog_model.model_name if catalog_model else None,
                is_active=p.is_active,
                last_service_date=latest_report[0] if latest_report else None,
            )
        )
    return items


# ---------------------------------------------------------------------------
# GET /api/portal/printers/{printer_id}
# ---------------------------------------------------------------------------


@router.get("/printers/{printer_id}", response_model=PortalPrinterDetail)
def get_printer(
    printer_id: str,
    db: Session = Depends(get_db),
    payload: dict = Depends(get_current_portal_user),
) -> PortalPrinterDetail:
    """Return detail for a single printer — must be within the user's scope."""
    portal_user = _resolve_portal_user(payload, db)

    printer: Printer | None = db.get(Printer, printer_id)
    if not printer or printer.client_id != portal_user.client_id:
        raise HTTPException(status_code=404, detail="Impresora no encontrada")

    if portal_user.plant_id and printer.plant_id != portal_user.plant_id:
        raise HTTPException(status_code=403, detail="Acceso denegado a esta impresora")

    plant = db.get(Plant, printer.plant_id)
    area = db.get(Area, printer.area_id)
    catalog_model = db.get(CatalogModel, printer.model_id)

    return PortalPrinterDetail(
        id=printer.id,
        serial_number=printer.serial_number,
        code=printer.code,
        client_id=printer.client_id,
        plant_id=printer.plant_id,
        plant_name=plant.name if plant else None,
        area_id=printer.area_id,
        area_name=area.name if area else None,
        model_brand=catalog_model.brand if catalog_model else None,
        model_name=catalog_model.model_name if catalog_model else None,
        model_dpi=catalog_model.dpi if catalog_model else None,
        is_active=printer.is_active,
    )


# ---------------------------------------------------------------------------
# GET /api/portal/reports
# ---------------------------------------------------------------------------


@router.get("/reports", response_model=PortalReportListResponse)
def list_reports(
    printer_id: str | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
    payload: dict = Depends(get_current_portal_user),
) -> PortalReportListResponse:
    """Return reports for all printers in scope, ordered by service_date desc."""
    portal_user = _resolve_portal_user(payload, db)

    printer_ids = _get_printer_ids_in_scope(portal_user, db)

    if not printer_ids:
        return PortalReportListResponse(total=0, offset=offset, limit=limit, items=[])

    q = db.query(Report).filter(Report.printer_id.in_(printer_ids))

    if printer_id:
        if printer_id not in printer_ids:
            raise HTTPException(
                status_code=403, detail="Acceso denegado a esta impresora"
            )
        q = q.filter(Report.printer_id == printer_id)

    total = q.count()
    reports = q.order_by(Report.service_date.desc()).offset(offset).limit(limit).all()

    items: list[PortalReportListItem] = []
    for r in reports:
        printer = db.get(Printer, r.printer_id)
        items.append(
            PortalReportListItem(
                id=r.id,
                code=r.code,
                printer_id=r.printer_id,
                printer_serial=printer.serial_number if printer else None,
                service_type=r.service_type,
                status=r.status,
                service_date=r.service_date,
                notes=r.notes,
                created_at=r.created_at,
            )
        )

    return PortalReportListResponse(total=total, offset=offset, limit=limit, items=items)


# ---------------------------------------------------------------------------
# GET /api/portal/reports/{report_id}
# ---------------------------------------------------------------------------


@router.get("/reports/{report_id}", response_model=PortalReportDetail)
def get_report(
    report_id: str,
    db: Session = Depends(get_db),
    payload: dict = Depends(get_current_portal_user),
) -> PortalReportDetail:
    """Return full detail for a single report — must belong to an in-scope printer."""
    portal_user = _resolve_portal_user(payload, db)

    report: Report | None = db.get(Report, report_id)
    if not report:
        raise HTTPException(status_code=404, detail="Reporte no encontrado")

    # Verify report's printer is in scope
    printer_ids = _get_printer_ids_in_scope(portal_user, db)
    if report.printer_id not in printer_ids:
        raise HTTPException(
            status_code=403, detail="Acceso denegado a este reporte"
        )

    printer = db.get(Printer, report.printer_id)
    tech = db.get(User, report.tech_id)
    client = db.get(Client, printer.client_id) if printer else None

    return PortalReportDetail(
        id=report.id,
        code=report.code,
        printer_id=report.printer_id,
        printer_serial=printer.serial_number if printer else None,
        tech_id=report.tech_id,
        tech_name=tech.name if tech else None,
        service_type=report.service_type,
        status=report.status,
        service_date=report.service_date,
        linear_inches_counter=report.linear_inches_counter,
        darkness_level=report.darkness_level,
        technical_checkboxes=report.technical_checkboxes,
        notes=report.notes,
        signature_name=report.signature_name,
        signature_role=report.signature_role,
        photo_count=report.photo_count,
        sync_date=report.sync_date,
        created_at=report.created_at,
        client_name=client.name if client else None,
        signature_image_path=report.signature_image_path,
        photo_paths=report.photo_paths or "[]",
    )


# ---------------------------------------------------------------------------
# GET /api/portal/reports/{report_id}/files
# ---------------------------------------------------------------------------


@router.get("/reports/{report_id}/files", response_model=PortalReportFiles)
def get_report_files(
    report_id: str,
    db: Session = Depends(get_db),
    payload: dict = Depends(get_current_portal_user),
) -> PortalReportFiles:
    """Return photo/signature/PDF URLs for a report within the portal user's scope."""
    portal_user = _resolve_portal_user(payload, db)

    report: Report | None = db.get(Report, report_id)
    if not report:
        raise HTTPException(status_code=404, detail="Reporte no encontrado")

    printer_ids = _get_printer_ids_in_scope(portal_user, db)
    if report.printer_id not in printer_ids:
        raise HTTPException(status_code=403, detail="Acceso denegado a este reporte")

    rows = (
        db.query(EntityFile, File)
        .join(File, EntityFile.file_id == File.id)
        .filter(
            EntityFile.entity_id == report_id,
            EntityFile.entity_type == "report",
        )
        .all()
    )

    upload_dir_path = Path(_settings.upload_dir)
    photos: list[str] = []
    signature: str | None = None
    pdf: str | None = None

    for ef, f in rows:
        try:
            rel = Path(f.storage_path).relative_to(upload_dir_path)
            url = f"/uploads/{rel.as_posix()}"
        except ValueError:
            url = f"/uploads/{f.storage_path.lstrip('/')}"
        if ef.file_category == "photo":
            photos.append(url)
        elif ef.file_category == "signature":
            signature = url
        elif ef.file_category == "pdf":
            pdf = url

    # Fallback: use raw paths from report if EntityFile table is empty
    if not photos and report.photo_paths and report.photo_paths != "[]":
        import json
        raw_paths = json.loads(report.photo_paths)
        photos = [f"/uploads/{p.lstrip('/')}" if not p.startswith("/uploads") else p for p in raw_paths]

    if not signature and report.signature_image_path:
        sig = report.signature_image_path
        signature = f"/uploads/{sig.lstrip('/')}" if not sig.startswith("/uploads") else sig

    return PortalReportFiles(photos=photos, signature=signature, pdf=pdf)


# ---------------------------------------------------------------------------
# GET /api/portal/policies
# ---------------------------------------------------------------------------


@router.get("/policies", response_model=list[PortalPolicyItem])
def list_policies(
    db: Session = Depends(get_db),
    payload: dict = Depends(get_current_portal_user),
) -> list[PortalPolicyItem]:
    """Return active/current policies for the portal user's client."""
    portal_user = _resolve_portal_user(payload, db)

    policies = (
        db.query(Policy)
        .filter(
            Policy.client_id == portal_user.client_id,
            Policy.status.in_(["active", "Active", "Activa"]),
        )
        .order_by(Policy.end_date.desc())
        .all()
    )

    items: list[PortalPolicyItem] = []
    for p in policies:
        printer_count = (
            db.query(func.count(PolicyPrinter.id))
            .filter(PolicyPrinter.policy_id == p.id)
            .scalar()
        ) or 0
        items.append(
            PortalPolicyItem(
                id=p.id,
                folio=p.folio,
                coverage_type=p.coverage_type,
                start_date=p.start_date,
                end_date=p.end_date,
                status=p.status,
                sla_notes=p.sla_notes,
                frequency_maintenance=p.frequency_maintenance,
                printer_count=printer_count,
            )
        )
    return items


# ---------------------------------------------------------------------------
# GET /api/portal/policies/{policy_id}
# ---------------------------------------------------------------------------


@router.get("/policies/{policy_id}", response_model=PortalPolicyDetail)
def get_policy(
    policy_id: str,
    db: Session = Depends(get_db),
    payload: dict = Depends(get_current_portal_user),
) -> PortalPolicyDetail:
    """Return full detail for a single policy — must belong to the portal user's client."""
    portal_user = _resolve_portal_user(payload, db)

    policy: Policy | None = db.get(Policy, policy_id)
    if not policy or policy.client_id != portal_user.client_id:
        raise HTTPException(status_code=404, detail="Póliza no encontrada")

    client: Client | None = db.get(Client, policy.client_id)

    # Printers
    policy_printers = (
        db.query(PolicyPrinter)
        .filter(PolicyPrinter.policy_id == policy_id)
        .all()
    )
    printers: list[PortalPolicyDetailPrinter] = []
    for pp in policy_printers:
        printer: Printer | None = db.get(Printer, pp.printer_id)
        if not printer:
            continue
        plant = db.get(Plant, printer.plant_id) if printer.plant_id else None
        area = db.get(Area, printer.area_id) if printer.area_id else None
        catalog_model = db.get(CatalogModel, printer.model_id) if printer.model_id else None
        model_name: str | None = None
        if catalog_model:
            model_name = f"{catalog_model.brand} {catalog_model.model_name}".strip()
        printers.append(
            PortalPolicyDetailPrinter(
                id=printer.id,
                serial_number=printer.serial_number,
                code=printer.code,
                plant_name=plant.name if plant else None,
                area_name=area.name if area else None,
                model_name=model_name,
            )
        )

    # Deliveries
    deliveries_db = (
        db.query(PolicyDelivery)
        .filter(PolicyDelivery.policy_id == policy_id)
        .order_by(PolicyDelivery.delivery_date.desc())
        .all()
    )
    deliveries: list[PortalPolicyDeliveryItem] = []
    for d in deliveries_db:
        tech: User | None = db.get(User, d.tech_id)
        report_count = (
            db.query(func.count(PolicyDeliveryReport.id))
            .filter(PolicyDeliveryReport.delivery_id == d.id)
            .scalar()
        ) or 0
        deliveries.append(
            PortalPolicyDeliveryItem(
                id=d.id,
                delivery_date=d.delivery_date,
                signature_name=d.signature_name,
                signature_role=d.signature_role,
                tech_name=tech.name if tech else None,
                report_count=report_count,
            )
        )

    return PortalPolicyDetail(
        id=policy.id,
        folio=policy.folio,
        coverage_type=policy.coverage_type,
        start_date=policy.start_date,
        end_date=policy.end_date,
        status=policy.status,
        sla_notes=policy.sla_notes,
        frequency_maintenance=policy.frequency_maintenance,
        client_name=client.name if client else "",
        printer_count=len(printers),
        printers=printers,
        deliveries=deliveries,
    )


# ---------------------------------------------------------------------------
# GET /api/portal/policies/{policy_id}/deliveries/{delivery_id}
# ---------------------------------------------------------------------------


@router.get(
    "/policies/{policy_id}/deliveries/{delivery_id}",
    response_model=PortalPolicyDeliveryDetail,
)
def get_policy_delivery(
    policy_id: str,
    delivery_id: str,
    db: Session = Depends(get_db),
    payload: dict = Depends(get_current_portal_user),
) -> PortalPolicyDeliveryDetail:
    """Return detail for a single policy delivery including per-report rows."""
    portal_user = _resolve_portal_user(payload, db)

    policy: Policy | None = db.get(Policy, policy_id)
    if not policy or policy.client_id != portal_user.client_id:
        raise HTTPException(status_code=404, detail="Póliza no encontrada")

    delivery: PolicyDelivery | None = db.get(PolicyDelivery, delivery_id)
    if not delivery or delivery.policy_id != policy_id:
        raise HTTPException(status_code=404, detail="Entrega no encontrada")

    tech: User | None = db.get(User, delivery.tech_id)

    delivery_reports_db = (
        db.query(PolicyDeliveryReport)
        .filter(PolicyDeliveryReport.delivery_id == delivery_id)
        .all()
    )
    reports: list[PortalDeliveryReportItem] = []
    for dr in delivery_reports_db:
        report: Report | None = db.get(Report, dr.report_id)
        if not report:
            continue
        printer: Printer | None = db.get(Printer, report.printer_id)
        catalog_model = (
            db.get(CatalogModel, printer.model_id)
            if printer and printer.model_id
            else None
        )
        model_name: str | None = None
        if catalog_model:
            model_name = f"{catalog_model.brand} {catalog_model.model_name}".strip()
        reports.append(
            PortalDeliveryReportItem(
                report_id=dr.report_id,
                serial_number=printer.serial_number if printer else None,
                model_name=model_name,
                service_type=report.service_type,
                service_date=report.service_date,
                status=report.status,
            )
        )

    return PortalPolicyDeliveryDetail(
        id=delivery.id,
        delivery_date=delivery.delivery_date,
        signature_name=delivery.signature_name,
        signature_role=delivery.signature_role,
        tech_name=tech.name if tech else None,
        report_count=len(reports),
        reports=reports,
    )


# ===========================================================================
# Admin management endpoints — require internal JWT (get_current_user)
# ===========================================================================


# ---------------------------------------------------------------------------
# GET /api/portal/admin/clients/{client_id}/users
# ---------------------------------------------------------------------------


@router.get(
    "/admin/clients/{client_id}/users",
    response_model=list[PortalUserAdminItem],
)
def list_client_portal_users(
    client_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
) -> list[PortalUserAdminItem]:
    """Admin: list all portal users registered for a given client."""
    client: Client | None = db.get(Client, client_id)
    if not client:
        raise HTTPException(status_code=404, detail="Cliente no encontrado")

    users = (
        db.query(PortalUser)
        .filter(PortalUser.client_id == client_id)
        .order_by(PortalUser.created_at.desc())
        .all()
    )

    items: list[PortalUserAdminItem] = []
    for u in users:
        plant_name: str | None = None
        if u.plant_id:
            plant: Plant | None = db.get(Plant, u.plant_id)
            plant_name = plant.name if plant else None
        items.append(
            PortalUserAdminItem(
                id=u.id,
                email=u.email,
                name=u.name,
                is_active=u.is_active,
                last_login_at=u.last_login_at,
                plant_id=u.plant_id,
                plant_name=plant_name,
                created_at=u.created_at,
            )
        )
    return items


# ---------------------------------------------------------------------------
# PATCH /api/portal/admin/users/{user_id}/toggle-active
# ---------------------------------------------------------------------------


@router.patch(
    "/admin/users/{user_id}/toggle-active",
    response_model=PortalUserToggleResponse,
)
def toggle_portal_user_active(
    user_id: str,
    body: PortalUserToggleRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
) -> PortalUserToggleResponse:
    """Admin: activate or deactivate a portal user."""
    portal_user: PortalUser | None = db.get(PortalUser, user_id)
    if not portal_user:
        raise HTTPException(status_code=404, detail="Usuario del portal no encontrado")

    portal_user.is_active = body.is_active
    db.commit()

    return PortalUserToggleResponse(
        id=portal_user.id,
        email=portal_user.email,
        name=portal_user.name,
        is_active=portal_user.is_active,
    )
