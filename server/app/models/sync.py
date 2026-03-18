from sqlalchemy import DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.database import Base


class SyncQueue(Base):
    __tablename__ = "sync_queue"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    method_http: Mapped[str] = mapped_column(String, nullable=False)
    endpoint_destino: Mapped[str] = mapped_column(String, nullable=False)
    payload_json: Mapped[str] = mapped_column(Text, nullable=False)
    entity_type: Mapped[str] = mapped_column(String, nullable=False)
    entity_id: Mapped[str] = mapped_column(String, nullable=False)
    fecha_creacion: Mapped[DateTime] = mapped_column(
        DateTime, server_default=func.now(), nullable=False
    )
    estado_peticion: Mapped[str] = mapped_column(
        String, nullable=False, default="pending"
    )
    intentos_fallidos: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    updated_at: Mapped[DateTime | None] = mapped_column(DateTime, nullable=True)

    # Relationships
    sync_logs: Mapped[list] = relationship("SyncLog", back_populates="sync_queue_entry")


class SyncLog(Base):
    __tablename__ = "sync_log"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    sync_queue_id: Mapped[str | None] = mapped_column(
        String, ForeignKey("sync_queue.id"), nullable=True
    )
    entity_type: Mapped[str] = mapped_column(String, nullable=False)
    entity_id: Mapped[str] = mapped_column(String, nullable=False)
    action: Mapped[str] = mapped_column(String, nullable=False)
    status: Mapped[str] = mapped_column(String, nullable=False)
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)
    synced_at: Mapped[DateTime] = mapped_column(
        DateTime, server_default=func.now(), nullable=False
    )
    server_response: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Relationships
    sync_queue_entry: Mapped["SyncQueue | None"] = relationship(
        "SyncQueue", back_populates="sync_logs"
    )
