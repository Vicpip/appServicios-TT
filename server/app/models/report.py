from sqlalchemy import DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.database import Base


class Report(Base):
    __tablename__ = "reports"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    code: Mapped[str | None] = mapped_column(String, nullable=True)
    # No FK constraints: the app is offline-first; printer/user may not exist yet
    printer_id: Mapped[str] = mapped_column(String, nullable=False, index=True)
    tech_id: Mapped[str] = mapped_column(String, nullable=False, index=True)
    service_type: Mapped[str] = mapped_column(String, nullable=False)
    status: Mapped[str] = mapped_column(String, nullable=False)
    service_date: Mapped[DateTime] = mapped_column(DateTime, nullable=False)
    linear_inches_counter: Mapped[int] = mapped_column(Integer, nullable=False)
    darkness_level: Mapped[int | None] = mapped_column(Integer, nullable=True)
    label_type_id: Mapped[str | None] = mapped_column(String, nullable=True)
    technical_checkboxes: Mapped[str] = mapped_column(
        Text, nullable=False, default="{}"
    )
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    signature_name: Mapped[str | None] = mapped_column(String, nullable=True)
    signature_role: Mapped[str | None] = mapped_column(String, nullable=True)
    internal_notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    supersedes_report_id: Mapped[str | None] = mapped_column(String, nullable=True)
    photo_paths: Mapped[str] = mapped_column(Text, nullable=False, default="[]")
    photo_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    signature_image_path: Mapped[str | None] = mapped_column(String, nullable=True)
    signature_block_id: Mapped[str | None] = mapped_column(String, nullable=True)
    report_block_status: Mapped[str | None] = mapped_column(String, nullable=True)
    sync_date: Mapped[DateTime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime, server_default=func.now(), nullable=False
    )

    # Relationships use explicit join — no FK enforcement at DB level
    printer: Mapped["Printer"] = relationship(
        "Printer",
        primaryjoin="Report.printer_id == foreign(Printer.id)",
        viewonly=True,
        overlaps="reports",
    )
    technician: Mapped["User"] = relationship(
        "User",
        primaryjoin="Report.tech_id == foreign(User.id)",
        viewonly=True,
        overlaps="reports",
    )
    label_type: Mapped["CatalogLabelType"] = relationship(
        "CatalogLabelType",
        primaryjoin="Report.label_type_id == foreign(CatalogLabelType.id)",
        viewonly=True,
    )
    actions: Mapped[list] = relationship(
        "ReportAction",
        back_populates="report",
        foreign_keys="[ReportAction.report_id]",
    )
    parts: Mapped[list] = relationship(
        "ReportPart",
        back_populates="report",
        foreign_keys="[ReportPart.report_id]",
    )
