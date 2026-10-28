"""Ayudas para las pruebas del portal de clientes."""
import uuid

from app.api.routers.portal import _hash_password, _portal_token
from app.models.area import Area
from app.models.plant import Plant
from app.models.portal import PortalUser
from app.models.printer import Printer

PORTAL_PASSWORD = "Portal#2026"


def make_portal_user(db, client_id: str, plant_id: str | None = None,
                     email: str | None = None, active: bool = True,
                     password: str = PORTAL_PASSWORD) -> PortalUser:
    user = PortalUser(
        id=str(uuid.uuid4()), client_id=client_id, plant_id=plant_id,
        email=email or f"{uuid.uuid4().hex[:6]}@cliente.example.com",
        password_hash=_hash_password(password), name="Cliente Portal",
        is_active=active,
    )
    db.add(user)
    db.commit()
    return user


def portal_headers(db, user: PortalUser) -> dict:
    return {"Authorization": f"Bearer {_portal_token(user, db)}"}


def add_plant_b_printer(db, world, serial: str = "SN-B01") -> tuple[Plant, Printer]:
    """Segunda planta del mismo cliente con una impresora."""
    base = world.printers[0]
    plant_b = Plant(id=str(uuid.uuid4()), client_id=world.client_row.id, name="Planta B")
    db.add(plant_b)
    db.flush()
    area_b = Area(id=str(uuid.uuid4()), plant_id=plant_b.id, name="Área B")
    db.add(area_b)
    db.flush()
    printer = Printer(
        id=str(uuid.uuid4()), qr_uuid=str(uuid.uuid4()), serial_number=serial,
        client_id=world.client_row.id, plant_id=plant_b.id, area_id=area_b.id,
        model_id=base.model_id, is_active=True,
    )
    db.add(printer)
    db.commit()
    return plant_b, printer
