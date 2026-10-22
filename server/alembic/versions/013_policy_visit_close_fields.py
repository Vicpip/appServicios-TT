"""policy_visits: closed_at / closed_by / closed_reason (cierre manual de visita)

Revision ID: 013
Revises: 012
Create Date: 2026-10-22
"""

from alembic import op
import sqlalchemy as sa

revision = "013"
down_revision = "012"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("policy_visits", sa.Column("closed_at", sa.DateTime(), nullable=True))
    op.add_column(
        "policy_visits",
        sa.Column(
            "closed_by",
            sa.String(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )
    op.add_column("policy_visits", sa.Column("closed_reason", sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column("policy_visits", "closed_reason")
    op.drop_constraint("policy_visits_closed_by_fkey", "policy_visits", type_="foreignkey")
    op.drop_column("policy_visits", "closed_by")
    op.drop_column("policy_visits", "closed_at")
