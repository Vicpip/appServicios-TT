from sqlalchemy import DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.database import Base


class Policy(Base):
    __tablename__ = "policies"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    code: Mapped[str | None] = mapped_column(String, nullable=True)
    client_id: Mapped[str] = mapped_column(
        String, ForeignKey("clients.id"), nullable=False
    )
    folio: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    start_date: Mapped[DateTime] = mapped_column(DateTime, nullable=False)
    end_date: Mapped[DateTime] = mapped_column(DateTime, nullable=False)
    coverage_type: Mapped[str] = mapped_column(String, nullable=False)
    sla_notes: Mapped[str | None] = mapped_column(String, nullable=True)
    status: Mapped[str] = mapped_column(String, nullable=False)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime, server_default=func.now(), nullable=False
    )

    # Relationships
    client: Mapped["Client"] = relationship("Client", back_populates="policies")
    policy_printers: Mapped[list] = relationship(
        "PolicyPrinter", back_populates="policy"
    )
    deliveries: Mapped[list] = relationship("PolicyDelivery", back_populates="policy")


class PolicyPrinter(Base):
    __tablename__ = "policy_printers"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    policy_id: Mapped[str] = mapped_column(
        String, ForeignKey("policies.id"), nullable=False
    )
    printer_id: Mapped[str] = mapped_column(
        String, ForeignKey("printers.id"), nullable=False
    )

    # Relationships
    policy: Mapped["Policy"] = relationship("Policy", back_populates="policy_printers")
    printer: Mapped["Printer"] = relationship(
        "Printer", back_populates="policy_printers"
    )


class PolicyDelivery(Base):
    __tablename__ = "policy_deliveries"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    policy_id: Mapped[str] = mapped_column(
        String, ForeignKey("policies.id"), nullable=False
    )
    delivery_date: Mapped[DateTime] = mapped_column(DateTime, nullable=False)
    signature_name: Mapped[str] = mapped_column(String, nullable=False)
    signature_role: Mapped[str] = mapped_column(String, nullable=False)
    tech_id: Mapped[str] = mapped_column(
        String, ForeignKey("users.id"), nullable=False
    )

    # Relationships
    policy: Mapped["Policy"] = relationship("Policy", back_populates="deliveries")
    technician: Mapped["User"] = relationship(
        "User", back_populates="policy_deliveries"
    )
    delivery_reports: Mapped[list] = relationship(
        "PolicyDeliveryReport", back_populates="delivery"
    )


class PolicyDeliveryReport(Base):
    __tablename__ = "policy_delivery_reports"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    delivery_id: Mapped[str] = mapped_column(
        String, ForeignKey("policy_deliveries.id"), nullable=False
    )
    report_id: Mapped[str] = mapped_column(
        String, ForeignKey("reports.id"), nullable=False
    )

    # Relationships
    delivery: Mapped["PolicyDelivery"] = relationship(
        "PolicyDelivery", back_populates="delivery_reports"
    )
    report: Mapped["Report"] = relationship("Report")
