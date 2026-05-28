"""Add logo_path column to clients table

Revision ID: 008
Revises: 007
Create Date: 2026-05-28
"""

from alembic import op
import sqlalchemy as sa

revision = "008"
down_revision = "007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("clients", sa.Column("logo_path", sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column("clients", "logo_path")
