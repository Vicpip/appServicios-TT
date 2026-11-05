"""printer_risk_snapshots: ultimo calculo de riesgo (cabezal/rodillo) por impresora

Revision ID: 016
Revises: 015
Create Date: 2026-11-04
"""

from alembic import op
import sqlalchemy as sa

revision = "016"
down_revision = "015"
branch_labels = None
depends_on = None

TABLA = "printer_risk_snapshots"
INDICE = "ix_printer_risk_snapshots_printer_id"


def upgrade() -> None:
    # Idempotente: main.py ejecuta Base.metadata.create_all() al arrancar, así que si el servidor se levantó con el
    # código nuevo antes de correr Alembic, la tabla (y su índice) ya existen y no hay nada que hacer.
    insp = sa.inspect(op.get_bind())
    if not insp.has_table(TABLA):
        op.create_table(
            TABLA,
            sa.Column("id", sa.String(), primary_key=True),
            sa.Column("printer_id", sa.String(), sa.ForeignKey("printers.id"), nullable=False),
            sa.Column("piece", sa.String(16), nullable=False),
            sa.Column("level", sa.String(8), nullable=False),
            sa.Column("risk_index", sa.Float(), nullable=False),
            sa.Column("damaged_last_visit", sa.Boolean(), nullable=False),
            sa.Column("previous_damages", sa.Integer(), nullable=False),
            sa.Column("visits_count", sa.Integer(), nullable=False),
            sa.Column("short_history", sa.Boolean(), nullable=False),
            sa.Column("last_visit_date", sa.Date(), nullable=False),
            sa.Column("valid_until", sa.Date(), nullable=False),
            sa.Column("last_report_id", sa.String(), nullable=True),
            sa.Column("model_version", sa.String(16), nullable=False),
            sa.Column("inputs_json", sa.Text(), nullable=True),
            sa.Column("computed_at", sa.DateTime(), nullable=False),
            sa.Column("computed_by", sa.String(), nullable=True),
            sa.UniqueConstraint("printer_id", "piece", name="uq_printer_risk_snapshots_printer_piece"),
        )
        insp = sa.inspect(op.get_bind())
    if INDICE not in {i["name"] for i in insp.get_indexes(TABLA)}:
        op.create_index(INDICE, TABLA, ["printer_id"])


def downgrade() -> None:
    if sa.inspect(op.get_bind()).has_table(TABLA):
        op.drop_table(TABLA)    # arrastra sus índices; solo se elimina esta tabla
