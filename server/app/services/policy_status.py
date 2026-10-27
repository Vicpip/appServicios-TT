"""Estado de una póliza: una sola fuente, calculada por end_date.

La columna ``policy.status`` solo se usa para la baja lógica ("Deleted") y
para lo que descarga la app; el estado visible (Active/Expiring/Expired) sale
siempre de ``end_date``.
"""
from datetime import datetime, timedelta, timezone

from app.models.policy import Policy

DELETED = "Deleted"
EXPIRING_WINDOW = timedelta(days=30)


def now_utc() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def policy_status(end_date: datetime) -> str:
    # Normalize to naive UTC: Pydantic v2 parses ISO strings with 'Z' as
    # timezone-aware datetimes; DB-loaded datetimes are naive. Stripping tzinfo
    # (replace, not astimezone) is safe because we always work in UTC.
    end = end_date.replace(tzinfo=None)
    now = now_utc()
    if end < now:
        return "Expired"
    if end < now + EXPIRING_WINDOW:
        return "Expiring"
    return "Active"


def not_deleted():
    return Policy.status != DELETED


def vigente(now: datetime | None = None):
    """Criterio SQL: póliza no eliminada y con end_date >= ahora (Active + Expiring)."""
    return (Policy.status != DELETED) & (Policy.end_date >= (now or now_utc()))


def status_filter(status: str, now: datetime | None = None):
    """Criterio SQL equivalente a ``policy_status(end_date) == status``."""
    now = now or now_utc()
    if status == "Expired":
        return Policy.end_date < now
    if status == "Expiring":
        return (Policy.end_date >= now) & (Policy.end_date < now + EXPIRING_WINDOW)
    if status == "Active":
        return Policy.end_date >= now + EXPIRING_WINDOW
    return None
