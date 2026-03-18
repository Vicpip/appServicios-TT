from sqlalchemy import Boolean, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class ReportAction(Base):
    __tablename__ = "report_actions"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    report_id: Mapped[str] = mapped_column(
        String, ForeignKey("reports.id"), nullable=False
    )
    action_id: Mapped[str] = mapped_column(
        String, ForeignKey("catalog_actions.id"), nullable=False
    )

    # Relationships
    report: Mapped["Report"] = relationship("Report", back_populates="actions")
    action: Mapped["CatalogAction"] = relationship("CatalogAction")


class ReportPart(Base):
    __tablename__ = "report_parts"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    report_id: Mapped[str] = mapped_column(
        String, ForeignKey("reports.id"), nullable=False
    )
    part_id: Mapped[str] = mapped_column(
        String, ForeignKey("catalog_parts.id"), nullable=False
    )
    was_damaged: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    wear_level: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    # Relationships
    report: Mapped["Report"] = relationship("Report", back_populates="parts")
    part: Mapped["CatalogPart"] = relationship("CatalogPart")
