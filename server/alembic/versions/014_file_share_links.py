"""file_share_links: ligas públicas con token aleatorio a PDFs de reportes/entregas

Revision ID: 014
Revises: 013
Create Date: 2026-10-22
"""

from alembic import op
import sqlalchemy as sa

revision = "014"
down_revision = "013"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # main.py ejecuta Base.metadata.create_all() al arrancar; si el servidor se
    # levantó con el código nuevo antes de correr Alembic, la tabla ya existe.
    if sa.inspect(op.get_bind()).has_table("file_share_links"):
        return
    op.create_table(
        "file_share_links",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("token", sa.String(), nullable=False),
        sa.Column("target_type", sa.String(), nullable=False),
        sa.Column("target_id", sa.String(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False
        ),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        sa.Column("revoked_at", sa.DateTime(), nullable=True),
        sa.Column("last_access_at", sa.DateTime(), nullable=True),
        sa.Column("access_count", sa.Integer(), nullable=False, server_default="0"),
    )
    op.create_index("ix_file_share_links_token", "file_share_links", ["token"], unique=True)
    op.create_index(
        "ix_file_share_links_target", "file_share_links", ["target_type", "target_id"]
    )


def downgrade() -> None:
    op.drop_index("ix_file_share_links_target", table_name="file_share_links")
    op.drop_index("ix_file_share_links_token", table_name="file_share_links")
    op.drop_table("file_share_links")
