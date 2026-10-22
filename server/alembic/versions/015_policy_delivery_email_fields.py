"""policy_deliveries: extra_email y email_sent_at (correo único por entrega)

Revision ID: 015
Revises: 014
Create Date: 2026-10-22
"""

from alembic import op
import sqlalchemy as sa

revision = "015"
down_revision = "014"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("policy_deliveries", sa.Column("extra_email", sa.String(), nullable=True))
    op.add_column("policy_deliveries", sa.Column("email_sent_at", sa.DateTime(), nullable=True))
    # Entregas anteriores a esta versión: se marcan como ya enviadas para que el
    # nuevo disparo automático no reenvíe correos históricos al hacer deploy.
    op.execute(
        "UPDATE policy_deliveries SET email_sent_at = now() WHERE email_sent_at IS NULL"
    )


def downgrade() -> None:
    op.drop_column("policy_deliveries", "email_sent_at")
    op.drop_column("policy_deliveries", "extra_email")
