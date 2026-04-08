"""Add policy_visits table

Revision ID: 005
Revises: 004
Create Date: 2026-03-27
"""

from alembic import op
import sqlalchemy as sa

revision = "005"
down_revision = "004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("""
        CREATE TABLE IF NOT EXISTS policy_visits (
            id VARCHAR PRIMARY KEY,
            policy_id VARCHAR NOT NULL REFERENCES policies(id),
            visit_number INTEGER NOT NULL,
            scheduled_date DATE,
            status VARCHAR NOT NULL DEFAULT 'scheduled',
            started_at TIMESTAMP,
            completed_at TIMESTAMP,
            created_at TIMESTAMP NOT NULL DEFAULT NOW()
        )
    """)


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS policy_visits")
