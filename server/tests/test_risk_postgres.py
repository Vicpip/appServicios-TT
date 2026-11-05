"""Pruebas contra PostgreSQL real (advisory lock del refresh). Se omiten salvo que RISK_TEST_PG_URL apunte a una base
llamada exactamente `servicios_copia`. Solo escriben en printer_risk_snapshots (el refresh; nunca en reports)."""
import os
import subprocess
import sys
from pathlib import Path

import pytest
import sqlalchemy as sa

URL = os.environ.get("RISK_TEST_PG_URL", "")
pytestmark = pytest.mark.skipif(not URL.startswith("postgresql") or not URL.rstrip("/").endswith("/servicios_copia"),
                                reason="requiere RISK_TEST_PG_URL=postgresql://.../servicios_copia")
SERVER = Path(__file__).resolve().parents[1]


@pytest.fixture()
def engine():
    eng = sa.create_engine(URL)
    yield eng
    eng.dispose()


def _cli():
    return subprocess.run([sys.executable, "-m", "app.risk.refresh", "--all"], cwd=SERVER, capture_output=True,
                          text=True, env={**os.environ, "DATABASE_URL": URL}).returncode


def test_esquema_coincide_con_printers(engine):
    insp = sa.inspect(engine)
    tipo = lambda t, c: str(next(x["type"] for x in insp.get_columns(t) if x["name"] == c))
    assert tipo("printer_risk_snapshots", "printer_id") == tipo("printers", "id")
    assert any(u["column_names"] == ["printer_id", "piece"] for u in insp.get_unique_constraints("printer_risk_snapshots"))


def test_cli_sale_con_75_si_el_lock_esta_ocupado_y_no_deja_locks(engine):
    from app.risk import snapshots
    with engine.connect() as holder:
        assert holder.execute(sa.text("SELECT pg_try_advisory_xact_lock(:k)"), {"k": snapshots.LOCK_KEY}).scalar()
        assert _cli() == 75
        holder.rollback()
    assert _cli() == 0
    with engine.connect() as c:
        assert c.execute(sa.text("SELECT count(*) FROM pg_locks WHERE locktype='advisory'")).scalar() == 0
