from sqlalchemy import Boolean, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.database import Base


class Printer(Base):
    __tablename__ = "printers"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    code: Mapped[str | None] = mapped_column(String, nullable=True)
    qr_uuid: Mapped[str] = mapped_column(String, nullable=False)
    serial_number: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    client_id: Mapped[str] = mapped_column(
        String, ForeignKey("clients.id"), nullable=False
    )
    plant_id: Mapped[str] = mapped_column(
        String, ForeignKey("plants.id"), nullable=False
    )
    area_id: Mapped[str] = mapped_column(
        String, ForeignKey("areas.id"), nullable=False
    )
    model_id: Mapped[str] = mapped_column(
        String, ForeignKey("catalog_models.id"), nullable=False
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime, server_default=func.now(), nullable=False
    )

    # Relationships
    client: Mapped["Client"] = relationship("Client", back_populates="printers")
    plant: Mapped["Plant"] = relationship("Plant", back_populates="printers")
    area: Mapped["Area"] = relationship("Area", back_populates="printers")
    model: Mapped["CatalogModel"] = relationship("CatalogModel")
    reports: Mapped[list] = relationship(
        "Report",
        primaryjoin="Printer.id == foreign(Report.printer_id)",
        viewonly=True,
        overlaps="printer",
    )
    policy_printers: Mapped[list] = relationship(
        "PolicyPrinter", back_populates="printer"
    )
    policy_assignments: Mapped[list] = relationship(
        "PolicyPrinterAssignment", back_populates="printer"
    )
