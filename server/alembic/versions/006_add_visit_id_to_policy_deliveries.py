"""Add visit_id to policy_deliveries

Revision ID: 006
Revises: 005
Create Date: 2026-04-29
"""

from alembic import op

revision = "006"
down_revision = "005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "ALTER TABLE policy_deliveries ADD COLUMN IF NOT EXISTS "
        "visit_id VARCHAR REFERENCES policy_visits(id) ON DELETE SET NULL"
    )


def downgrade() -> None:
    op.execute(
        "ALTER TABLE policy_deliveries DROP COLUMN IF EXISTS visit_id"
    )
