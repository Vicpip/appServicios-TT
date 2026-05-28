"""Add portal tables (portal_users, portal_invitations, portal_password_resets)

Revision ID: 007
Revises: 006
Create Date: 2026-05-27
"""

from alembic import op

revision = "007"
down_revision = "006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ------------------------------------------------------------------
    # portal_users — registered client-portal accounts
    # ------------------------------------------------------------------
    op.execute("""
        CREATE TABLE IF NOT EXISTS portal_users (
            id            VARCHAR PRIMARY KEY,
            client_id     VARCHAR NOT NULL REFERENCES clients(id),
            plant_id      VARCHAR REFERENCES plants(id),
            email         VARCHAR UNIQUE NOT NULL,
            password_hash VARCHAR,
            name          VARCHAR NOT NULL,
            is_active     BOOLEAN NOT NULL DEFAULT TRUE,
            created_at    TIMESTAMP NOT NULL DEFAULT now(),
            last_login_at TIMESTAMP
        )
    """)
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_portal_users_client_id ON portal_users (client_id)"
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_portal_users_plant_id ON portal_users (plant_id)"
    )

    # ------------------------------------------------------------------
    # portal_invitations — admin-sent invite tokens
    # ------------------------------------------------------------------
    op.execute("""
        CREATE TABLE IF NOT EXISTS portal_invitations (
            id          VARCHAR PRIMARY KEY,
            client_id   VARCHAR NOT NULL REFERENCES clients(id),
            plant_id    VARCHAR REFERENCES plants(id),
            invited_by  VARCHAR NOT NULL REFERENCES users(id),
            email       VARCHAR NOT NULL,
            token       VARCHAR UNIQUE NOT NULL,
            status      VARCHAR NOT NULL DEFAULT 'pending',
            expires_at  TIMESTAMP NOT NULL,
            created_at  TIMESTAMP NOT NULL DEFAULT now(),
            accepted_at TIMESTAMP
        )
    """)
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_portal_invitations_client_id ON portal_invitations (client_id)"
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_portal_invitations_token ON portal_invitations (token)"
    )

    # ------------------------------------------------------------------
    # portal_password_resets — short-lived reset tokens
    # ------------------------------------------------------------------
    op.execute("""
        CREATE TABLE IF NOT EXISTS portal_password_resets (
            id              VARCHAR PRIMARY KEY,
            portal_user_id  VARCHAR NOT NULL REFERENCES portal_users(id),
            token           VARCHAR UNIQUE NOT NULL,
            used            BOOLEAN NOT NULL DEFAULT FALSE,
            expires_at      TIMESTAMP NOT NULL,
            created_at      TIMESTAMP NOT NULL DEFAULT now()
        )
    """)
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_portal_password_resets_portal_user_id "
        "ON portal_password_resets (portal_user_id)"
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_portal_password_resets_token "
        "ON portal_password_resets (token)"
    )


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS portal_password_resets")
    op.execute("DROP TABLE IF EXISTS portal_invitations")
    op.execute("DROP TABLE IF EXISTS portal_users")
