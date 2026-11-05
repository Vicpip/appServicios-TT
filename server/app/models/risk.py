from sqlalchemy import Boolean, Date, DateTime, Float, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class PrinterRiskSnapshot(Base):
    """Ultimo calculo de riesgo de una pieza (cabezal | rodillo) de una impresora. Una fila por (impresora, pieza).

    Es una cache derivada: se recalcula con el boton de la pantalla admin o con el job diario
    (`python -m app.risk.refresh --all`) y nunca modifica reportes. `vigente`, `stale` y `modelo_desactualizado`
    NO se guardan: se calculan al leer (app/risk/snapshots.py).
    """

    __tablename__ = "printer_risk_snapshots"
    __table_args__ = (UniqueConstraint("printer_id", "piece", name="uq_printer_risk_snapshots_printer_piece"),)

    id: Mapped[str] = mapped_column(String, primary_key=True)
    printer_id: Mapped[str] = mapped_column(String, ForeignKey("printers.id"), nullable=False, index=True)
    piece: Mapped[str] = mapped_column(String(16), nullable=False)          # 'cabezal' | 'rodillo'
    level: Mapped[str] = mapped_column(String(8), nullable=False)           # ALTO | MEDIO | BAJO (crudo)
    risk_index: Mapped[float] = mapped_column(Float, nullable=False)        # percentil 0-100; NO es una probabilidad
    damaged_last_visit: Mapped[bool] = mapped_column(Boolean, nullable=False)
    previous_damages: Mapped[int] = mapped_column(Integer, nullable=False)
    visits_count: Mapped[int] = mapped_column(Integer, nullable=False)      # app + historial anterior a la app
    short_history: Mapped[bool] = mapped_column(Boolean, nullable=False)    # menos de 3 visitas
    last_visit_date: Mapped[Date] = mapped_column(Date, nullable=False)
    valid_until: Mapped[Date] = mapped_column(Date, nullable=False)         # ultima visita + 90 dias
    # Ultimo Report elegible usado (None si todo el historial viene del CSV): detecta snapshots desactualizados.
    last_report_id: Mapped[str | None] = mapped_column(String, nullable=True)
    model_version: Mapped[str] = mapped_column(String(16), nullable=False)
    # Solo variables numericas de la ultima visita + indicador de dano detectado solo en notas. Nunca texto de notas.
    inputs_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    computed_at: Mapped[DateTime] = mapped_column(DateTime, nullable=False)  # UTC naive
    computed_by: Mapped[str | None] = mapped_column(String, nullable=True)  # users.id; None = job
