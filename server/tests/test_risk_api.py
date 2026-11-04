"""Endpoints /api/admin/risk: autenticacion, 503 y arranque sin dependencias de ML.
Las pruebas que calculan riesgo de verdad se omiten sin numpy/pandas/scikit-learn."""
import json
import os
import subprocess
import sys
import uuid
from datetime import timedelta
from pathlib import Path
from types import SimpleNamespace

import pytest

from app.risk import ModeloNoDisponible, service
from app.models.report import Report
from tests.conftest import now
from tests.portal_helpers import make_portal_user, portal_headers
from tests.risk_sintetico import escribir_csv, historial_sintetico, settings_falsos

SERVER = Path(__file__).resolve().parents[1]
RUTAS = ("/api/admin/risk/model/info", "/api/admin/risk/printers", "/api/admin/risk/printers/x")


def _hay_motor() -> bool:
    try:
        import numpy, pandas, sklearn, joblib  # noqa: F401
    except ImportError:
        return False
    return service.RUTA_MODELO_DEFECTO.exists()


necesita_motor = pytest.mark.skipif(not _hay_motor(), reason="faltan numpy/pandas/scikit-learn o el .joblib")


@pytest.mark.parametrize("ruta", RUTAS)
def test_sin_token_401(client, ruta):
    # Sin token: lo mismo que devuelve el resto de /api/admin (HTTPBearer)
    assert client.get(ruta).status_code == client.get("/api/admin/printers").status_code in (401, 403)


@pytest.mark.parametrize("ruta", RUTAS)
def test_tecnico_403(client, tech_headers, ruta):
    assert client.get(ruta, headers=tech_headers).status_code == 403


@pytest.mark.parametrize("ruta", RUTAS)
def test_portal_rechazado(client, db, world, ruta):
    """El token de portal no sirve en /api/admin. require_admin lo rechaza con 401 (su `sub` no existe en `users`), igual
    que en cualquier otro endpoint admin; por eso se compara con /api/admin/printers y nunca puede ser 200."""
    h = portal_headers(db, make_portal_user(db, world.client_row.id))
    esperado = client.get("/api/admin/printers", headers=h).status_code
    assert esperado in (401, 403)
    assert client.get(ruta, headers=h).status_code == esperado


def test_503_sin_archivo_de_modelo(client, admin_headers, monkeypatch, tmp_path):
    monkeypatch.setattr(service, "get_settings",
                        lambda: SimpleNamespace(risk_enabled=True, risk_model_path=str(tmp_path / "no_existe.joblib")))
    for ruta in RUTAS:
        res = client.get(ruta, headers=admin_headers)
        assert res.status_code == 503, ruta
        assert "no disponible" in res.json()["detail"]
        assert str(tmp_path) not in res.json()["detail"]            # la causa va al log, no al cliente


def test_503_con_risk_enabled_false(client, admin_headers, monkeypatch):
    monkeypatch.setattr(service, "get_settings", lambda: SimpleNamespace(risk_enabled=False, risk_model_path=""))
    for ruta in RUTAS:
        assert client.get(ruta, headers=admin_headers).status_code == 503


def test_503_si_faltan_dependencias(client, admin_headers, monkeypatch):
    def sin_motor():
        raise ModeloNoDisponible("Faltan dependencias del modulo de riesgo")
    monkeypatch.setattr(service, "_importar_motor", sin_motor)
    assert client.get("/api/admin/risk/printers", headers=admin_headers).status_code == 503


def test_importar_motor_convierte_importerror(monkeypatch):
    """Si numpy/pandas/sklearn no estan, _importar_motor lanza ModeloNoDisponible (no ImportError)."""
    import app.risk
    monkeypatch.delattr(app.risk, "modelo", raising=False)    # sin el atributo, `from app.risk import modelo` reimporta
    for nombre in ("app.risk.modelo", "numpy"):
        monkeypatch.setitem(sys.modules, nombre, None)         # un modulo en None hace que `import` lance ImportError
    with pytest.raises(ModeloNoDisponible):
        service._importar_motor()


def test_la_app_arranca_sin_numpy_pandas_sklearn():
    """Proceso aparte donde esos paquetes no se pueden importar: la app arranca y el endpoint pide auth/503."""
    codigo = r"""
import sys
class Bloqueo:
    def find_spec(self, nombre, ruta=None, destino=None):
        if nombre.split('.')[0] in ('numpy', 'pandas', 'sklearn', 'scipy', 'joblib'):
            raise ImportError('bloqueado en la prueba: ' + nombre)
sys.meta_path.insert(0, Bloqueo())
from fastapi.testclient import TestClient
import app.main as m
rutas = {r.path for r in m.app.routes}
assert '/api/admin/risk/printers' in rutas, 'el router de riesgo debe registrarse aunque falte el motor'
for mod in ('numpy', 'pandas', 'sklearn'):
    assert mod not in sys.modules, mod + ' se importo al arrancar'
with TestClient(m.app) as c:
    assert c.get('/').status_code == 200
    assert c.get('/api/admin/risk/printers').status_code in (401, 403)
print('OK')
"""
    env = {**os.environ, "DATABASE_URL": "sqlite://", "SECRET_KEY": "x", "APP_ENV": "test",
           "UPLOAD_DIR": str(Path(os.environ.get("TEMP", ".")) / "smp_risk_arranque")}
    res = subprocess.run([sys.executable, "-I", "-c", "import sys; sys.path.insert(0, %r)\n%s" % (str(SERVER), codigo)],
                         cwd=str(SERVER), env=env, capture_output=True, text=True, timeout=120)
    assert res.returncode == 0 and "OK" in res.stdout, res.stdout + res.stderr


# --------------------------------------------------------------------------- con el modelo real

def _reporte(db, printer, dias, cb=None, status="signed"):
    r = Report(id=str(uuid.uuid4()), code=f"R-{uuid.uuid4().hex[:4]}", printer_id=printer.id, tech_id="t",
               service_type="Preventivo", status=status, service_date=now() - timedelta(days=dias),
               linear_inches_counter=1000 + 10 * (100 - dias), technical_checkboxes=json.dumps(cb or {}))
    db.add(r)
    db.commit()


@pytest.fixture()
def historial_csv(tmp_path, monkeypatch):
    """Historial sintetico en un CSV temporal, configurado como risk_historico_path."""
    pytest.importorskip("pandas")
    csv = tmp_path / "historial.csv"
    escribir_csv(historial_sintetico(), csv)
    _configurar(monkeypatch, risk_historico_path=str(csv))
    return csv


def _configurar(monkeypatch, **cambios):
    from app.risk import queries
    for modulo in (service, queries):
        monkeypatch.setattr(modulo, "get_settings", lambda: settings_falsos(**cambios))


@necesita_motor
def test_endpoints_con_modelo(client, db, world, admin_headers, historial_csv):
    for p in world.printers[:2]:
        for dias in (120, 60, 10):
            _reporte(db, p, dias, {"Mantenimiento general": True, "Cabezal dañado": dias == 60})
    # world.printers[2]: sin reportes y sin historial en el CSV -> no aparece
    info = client.get("/api/admin/risk/model/info", headers=admin_headers)
    assert info.status_code == 200 and info.json()["version"]
    assert info.json()["historico_cargado"] is True and info.json()["n_filas_historico"] == len(historial_sintetico())

    lst = client.get("/api/admin/risk/printers", headers=admin_headers)
    assert lst.status_code == 200
    body = lst.json()
    assert body["total"] == 2 and body["sin_visitas"] == 1 and len(body["equipos"]) == 2
    e = body["equipos"][0]
    assert e["rodillo"]["en_monitoreo"] is True and e["cabezal"]["en_monitoreo"] is False
    assert e["visitas_app"] == 3 and e["visitas_historicas"] == 0 and e["vigente"] is True
    assert e["aviso"] and body["aviso"]
    idx = [max(x["cabezal"]["indice_riesgo"], x["rodillo"]["indice_riesgo"]) for x in body["equipos"]]
    assert idx == sorted(idx, reverse=True)

    assert client.get("/api/admin/risk/printers?limit=1", headers=admin_headers).json()["equipos"].__len__() == 1
    assert client.get("/api/admin/risk/printers?client_id=otro", headers=admin_headers).json()["total"] == 0
    assert client.get("/api/admin/risk/printers?level=EXTREMO", headers=admin_headers).status_code == 422
    assert client.get("/api/admin/risk/printers?piece=sensor", headers=admin_headers).status_code == 422

    uno = client.get(f"/api/admin/risk/printers/{world.printers[0].id}", headers=admin_headers)
    assert uno.status_code == 200 and uno.json()["printer_id"] == world.printers[0].id
    assert client.get(f"/api/admin/risk/printers/{world.printers[2].id}", headers=admin_headers).status_code == 404
    assert client.get("/api/admin/risk/printers/no-existe", headers=admin_headers).status_code == 404


@necesita_motor
def test_503_sin_historial_y_info_lo_reporta(client, db, world, admin_headers, monkeypatch, tmp_path):
    for dias in (90, 30, 5):
        _reporte(db, world.printers[0], dias)
    _configurar(monkeypatch, risk_historico_path=str(tmp_path / "no_existe.csv"))
    info = client.get("/api/admin/risk/model/info", headers=admin_headers)
    assert info.status_code == 200
    assert (info.json()["historico_cargado"], info.json()["n_filas_historico"]) == (False, 0)
    assert info.json()["permitir_sin_historico"] is False
    for ruta in ("/api/admin/risk/printers", f"/api/admin/risk/printers/{world.printers[0].id}"):
        res = client.get(ruta, headers=admin_headers)
        assert res.status_code == 503, ruta
        assert "historial de visitas" in res.json()["detail"] and str(tmp_path) not in res.json()["detail"]


@necesita_motor
def test_permitir_sin_historico_calcula_con_aviso(client, db, world, admin_headers, monkeypatch, tmp_path, caplog):
    for dias in (90, 30, 5):
        _reporte(db, world.printers[0], dias)
    _configurar(monkeypatch, risk_historico_path=str(tmp_path / "no_existe.csv"), risk_permitir_sin_historico=True)
    info = client.get("/api/admin/risk/model/info", headers=admin_headers).json()
    assert (info["historico_cargado"], info["n_filas_historico"], info["permitir_sin_historico"]) == (False, 0, True)
    with caplog.at_level("WARNING"):
        res = client.get("/api/admin/risk/printers", headers=admin_headers)
    assert res.status_code == 200 and res.json()["total"] == 1 and res.json()["equipos"][0]["visitas_historicas"] == 0
    assert "SIN historial" in caplog.text
