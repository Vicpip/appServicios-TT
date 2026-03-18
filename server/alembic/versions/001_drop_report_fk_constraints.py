"""Drop FK constraints from reports table (offline-first sync)

Reports from the mobile app arrive before the referenced printer/user
rows exist in PostgreSQL, so FK constraints block the sync.
Data integrity is maintained by the app; the server stores what it receives.

Revision ID: 001
Revises: (initial schema)
Create Date: 2026-03-16
"""

from alembic import op

revision = "001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Drop FK constraints added by the initial create_all()
    # PostgreSQL names them {table}_{column}_fkey by convention
    op.execute(
        "ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_printer_id_fkey"
    )
    op.execute(
        "ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_tech_id_fkey"
    )
    op.execute(
        "ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_label_type_id_fkey"
    )
    op.execute(
        "ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_supersedes_report_id_fkey"
    )
    # Add indexes for the columns we'll query frequently
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_reports_printer_id ON reports (printer_id)"
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_reports_tech_id ON reports (tech_id)"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_reports_printer_id")
    op.execute("DROP INDEX IF EXISTS ix_reports_tech_id")
    # Note: restoring FK constraints would require all referenced rows to exist.
    # Downgrade is intentionally left without constraint restoration.
