from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, alias_generators, field_validator

from app.schemas.common import normalize_optional_email


class TechnicalCheckboxes(BaseModel):
    mantenimiento_general: bool = False
    calibracion_sensores: bool = False
    rodillo_danado: bool = False
    cabezal_danado: bool = False
    sensor_ribbon_danado: bool = False
    sensor_papel_danado: bool = False
    pruebas: bool = False
    otros: bool = False


class ReportCreate(BaseModel):
    # Accept both camelCase (from Flutter) and snake_case
    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=alias_generators.to_camel,
    )

    id: str
    code: str | None = None
    printer_id: str
    tech_id: str
    service_type: str
    status: str
    service_date: datetime
    linear_inches_counter: int
    darkness_level: float | None = None
    label_type_id: str | None = None
    technical_checkboxes: dict[str, bool]  # raw dict for flexibility
    notes: str | None = None
    signature_name: str | None = None
    signature_role: str | None = None
    signature_image_path: str | None = None
    internal_notes: str | None = None
    supersedes_report_id: str | None = None
    photo_paths: list[str] = []
    photo_count: int = 0
    signature_block_id: str | None = None
    report_block_status: str | None = None
    created_at: datetime | None = None


class ReportRead(ReportCreate):
    sync_date: datetime | None = None
    model_config = ConfigDict(
        from_attributes=True,
        populate_by_name=True,
        alias_generator=alias_generators.to_camel,
    )


class ReportUpdate(BaseModel):
    """Partial-update schema for PATCH /api/reports/{id}. Only sent fields are applied."""

    service_type: Optional[str] = None
    notes: Optional[str] = None
    linear_inches_counter: Optional[int] = None
    darkness_level: Optional[float] = None
    signature_image_path: Optional[str] = None


class ReportSendEmailRequest(BaseModel):
    """Body for POST /api/reports/{id}/send-email."""

    extra_email: Optional[str] = None
    # True cuando el usuario pide el envío explícitamente (botón "Enviar"). El
    # disparo automático de la sincronización lo deja en False y el servidor lo
    # omite para reportes de una entrega de póliza (esos van en el correo único).
    manual: bool = False
    # Revoca la liga anterior del PDF y crea una nueva antes de enviar.
    regenerate_link: bool = False

    @field_validator("extra_email")
    @classmethod
    def _check_extra_email(cls, v: Optional[str]) -> Optional[str]:
        return normalize_optional_email(v)
