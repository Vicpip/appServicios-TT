"""Initial schema — create all tables

Creates every table from scratch using CREATE TABLE IF NOT EXISTS so it is
safe to run against a database that was already bootstrapped with create_all().

Revision ID: 000
Revises: —
Create Date: 2026-03-18
"""

from alembic import op

revision = "000"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # --- Leaf tables (no foreign-key dependencies) ---
    op.execute("""
        CREATE TABLE IF NOT EXISTS clients (
            id VARCHAR PRIMARY KEY,
            name VARCHAR NOT NULL,
            rfc VARCHAR,
            address VARCHAR,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP DEFAULT now() NOT NULL
        )
    """)

    op.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id VARCHAR PRIMARY KEY,
            code VARCHAR,
            name VARCHAR NOT NULL,
            email VARCHAR UNIQUE NOT NULL,
            password_hash VARCHAR,
            role VARCHAR NOT NULL,
            is_active BOOLEAN DEFAULT TRUE,
            signature_path VARCHAR,
            last_sync_at TIMESTAMP,
            created_at TIMESTAMP DEFAULT now() NOT NULL
        )
    """)

    op.execute("""
        CREATE TABLE IF NOT EXISTS catalog_models (
            id VARCHAR PRIMARY KEY,
            brand VARCHAR NOT NULL,
            model_name VARCHAR NOT NULL,
            dpi INTEGER NOT NULL,
            is_active BOOLEAN DEFAULT TRUE
        )
    """)

    op.execute("""
        CREATE TABLE IF NOT EXISTS catalog_label_types (
            id VARCHAR PRIMARY KEY,
            name VARCHAR NOT NULL,
            is_active BOOLEAN DEFAULT TRUE
        )
    """)

    op.execute("""
        CREATE TABLE IF NOT EXISTS catalog_actions (
            id VARCHAR PRIMARY KEY,
            name VARCHAR NOT NULL,
            is_active BOOLEAN DEFAULT TRUE
        )
    """)

    op.execute("""
        CREATE TABLE IF NOT EXISTS catalog_parts (
            id VARCHAR PRIMARY KEY,
            name VARCHAR NOT NULL,
            is_active BOOLEAN DEFAULT TRUE
        )
    """)

    op.execute("""
        CREATE TABLE IF NOT EXISTS catalog_failures (
            id VARCHAR PRIMARY KEY,
            name VARCHAR NOT NULL,
            is_active BOOLEAN DEFAULT TRUE
        )
    """)

    op.execute("""
        CREATE TABLE IF NOT EXISTS files (
            id VARCHAR PRIMARY KEY,
            file_hash VARCHAR NOT NULL,
            file_type VARCHAR NOT NULL,
            storage_path VARCHAR NOT NULL,
            origin VARCHAR NOT NULL,
            created_at TIMESTAMP DEFAULT now() NOT NULL
        )
    """)

    op.execute("""
        CREATE TABLE IF NOT EXISTS sync_queue (
            id VARCHAR PRIMARY KEY,
            method_http VARCHAR NOT NULL,
            endpoint_destino VARCHAR NOT NULL,
            payload_json TEXT NOT NULL,
            entity_type VARCHAR NOT NULL,
            entity_id VARCHAR NOT NULL,
            fecha_creacion TIMESTAMP DEFAULT now() NOT NULL,
            estado_peticion VARCHAR NOT NULL DEFAULT 'pending',
            intentos_fallidos INTEGER NOT NULL DEFAULT 0,
            updated_at TIMESTAMP
        )
    """)

    # --- Tables that depend on clients ---
    op.execute("""
        CREATE TABLE IF NOT EXISTS plants (
            id VARCHAR PRIMARY KEY,
            client_id VARCHAR NOT NULL REFERENCES clients(id),
            name VARCHAR NOT NULL,
            contact_name VARCHAR,
            phone VARCHAR,
            created_at TIMESTAMP DEFAULT now() NOT NULL
        )
    """)

    op.execute("""
        CREATE TABLE IF NOT EXISTS policies (
            id VARCHAR PRIMARY KEY,
            code VARCHAR,
            client_id VARCHAR NOT NULL REFERENCES clients(id),
            folio VARCHAR UNIQUE NOT NULL,
            start_date TIMESTAMP NOT NULL,
            end_date TIMESTAMP NOT NULL,
            coverage_type VARCHAR NOT NULL,
            sla_notes VARCHAR,
            status VARCHAR NOT NULL,
            created_at TIMESTAMP DEFAULT now() NOT NULL
        )
    """)

    # --- Tables that depend on plants ---
    op.execute("""
        CREATE TABLE IF NOT EXISTS areas (
            id VARCHAR PRIMARY KEY,
            plant_id VARCHAR NOT NULL REFERENCES plants(id),
            name VARCHAR NOT NULL,
            created_at TIMESTAMP DEFAULT now() NOT NULL
        )
    """)

    # --- Tables that depend on clients / plants / areas / catalog_models ---
    op.execute("""
        CREATE TABLE IF NOT EXISTS printers (
            id VARCHAR PRIMARY KEY,
            code VARCHAR,
            qr_uuid VARCHAR NOT NULL,
            serial_number VARCHAR UNIQUE NOT NULL,
            client_id VARCHAR NOT NULL REFERENCES clients(id),
            plant_id VARCHAR NOT NULL REFERENCES plants(id),
            area_id VARCHAR NOT NULL REFERENCES areas(id),
            model_id VARCHAR NOT NULL REFERENCES catalog_models(id),
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP DEFAULT now() NOT NULL
        )
    """)

    # --- reports: NO FK constraints (offline-first sync) ---
    op.execute("""
        CREATE TABLE IF NOT EXISTS reports (
            id VARCHAR PRIMARY KEY,
            code VARCHAR,
            printer_id VARCHAR NOT NULL,
            tech_id VARCHAR NOT NULL,
            service_type VARCHAR NOT NULL,
            status VARCHAR NOT NULL,
            service_date TIMESTAMP NOT NULL,
            linear_inches_counter INTEGER NOT NULL,
            darkness_level INTEGER,
            label_type_id VARCHAR,
            technical_checkboxes TEXT NOT NULL DEFAULT '{}',
            notes TEXT,
            signature_name VARCHAR,
            signature_role VARCHAR,
            internal_notes TEXT,
            supersedes_report_id VARCHAR,
            photo_paths TEXT NOT NULL DEFAULT '[]',
            photo_count INTEGER NOT NULL DEFAULT 0,
            signature_image_path VARCHAR,
            signature_block_id VARCHAR,
            report_block_status VARCHAR,
            sync_date TIMESTAMP,
            created_at TIMESTAMP DEFAULT now() NOT NULL
        )
    """)
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_reports_printer_id ON reports (printer_id)"
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_reports_tech_id ON reports (tech_id)"
    )

    # --- Tables that depend on reports ---
    op.execute("""
        CREATE TABLE IF NOT EXISTS report_actions (
            id VARCHAR PRIMARY KEY,
            report_id VARCHAR NOT NULL REFERENCES reports(id),
            action_id VARCHAR NOT NULL REFERENCES catalog_actions(id)
        )
    """)

    op.execute("""
        CREATE TABLE IF NOT EXISTS report_parts (
            id VARCHAR PRIMARY KEY,
            report_id VARCHAR NOT NULL REFERENCES reports(id),
            part_id VARCHAR NOT NULL REFERENCES catalog_parts(id),
            was_damaged BOOLEAN NOT NULL DEFAULT FALSE,
            wear_level INTEGER NOT NULL DEFAULT 0
        )
    """)

    # --- Tables that depend on sync_queue ---
    op.execute("""
        CREATE TABLE IF NOT EXISTS sync_log (
            id VARCHAR PRIMARY KEY,
            sync_queue_id VARCHAR REFERENCES sync_queue(id),
            entity_type VARCHAR NOT NULL,
            entity_id VARCHAR NOT NULL,
            action VARCHAR NOT NULL,
            status VARCHAR NOT NULL,
            error_message TEXT,
            synced_at TIMESTAMP DEFAULT now() NOT NULL,
            server_response TEXT
        )
    """)

    # --- Tables that depend on files ---
    op.execute("""
        CREATE TABLE IF NOT EXISTS entity_files (
            id VARCHAR PRIMARY KEY,
            file_id VARCHAR NOT NULL REFERENCES files(id),
            entity_id VARCHAR NOT NULL,
            entity_type VARCHAR NOT NULL,
            file_category VARCHAR NOT NULL
        )
    """)

    # --- Tables that depend on policies / printers / users ---
    op.execute("""
        CREATE TABLE IF NOT EXISTS policy_printers (
            id VARCHAR PRIMARY KEY,
            policy_id VARCHAR NOT NULL REFERENCES policies(id),
            printer_id VARCHAR NOT NULL REFERENCES printers(id)
        )
    """)

    op.execute("""
        CREATE TABLE IF NOT EXISTS policy_deliveries (
            id VARCHAR PRIMARY KEY,
            policy_id VARCHAR NOT NULL REFERENCES policies(id),
            delivery_date TIMESTAMP NOT NULL,
            signature_name VARCHAR NOT NULL,
            signature_role VARCHAR NOT NULL,
            tech_id VARCHAR NOT NULL REFERENCES users(id)
        )
    """)

    op.execute("""
        CREATE TABLE IF NOT EXISTS policy_delivery_reports (
            id VARCHAR PRIMARY KEY,
            delivery_id VARCHAR NOT NULL REFERENCES policy_deliveries(id),
            report_id VARCHAR NOT NULL REFERENCES reports(id)
        )
    """)


def downgrade() -> None:
    # Drop in reverse dependency order
    op.execute("DROP TABLE IF EXISTS policy_delivery_reports")
    op.execute("DROP TABLE IF EXISTS policy_deliveries")
    op.execute("DROP TABLE IF EXISTS policy_printers")
    op.execute("DROP TABLE IF EXISTS entity_files")
    op.execute("DROP TABLE IF EXISTS sync_log")
    op.execute("DROP TABLE IF EXISTS report_parts")
    op.execute("DROP TABLE IF EXISTS report_actions")
    op.execute("DROP TABLE IF EXISTS reports")
    op.execute("DROP TABLE IF EXISTS printers")
    op.execute("DROP TABLE IF EXISTS areas")
    op.execute("DROP TABLE IF EXISTS policies")
    op.execute("DROP TABLE IF EXISTS plants")
    op.execute("DROP TABLE IF EXISTS sync_queue")
    op.execute("DROP TABLE IF EXISTS files")
    op.execute("DROP TABLE IF EXISTS catalog_failures")
    op.execute("DROP TABLE IF EXISTS catalog_parts")
    op.execute("DROP TABLE IF EXISTS catalog_actions")
    op.execute("DROP TABLE IF EXISTS catalog_label_types")
    op.execute("DROP TABLE IF EXISTS catalog_models")
    op.execute("DROP TABLE IF EXISTS users")
    op.execute("DROP TABLE IF EXISTS clients")
