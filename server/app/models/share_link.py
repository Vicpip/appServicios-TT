from sqlalchemy import DateTime, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base

# Tipos de destino de una liga pública.
TARGET_REPORT_PDF = "report_pdf"      # target_id = reports.id
TARGET_DELIVERY_PDF = "delivery_pdf"  # target_id = policy_deliveries.id


class FileShareLink(Base):
    """Liga pública (token aleatorio) a un PDF de reporte o de entrega.

    El token NO es el ID del archivo. La liga apunta a la entidad y se resuelve
    al PDF vigente en cada acceso, así que sigue funcionando si el PDF se
    regenera.
    """

    __tablename__ = "file_share_links"
    __table_args__ = (Index("ix_file_share_links_target", "target_type", "target_id"),)

    id: Mapped[str] = mapped_column(String, primary_key=True)
    token: Mapped[str] = mapped_column(String, unique=True, index=True, nullable=False)
    target_type: Mapped[str] = mapped_column(String, nullable=False)
    target_id: Mapped[str] = mapped_column(String, nullable=False)
    created_at: Mapped[DateTime] = mapped_column(
        DateTime, server_default=func.now(), nullable=False
    )
    expires_at: Mapped[DateTime] = mapped_column(DateTime, nullable=False)
    revoked_at: Mapped[DateTime | None] = mapped_column(DateTime, nullable=True)
    last_access_at: Mapped[DateTime | None] = mapped_column(DateTime, nullable=True)
    access_count: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
