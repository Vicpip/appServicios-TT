from datetime import datetime

from pydantic import BaseModel, ConfigDict, alias_generators


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
    darkness_level: int | None = None
    label_type_id: str | None = None
    technical_checkboxes: dict[str, bool]  # raw dict for flexibility
    notes: str | None = None
    signature_name: str | None = None
    signature_role: str | None = None
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
