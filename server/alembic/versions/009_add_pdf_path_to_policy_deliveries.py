"""Add pdf_path column to policy_deliveries table

Revision ID: 009
Revises: 008
Create Date: 2026-06-02
"""

from alembic import op
import sqlalchemy as sa

revision = "009"
down_revision = "008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("policy_deliveries", sa.Column("pdf_path", sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column("policy_deliveries", "pdf_path")
