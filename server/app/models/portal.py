"""SQLAlchemy models for the client portal.

Three new tables:
  - portal_users        : registered portal accounts (one per client contact)
  - portal_invitations  : admin-created invite tokens
  - portal_password_resets : short-lived password-reset tokens
"""

from sqlalchemy import Boolean, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.database import Base


class PortalUser(Base):
    __tablename__ = "portal_users"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    client_id: Mapped[str] = mapped_column(
        String, ForeignKey("clients.id"), nullable=False, index=True
    )
    # NULL → full-client access; set → single-plant access
    plant_id: Mapped[str | None] = mapped_column(
        String, ForeignKey("plants.id"), nullable=True, index=True
    )
    email: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    password_hash: Mapped[str | None] = mapped_column(String, nullable=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime, server_default=func.now(), nullable=False
    )
    last_login_at: Mapped[DateTime | None] = mapped_column(DateTime, nullable=True)

    # Relationships (read-only views into shared tables)
    client: Mapped["Client"] = relationship(  # type: ignore[name-defined]  # noqa: F821
        "Client",
        primaryjoin="PortalUser.client_id == foreign(Client.id)",
        viewonly=True,
    )
    plant: Mapped["Plant | None"] = relationship(  # type: ignore[name-defined]  # noqa: F821
        "Plant",
        primaryjoin="PortalUser.plant_id == foreign(Plant.id)",
        viewonly=True,
    )
    password_resets: Mapped[list] = relationship(
        "PortalPasswordReset", back_populates="portal_user"
    )


class PortalInvitation(Base):
    __tablename__ = "portal_invitations"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    client_id: Mapped[str] = mapped_column(
        String, ForeignKey("clients.id"), nullable=False, index=True
    )
    # NULL → full-client access invitation
    plant_id: Mapped[str | None] = mapped_column(
        String, ForeignKey("plants.id"), nullable=True
    )
    invited_by: Mapped[str] = mapped_column(
        String, ForeignKey("users.id"), nullable=False
    )
    email: Mapped[str] = mapped_column(String, nullable=False)
    token: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    # status: pending | accepted | expired
    status: Mapped[str] = mapped_column(
        String, nullable=False, server_default="pending"
    )
    expires_at: Mapped[DateTime] = mapped_column(DateTime, nullable=False)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime, server_default=func.now(), nullable=False
    )
    accepted_at: Mapped[DateTime | None] = mapped_column(DateTime, nullable=True)

    # Relationships
    client: Mapped["Client"] = relationship(  # type: ignore[name-defined]  # noqa: F821
        "Client",
        primaryjoin="PortalInvitation.client_id == foreign(Client.id)",
        viewonly=True,
    )
    plant: Mapped["Plant | None"] = relationship(  # type: ignore[name-defined]  # noqa: F821
        "Plant",
        primaryjoin="PortalInvitation.plant_id == foreign(Plant.id)",
        viewonly=True,
    )
    inviter: Mapped["User"] = relationship(  # type: ignore[name-defined]  # noqa: F821
        "User",
        primaryjoin="PortalInvitation.invited_by == foreign(User.id)",
        viewonly=True,
    )


class PortalPasswordReset(Base):
    __tablename__ = "portal_password_resets"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    portal_user_id: Mapped[str] = mapped_column(
        String, ForeignKey("portal_users.id"), nullable=False, index=True
    )
    token: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    used: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    expires_at: Mapped[DateTime] = mapped_column(DateTime, nullable=False)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime, server_default=func.now(), nullable=False
    )

    # Relationships
    portal_user: Mapped["PortalUser"] = relationship(
        "PortalUser", back_populates="password_resets"
    )
