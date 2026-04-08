"""Add frequency_maintenance column to policies

Revision ID: 004
Revises: 003
Create Date: 2026-03-22
"""

from alembic import op
import sqlalchemy as sa

revision = "004"
down_revision = "003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("""
        ALTER TABLE policies
        ADD COLUMN IF NOT EXISTS frequency_maintenance VARCHAR
    """)


def downgrade() -> None:
    op.execute("""
        ALTER TABLE policies
        DROP COLUMN IF EXISTS frequency_maintenance
    """)
