"""Pydantic schemas for the client portal API."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, EmailStr


# ---------------------------------------------------------------------------
# Auth — invite
# ---------------------------------------------------------------------------

class InviteInfoResponse(BaseModel):
    email: str
    client_name: str


class InviteRequest(BaseModel):
    email: EmailStr
    client_id: str
    plant_id: Optional[str] = None


class InviteResponse(BaseModel):
    id: str
    email: str
    client_id: str
    plant_id: Optional[str]
    status: str
    expires_at: datetime
    created_at: datetime


# ---------------------------------------------------------------------------
# Auth — register
# ---------------------------------------------------------------------------

class RegisterRequest(BaseModel):
    token: str
    name: str
    password: str


class RegisterResponse(BaseModel):
    id: str
    email: str
    name: str
    client_id: str
    plant_id: Optional[str]
    created_at: datetime


# ---------------------------------------------------------------------------
# Auth — login
# ---------------------------------------------------------------------------

class PortalLoginRequest(BaseModel):
    email: EmailStr
    password: str


class PortalLoginResponse(BaseModel):
    access_token: str
    token_type: str
    user: "PortalUserInfo"


# ---------------------------------------------------------------------------
# Auth — forgot / reset password
# ---------------------------------------------------------------------------

class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ForgotPasswordResponse(BaseModel):
    message: str


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str


class ResetPasswordResponse(BaseModel):
    message: str


# ---------------------------------------------------------------------------
# Portal data — /me
# ---------------------------------------------------------------------------

class PortalUserInfo(BaseModel):
    id: str
    email: str
    name: str
    client_id: str
    client_name: str
    plant_id: Optional[str]
    plant_name: Optional[str]
    is_active: bool
    last_login_at: Optional[datetime]


# ---------------------------------------------------------------------------
# Portal data — printers
# ---------------------------------------------------------------------------

class PortalPrinterListItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    serial_number: str
    code: Optional[str]
    plant_id: str
    plant_name: Optional[str]
    area_id: str
    area_name: Optional[str]
    model_brand: Optional[str]
    model_name: Optional[str]
    is_active: bool
    last_service_date: Optional[datetime]


class PortalPrinterDetail(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    serial_number: str
    code: Optional[str]
    client_id: str
    plant_id: str
    plant_name: Optional[str]
    area_id: str
    area_name: Optional[str]
    model_brand: Optional[str]
    model_name: Optional[str]
    model_dpi: Optional[int]
    is_active: bool


# ---------------------------------------------------------------------------
# Portal data — reports
# ---------------------------------------------------------------------------

class PortalReportListItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    code: Optional[str]
    printer_id: str
    printer_serial: Optional[str]
    service_type: str
    status: str
    service_date: datetime
    notes: Optional[str]
    created_at: datetime


class PortalReportDetail(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    code: Optional[str]
    printer_id: str
    printer_serial: Optional[str]
    tech_id: str
    tech_name: Optional[str]
    service_type: str
    status: str
    service_date: datetime
    linear_inches_counter: int
    darkness_level: Optional[int]
    technical_checkboxes: str
    notes: Optional[str]
    signature_name: Optional[str]
    signature_role: Optional[str]
    photo_count: int
    sync_date: Optional[datetime]
    created_at: datetime


class PortalReportListResponse(BaseModel):
    total: int
    offset: int
    limit: int
    items: list[PortalReportListItem]


# ---------------------------------------------------------------------------
# Portal data — policies
# ---------------------------------------------------------------------------

class PortalPolicyItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    folio: str
    coverage_type: str
    start_date: datetime
    end_date: datetime
    status: str
    sla_notes: Optional[str]
    frequency_maintenance: Optional[str]


# ---------------------------------------------------------------------------
# Admin management schemas
# ---------------------------------------------------------------------------

class PortalUserAdminItem(BaseModel):
    id: str
    email: str
    name: str
    is_active: bool
    last_login_at: Optional[datetime]
    plant_id: Optional[str]
    plant_name: Optional[str]
    created_at: datetime


class PortalUserToggleRequest(BaseModel):
    is_active: bool


class PortalUserToggleResponse(BaseModel):
    id: str
    email: str
    name: str
    is_active: bool


# Resolve forward reference
PortalLoginResponse.model_rebuild()
