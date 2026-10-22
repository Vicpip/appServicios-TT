"""Fixtures de pruebas del backend (TestClient + SQLite en memoria).

Las pruebas NO envían correos reales: ``email_service._smtp_deliver`` se
reemplaza por un buzón falso (``outbox``). Los archivos subidos van a una
carpeta temporal.

Correr:  cd server && venv313\\Scripts\\python -m pytest tests -v
"""
import hashlib
import os
import tempfile
import uuid
from datetime import datetime, timedelta, timezone
from email import message_from_string
from pathlib import Path

_UPLOADS = tempfile.mkdtemp(prefix="smp_test_uploads_")
os.environ["DATABASE_URL"] = "sqlite://"
os.environ["SECRET_KEY"] = "test-secret-key"
os.environ["UPLOAD_DIR"] = _UPLOADS
os.environ["API_BASE_URL"] = "https://api.test.local"
os.environ["PUBLIC_LINK_RATE_LIMIT"] = "1000"  # las pruebas de límite lo bajan

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy import create_engine  # noqa: E402
from sqlalchemy.orm import sessionmaker  # noqa: E402
from sqlalchemy.pool import StaticPool  # noqa: E402

import app.models  # noqa: E402,F401
from app.config import get_settings  # noqa: E402
from app.database import Base, get_db  # noqa: E402
from app.main import app as fastapi_app  # noqa: E402
from app.models.area import Area  # noqa: E402
from app.models.catalog import CatalogModel  # noqa: E402
from app.models.client import Client  # noqa: E402
from app.models.client_contact_email import ClientContactEmail  # noqa: E402
from app.models.file import EntityFile, File  # noqa: E402
from app.models.plant import Plant  # noqa: E402
from app.models.policy import Policy, PolicyPrinter, PolicyVisit  # noqa: E402
from app.models.printer import Printer  # noqa: E402
from app.models.report import Report  # noqa: E402
from app.models.user import User  # noqa: E402
from app.services import email_service  # noqa: E402
from app.services.rate_limit import public_link_limiter  # noqa: E402

PDF_BYTES = b"%PDF-1.4\n% prueba\n%%EOF\n"
PASSWORD = "Secreta#2026"


def _hash_password(password: str) -> str:
    salt = "0123456789abcdef"
    dk = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 260_000)
    return f"{salt}${dk.hex()}"


_PASSWORD_HASH = _hash_password(PASSWORD)  # PBKDF2 260k: se calcula una sola vez


@pytest.fixture()
def db_engine():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    yield engine
    engine.dispose()


@pytest.fixture()
def db(db_engine):
    Session = sessionmaker(bind=db_engine, autocommit=False, autoflush=False)
    session = Session()
    yield session
    session.close()


@pytest.fixture()
def client(db_engine):
    Session = sessionmaker(bind=db_engine, autocommit=False, autoflush=False)

    def _get_db():
        s = Session()
        try:
            yield s
        finally:
            s.close()

    fastapi_app.dependency_overrides[get_db] = _get_db
    public_link_limiter.reset()
    with TestClient(fastapi_app) as c:  # arranca el lifespan (carpetas de uploads)
        yield c
    fastapi_app.dependency_overrides.clear()


class Outbox:
    """Buzón falso: guarda cada mensaje que habría salido por SMTP."""

    def __init__(self) -> None:
        self.sent: list[dict] = []
        self.fail = False

    def deliver(self, recipients: list[str], message: str) -> None:
        if self.fail:
            raise OSError("SMTP caído (simulado)")
        self.sent.append(
            {"recipients": list(recipients), "message": message_from_string(message)}
        )

    @staticmethod
    def html(item: dict) -> str:
        msg = item["message"]
        part = next(p for p in msg.walk() if p.get_content_type() == "text/html")
        return part.get_payload(decode=True).decode("utf-8")

    @staticmethod
    def has_attachment(item: dict) -> bool:
        return any(
            p.get_content_type() == "application/pdf" or p.get_filename()
            for p in item["message"].walk()
        )


@pytest.fixture()
def outbox(monkeypatch):
    box = Outbox()
    monkeypatch.setattr(email_service, "_smtp_deliver", box.deliver)
    return box


# ---------------------------------------------------------------------------
# Fábricas de datos
# ---------------------------------------------------------------------------


def now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class World:
    """Cliente con 3 equipos en una póliza con 2 visitas, un admin y un técnico."""

    def __init__(self, db) -> None:
        self.db = db
        self.admin = User(
            id=str(uuid.uuid4()), code="A-001", name="Admin Uno",
            email="admin@smp.test", password_hash=_PASSWORD_HASH, role="admin",
            is_active=True, token_version=0,
        )
        self.tech = User(
            id=str(uuid.uuid4()), code="T-001", name="Técnico Uno",
            email="tech@smp.test", password_hash=_PASSWORD_HASH, role="technician",
            is_active=True, token_version=0,
        )
        self.client_row = Client(id=str(uuid.uuid4()), name="Vibracoustic & Co", is_active=True)
        plant = Plant(id=str(uuid.uuid4()), client_id=self.client_row.id, name="Planta 1")
        area = Area(id=str(uuid.uuid4()), plant_id=plant.id, name="Área 1")
        model = CatalogModel(
            id=str(uuid.uuid4()), brand="Zebra", model_name="ZT411", dpi=300, is_active=True
        )
        db.add_all([self.admin, self.tech, self.client_row, plant, area, model])
        db.flush()

        self.printers: list[Printer] = []
        for i in range(3):
            p = Printer(
                id=str(uuid.uuid4()), qr_uuid=str(uuid.uuid4()),
                serial_number=f"SN-{i + 1:03d}", client_id=self.client_row.id,
                plant_id=plant.id, area_id=area.id, model_id=model.id, is_active=True,
            )
            self.printers.append(p)
        db.add_all(self.printers)
        db.flush()

        self.policy = Policy(
            id=str(uuid.uuid4()), code="P-001", client_id=self.client_row.id,
            folio="POL-2026-001", start_date=now() - timedelta(days=30),
            end_date=now() + timedelta(days=300), coverage_type="Integral",
            status="Active", frequency_maintenance="Semestral",
        )
        db.add(self.policy)
        db.flush()
        for p in self.printers:
            db.add(PolicyPrinter(id=str(uuid.uuid4()), policy_id=self.policy.id, printer_id=p.id))
        self.visit1 = PolicyVisit(
            id=str(uuid.uuid4()), policy_id=self.policy.id, visit_number=1,
            status="in_progress", started_at=now() - timedelta(hours=5),
        )
        self.visit2 = PolicyVisit(
            id=str(uuid.uuid4()), policy_id=self.policy.id, visit_number=2,
            status="scheduled",
        )
        db.add_all([self.visit1, self.visit2])
        db.commit()

    # -- datos auxiliares ---------------------------------------------------
    def add_contact(self, email: str, active: bool = True) -> None:
        self.db.add(ClientContactEmail(
            id=str(uuid.uuid4()), client_id=self.client_row.id, email=email, is_active=active
        ))
        self.db.commit()

    def add_report(self, printer: Printer, status: str = "pending_delivery",
                   code: str | None = None) -> Report:
        r = Report(
            id=str(uuid.uuid4()), code=code or f"R-{uuid.uuid4().hex[:4]}",
            printer_id=printer.id, tech_id=self.tech.id, service_type="Preventivo",
            status=status, service_date=now() - timedelta(hours=1),
            linear_inches_counter=100, technical_checkboxes="{}",
        )
        self.db.add(r)
        self.db.commit()
        return r


@pytest.fixture()
def world(db) -> World:
    return World(db)


def _login(client: TestClient, email: str) -> dict:
    res = client.post("/api/auth/login", json={"email": email, "password": PASSWORD})
    assert res.status_code == 200, res.text
    return res.json()


@pytest.fixture()
def admin_headers(client, world):
    return {"Authorization": f"Bearer {_login(client, world.admin.email)['access_token']}"}


@pytest.fixture()
def tech_headers(client, world):
    return {"Authorization": f"Bearer {_login(client, world.tech.email)['access_token']}"}


def store_pdf(db, entity_type: str, entity_id: str, category: str = "pdf",
              content: bytes = PDF_BYTES) -> Path:
    """Guarda un archivo en uploads y lo registra como la sincronización real."""
    upload = Path(get_settings().upload_dir)
    path = upload / entity_type / entity_id / f"{uuid.uuid4().hex}.pdf"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content + uuid.uuid4().bytes)
    f = File(
        id=str(uuid.uuid4()), file_hash=uuid.uuid4().hex, file_type="application/pdf",
        storage_path=str(path), origin="mobile_sync",
    )
    db.add(f)
    db.flush()
    db.add(EntityFile(
        id=str(uuid.uuid4()), file_id=f.id, entity_id=entity_id,
        entity_type=entity_type, file_category=category,
    ))
    db.commit()
    return path
