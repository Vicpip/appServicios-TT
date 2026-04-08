from sqlalchemy import Boolean, DateTime, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.database import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    code: Mapped[str | None] = mapped_column(String, nullable=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    email: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    password_hash: Mapped[str | None] = mapped_column(String, nullable=True)
    role: Mapped[str] = mapped_column(String, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    signature_path: Mapped[str | None] = mapped_column(String, nullable=True)
    last_sync_at: Mapped[DateTime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime, server_default=func.now(), nullable=False
    )

    # Relationships
    reports: Mapped[list] = relationship(
        "Report",
        primaryjoin="User.id == foreign(Report.tech_id)",
        viewonly=True,
        overlaps="technician",
    )
    policy_deliveries: Mapped[list] = relationship(
        "PolicyDelivery", back_populates="technician"
    )
    policy_assignments: Mapped[list] = relationship(
        "PolicyPrinterAssignment", back_populates="technician"
    )
