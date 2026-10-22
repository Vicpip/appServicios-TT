"""reports.darkness_level INTEGER -> DOUBLE PRECISION (decimal darkness, e.g. 18.5)

Revision ID: 012
Revises: 011
Create Date: 2026-10-21
"""

from alembic import op
import sqlalchemy as sa

revision = "012"
down_revision = "011"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column(
        "reports",
        "darkness_level",
        existing_type=sa.Integer(),
        type_=sa.Float(),
        existing_nullable=True,
        postgresql_using="darkness_level::double precision",
    )


def downgrade() -> None:
    op.alter_column(
        "reports",
        "darkness_level",
        existing_type=sa.Float(),
        type_=sa.Integer(),
        existing_nullable=True,
        postgresql_using="round(darkness_level)::integer",
    )
