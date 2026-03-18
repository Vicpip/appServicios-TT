from datetime import datetime

from pydantic import BaseModel, ConfigDict


class ReportListItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    code: str | None
    service_type: str
    status: str
    service_date: datetime
    sync_date: datetime | None
    printer_serial: str | None
    client_name: str | None
    tech_name: str | None


class ReportDetail(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    code: str | None
    printer_id: str
    tech_id: str
    service_type: str
    status: str
    service_date: datetime
    linear_inches_counter: int
    darkness_level: int | None
    label_type_id: str | None
    technical_checkboxes: str  # raw JSON string
    notes: str | None
    signature_name: str | None
    signature_role: str | None
    signature_image_path: str | None
    photo_paths: str  # raw JSON string
    photo_count: int
    internal_notes: str | None
    sync_date: datetime | None
    created_at: datetime
    # Joined fields
    printer_serial: str | None
    printer_code: str | None
    client_name: str | None
    tech_name: str | None
    tech_code: str | None


class ClientListItem(BaseModel):
    id: str
    name: str
    rfc: str | None
    address: str | None
    is_active: bool
    plant_count: int
    printer_count: int
    active_policy_count: int


class TechnicianListItem(BaseModel):
    id: str
    code: str | None
    name: str
    email: str
    role: str
    reports_count: int
    last_sync_at: datetime | None


class PrinterListItem(BaseModel):
    id: str
    code: str | None
    serial_number: str
    client_name: str | None
    plant_name: str | None
    area_name: str | None
    model_brand: str | None
    model_name: str | None
    model_dpi: int | None
    last_service_date: datetime | None
    printer_status: str  # "Correcto" | "En Atención" | "Sin Historial"


class PolicyListItem(BaseModel):
    id: str
    code: str | None
    folio: str
    client_name: str
    coverage_type: str
    start_date: datetime
    end_date: datetime
    status: str  # "Active" | "Expiring" | "Expired"
    printer_count: int
    sla_notes: str | None


class ReviewRequest(BaseModel):
    status: str  # "approved" | "rejected"
    notes: str | None = None


class SyncHistoryItem(BaseModel):
    id: str
    entity_type: str
    entity_id: str
    action: str
    status: str
    error_message: str | None
    synced_at: datetime
    server_response: str | None


class PaginatedResponse(BaseModel):
    total: int
    offset: int
    limit: int
    items: list


# ---------------------------------------------------------------------------
# Policy write schemas
# ---------------------------------------------------------------------------

class PolicyCreate(BaseModel):
    client_id: str
    folio: str
    start_date: datetime
    end_date: datetime
    coverage_type: str
    sla_notes: str | None = None


class PolicyUpdate(BaseModel):
    folio: str | None = None
    start_date: datetime | None = None
    end_date: datetime | None = None
    coverage_type: str | None = None
    sla_notes: str | None = None


class AssignPrintersRequest(BaseModel):
    printer_ids: list[str]


# ---------------------------------------------------------------------------
# Policy detail (with assigned printers)
# ---------------------------------------------------------------------------

class PolicyPrinterItem(BaseModel):
    id: str
    code: str | None
    serial_number: str
    plant_name: str | None
    area_name: str | None


class PolicyDetail(PolicyListItem):
    client_id: str
    printers: list[PolicyPrinterItem]


# ---------------------------------------------------------------------------
# CRUD write schemas
# ---------------------------------------------------------------------------

class TechnicianCreate(BaseModel):
    name: str
    email: str
    password: str
    role: str = "technician"


class TechnicianUpdate(BaseModel):
    name: str | None = None
    email: str | None = None
    role: str | None = None


class ClientCreate(BaseModel):
    name: str
    rfc: str | None = None
    address: str | None = None


class ClientUpdate(BaseModel):
    name: str | None = None
    rfc: str | None = None
    address: str | None = None


class PrinterCreate(BaseModel):
    serial_number: str
    qr_uuid: str | None = None
    client_id: str
    plant_id: str
    area_id: str
    model_id: str


class PrinterUpdate(BaseModel):
    serial_number: str | None = None
    client_id: str | None = None
    plant_id: str | None = None
    area_id: str | None = None
    model_id: str | None = None


class PlantCreate(BaseModel):
    client_id: str
    name: str


class PlantListItem(BaseModel):
    id: str
    name: str
    client_id: str


class AreaCreate(BaseModel):
    plant_id: str
    name: str


class AreaListItem(BaseModel):
    id: str
    name: str
    plant_id: str


class CatalogModelItem(BaseModel):
    id: str
    brand: str
    model_name: str
    dpi: int


class CatalogModelCreate(BaseModel):
    brand: str
    model_name: str
    dpi: int
