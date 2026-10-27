"""Fechas de las visitas de una póliza (regla H-28).

Intervalo en meses = 12 / número de visitas. La visita k (0..N-1) cae en
``start + k * intervalo`` meses, siempre calculado desde ``start`` (nunca
encadenado) y con el día recortado al último del mes cuando no existe (31 ene
-> 28 feb). Solo se conservan las fechas anteriores a ``end``: la renovación
es el día siguiente a ``end_date``.
"""
import calendar
from datetime import date


def add_months(start: date, months: int) -> date:
    """start + months, recortando el día al último del mes destino si no existe."""
    index = start.month - 1 + months
    year, month = start.year + index // 12, index % 12 + 1
    day = min(start.day, calendar.monthrange(year, month)[1])
    return date(year, month, day)


def visit_dates(start: date, end: date, n_visits: int) -> list[date]:
    interval = 12 // n_visits if n_visits > 0 and 12 % n_visits == 0 else 12
    dates = [add_months(start, k * interval) for k in range(n_visits)]
    return [d for d in dates if d < end]
