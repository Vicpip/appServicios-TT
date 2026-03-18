# Import all models so Alembic can detect them for autogenerate migrations.
# The order of imports matters to respect foreign key dependencies.

from app.models.user import User  # noqa: F401
from app.models.client import Client  # noqa: F401
from app.models.plant import Plant  # noqa: F401
from app.models.area import Area  # noqa: F401
from app.models.catalog import (  # noqa: F401
    CatalogModel,
    CatalogLabelType,
    CatalogAction,
    CatalogPart,
    CatalogFailure,
)
from app.models.printer import Printer  # noqa: F401
from app.models.report import Report  # noqa: F401
from app.models.report_detail import ReportAction, ReportPart  # noqa: F401
from app.models.policy import (  # noqa: F401
    Policy,
    PolicyPrinter,
    PolicyDelivery,
    PolicyDeliveryReport,
)
from app.models.file import File, EntityFile  # noqa: F401
from app.models.sync import SyncQueue, SyncLog  # noqa: F401

__all__ = [
    "User",
    "Client",
    "Plant",
    "Area",
    "CatalogModel",
    "CatalogLabelType",
    "CatalogAction",
    "CatalogPart",
    "CatalogFailure",
    "Printer",
    "Report",
    "ReportAction",
    "ReportPart",
    "Policy",
    "PolicyPrinter",
    "PolicyDelivery",
    "PolicyDeliveryReport",
    "File",
    "EntityFile",
    "SyncQueue",
    "SyncLog",
]
