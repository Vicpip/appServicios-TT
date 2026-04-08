"""Add policy_printer_assignments table and signature_image_path to policy_deliveries

Revision ID: 003
Revises: 002
Create Date: 2026-03-20
"""

from alembic import op
import sqlalchemy as sa

revision = "003"
down_revision = "002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("""
        CREATE TABLE IF NOT EXISTS policy_printer_assignments (
            id VARCHAR PRIMARY KEY,
            policy_id VARCHAR NOT NULL REFERENCES policies(id) ON DELETE CASCADE,
            printer_id VARCHAR NOT NULL REFERENCES printers(id) ON DELETE CASCADE,
            technician_id VARCHAR NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            assigned_at TIMESTAMP NOT NULL DEFAULT NOW(),
            CONSTRAINT uq_policy_printer UNIQUE (policy_id, printer_id)
        )
    """)
    op.execute(
        "ALTER TABLE policy_deliveries ADD COLUMN IF NOT EXISTS signature_image_path VARCHAR"
    )


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS policy_printer_assignments")
    op.execute(
        "ALTER TABLE policy_deliveries DROP COLUMN IF EXISTS signature_image_path"
    )
