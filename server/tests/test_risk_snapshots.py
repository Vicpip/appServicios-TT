"""Fase C: snapshots, refresh (por impresora, por poliza, job), concurrencia y migracion 016.
Datos 100 % sinteticos; las pruebas que calculan se omiten sin el motor de ML o sin server/ml_models/modelo_riesgo.joblib."""
import json
import uuid
from datetime import date, timedelta
from types import SimpleNamespace

import pytest
import sqlalchemy as sa
from sqlalchemy.orm import sessionmaker

from app.models.policy import Policy, PolicyPrinter
from app.models.report import Report
from app.models.risk import PrinterRiskSnapshot
from app.risk import refresh as refresh_cli, service, snapshots
from tests.conftest import now
from tests.risk_sintetico import escribir_csv, historial_sintetico
from tests.test_risk_api import _configurar, necesita_motor

NOTA_UNICA = "Se cambio el cabezal; nota-privada-xyz"


def _reporte(db, printer, dias, cb=None, notas=None, status="signed"):
    r = Report(id=str(uuid.uuid4()), code=f"R-{uuid.uuid4().hex[:4]}", printer_id=printer.id, tech_id="t",
               service_type="Preventivo", status=status, service_date=now() - timedelta(days=dias),
               linear_inches_counter=1000 + 10 * (100 - dias), technical_checkboxes=json.dumps(cb or {}), notes=notas)
    db.add(r)
    db.commit()
    return r


def _fabrica(db_engine):
    return sessionmaker(bind=db_engine, autocommit=False, autoflush=False)


@pytest.fixture()
def sembrado(db, world, tmp_path, monkeypatch):
    """Dos impresoras con 3 visitas; la tercera sin visitas. Historial sintetico configurado."""
    pytest.importorskip("pandas")
    csv = tmp_path / "historial.csv"
    escribir_csv(historial_sintetico(), csv)
    _configurar(monkeypatch, risk_historico_path=str(csv))
    for p in world.printers[:2]:
        for dias in (120, 60, 10):
            _reporte(db, p, dias, {"Mantenimiento general": True})
    return world


# --------------------------------------------------------------------------- seguridad

def _posts(world):
    return [f"/api/admin/risk/printers/{world.printers[0].id}/refresh",
            f"/api/admin/policies/{world.policy.id}/risk/refresh"]


def test_post_exige_admin(client, world, tech_headers):
    for ruta in _posts(world):
        assert client.post(ruta).status_code in (401, 403)
        assert client.post(ruta, headers=tech_headers).status_code == 403


def test_post_rechaza_token_de_portal(client, db, world):
    from tests.portal_helpers import make_portal_user, portal_headers
    h = portal_headers(db, make_portal_user(db, world.client_row.id))
    for ruta in _posts(world):
        assert client.post(ruta, headers=h).status_code in (401, 403)


def test_404_impresora_y_poliza_inexistentes(client, admin_headers, world):
    assert client.post("/api/admin/risk/printers/nope/refresh", headers=admin_headers).status_code == 404
    assert client.post("/api/admin/policies/nope/risk/refresh", headers=admin_headers).status_code == 404


def test_409_si_hay_otro_refresh(client, world, admin_headers, monkeypatch):
    def ocupado(db):
        raise snapshots.RefreshOcupado("Ya hay una actualización de riesgo en curso")
    monkeypatch.setattr(snapshots, "bloquear", ocupado)
    for ruta in _posts(world):
        assert client.post(ruta, headers=admin_headers).status_code == 409


def test_bloquear_no_hace_nada_en_sqlite(db):
    snapshots.bloquear(db)       # dialecto sqlite: sin lock, no lanza


# --------------------------------------------------------------------------- refresh

@necesita_motor
def test_refresh_por_impresora(client, db, sembrado, admin_headers):
    world = sembrado
    res = client.post(f"/api/admin/risk/printers/{world.printers[0].id}/refresh", headers=admin_headers)
    assert res.status_code == 200
    body = res.json()
    assert [e["printer_id"] for e in body["equipos"]] == [world.printers[0].id]
    assert body["computed_at"] and body["computed_by"] == world.admin.id
    assert db.query(PrinterRiskSnapshot).count() == 2          # cabezal y rodillo
    assert db.query(PrinterRiskSnapshot).filter_by(printer_id=world.printers[1].id).count() == 0


@necesita_motor
def test_refresh_sin_visitas_404(client, sembrado, admin_headers):
    res = client.post(f"/api/admin/risk/printers/{sembrado.printers[2].id}/refresh", headers=admin_headers)
    assert res.status_code == 404


@necesita_motor
def test_refresh_por_poliza_e_impresora_en_dos_polizas(client, db, sembrado, admin_headers):
    world = sembrado
    p2 = Policy(id=str(uuid.uuid4()), code="P-002", client_id=world.client_row.id, folio="POL-2026-002",
                start_date=now(), end_date=now() + timedelta(days=100), coverage_type="Integral", status="Active")
    db.add(p2)
    db.flush()
    db.add(PolicyPrinter(id=str(uuid.uuid4()), policy_id=p2.id, printer_id=world.printers[0].id))   # tambien en la 1
    db.commit()
    r1 = client.post(f"/api/admin/policies/{world.policy.id}/risk/refresh", headers=admin_headers)
    assert r1.status_code == 200 and len(r1.json()["equipos"]) == 2 and r1.json()["sin_datos"] == 1
    r2 = client.post(f"/api/admin/policies/{p2.id}/risk/refresh", headers=admin_headers)
    assert r2.status_code == 200 and len(r2.json()["equipos"]) == 1
    assert db.query(PrinterRiskSnapshot).count() == 4          # 2 impresoras x 2 piezas, sin duplicados


@necesita_motor
def test_poliza_eliminada_404(client, db, sembrado, admin_headers):
    sembrado.policy.status = "Deleted"
    db.commit()
    assert client.post(f"/api/admin/policies/{sembrado.policy.id}/risk/refresh", headers=admin_headers).status_code == 404


@necesita_motor
def test_inputs_json_solo_numeros_sin_texto_de_notas(client, db, sembrado, admin_headers):
    p = sembrado.printers[0]
    _reporte(db, p, 1, {}, notas=NOTA_UNICA)
    assert client.post(f"/api/admin/risk/printers/{p.id}/refresh", headers=admin_headers).status_code == 200
    filas = db.query(PrinterRiskSnapshot).filter_by(printer_id=p.id).all()
    assert len(filas) == 2
    for s in filas:
        assert "nota-privada" not in s.inputs_json and p.serial_number not in s.inputs_json
        datos = json.loads(s.inputs_json)
        assert all(v is None or isinstance(v, (int, float)) for v in datos["entradas"].values())
        assert datos["dano_solo_notas"] == {"cabezal": True, "rodillo": False}
    api = client.get(f"/api/admin/risk/printers/{p.id}", headers=admin_headers).json()
    assert api["cabezal"]["dano_detectado_en_notas"] is True and api["rodillo"]["dano_detectado_en_notas"] is False
    assert api["cabezal"]["danada_en_ultima_visita"] is True


@necesita_motor
def test_stale_vigente_y_modelo_desactualizado(client, db, sembrado, admin_headers):
    p = sembrado.printers[0]
    url = f"/api/admin/risk/printers/{p.id}"
    client.post(url + "/refresh", headers=admin_headers)
    base = client.get(url, headers=admin_headers).json()
    assert (base["stale"], base["vigente"], base["modelo_desactualizado"]) == (False, True, False)

    _reporte(db, p, 0)                                   # reporte nuevo despues del calculo
    assert client.get(url, headers=admin_headers).json()["stale"] is True
    client.post(url + "/refresh", headers=admin_headers)
    assert client.get(url, headers=admin_headers).json()["stale"] is False

    for s in db.query(PrinterRiskSnapshot).filter_by(printer_id=p.id):
        s.valid_until = date.today() - timedelta(days=1)       # misma "hoy" que snapshots.leer (local, no UTC)
        s.model_version = "viejo"
    db.commit()
    viejo = client.get(url, headers=admin_headers).json()
    assert viejo["vigente"] is False and viejo["modelo_desactualizado"] is True


@necesita_motor
def test_reportes_no_elegibles_no_marcan_stale(client, db, sembrado, admin_headers):
    p = sembrado.printers[0]
    url = f"/api/admin/risk/printers/{p.id}"
    client.post(url + "/refresh", headers=admin_headers)
    _reporte(db, p, 0, status="Draft")
    assert client.get(url, headers=admin_headers).json()["stale"] is False


@necesita_motor
def test_lista_filtra_y_ordena_desde_snapshots(client, sembrado, admin_headers):
    client.post(f"/api/admin/policies/{sembrado.policy.id}/risk/refresh", headers=admin_headers)
    body = client.get("/api/admin/risk/printers", headers=admin_headers).json()
    assert body["total"] == 2
    idx = [max(e["cabezal"]["indice_riesgo"], e["rodillo"]["indice_riesgo"]) for e in body["equipos"]]
    assert idx == sorted(idx, reverse=True)
    nivel = body["equipos"][0]["cabezal"]["nivel"]
    filtrado = client.get(f"/api/admin/risk/printers?level={nivel}&piece=cabezal", headers=admin_headers).json()
    assert all(e["cabezal"]["nivel"] == nivel for e in filtrado["equipos"])


# --------------------------------------------------------------------------- inelegibles

def _total(client, headers):
    return client.get("/api/admin/risk/printers", headers=headers).json()["total"]


@necesita_motor
def test_excluir_serie_despues_de_calcular_borra_el_snapshot(db, db_engine, client, sembrado, admin_headers, monkeypatch):
    fabrica = _fabrica(db_engine)
    assert refresh_cli.main(["--all"], session_factory=fabrica) == 0
    assert db.query(PrinterRiskSnapshot).count() == 4 and _total(client, admin_headers) == 2

    excluida = sembrado.printers[0]
    _configurar(monkeypatch, risk_historico_path=service.get_settings().risk_historico_path,
                risk_series_excluidas=excluida.serial_number.lower())
    # el GET ya no la lista, aunque la fila vieja siga en la tabla
    db.expire_all()
    assert db.query(PrinterRiskSnapshot).filter_by(printer_id=excluida.id).count() == 2
    body = client.get("/api/admin/risk/printers", headers=admin_headers).json()
    assert [e["printer_id"] for e in body["equipos"]] == [sembrado.printers[1].id]
    assert client.get(f"/api/admin/risk/printers/{excluida.id}", headers=admin_headers).status_code == 404

    # el refresh borra las filas viejas y deja las demas
    assert refresh_cli.main(["--all"], session_factory=fabrica) == 0
    db.expire_all()
    assert db.query(PrinterRiskSnapshot).filter_by(printer_id=excluida.id).count() == 0
    assert db.query(PrinterRiskSnapshot).count() == 2 and _total(client, admin_headers) == 1


@necesita_motor
def test_refresh_borra_snapshots_de_inactivas_cliente_excluido_y_sin_visitas(db, db_engine, client, sembrado, admin_headers,
                                                                              monkeypatch):
    fabrica = _fabrica(db_engine)
    refresh_cli.main(["--all"], session_factory=fabrica)
    assert db.query(PrinterRiskSnapshot).count() == 4
    sembrado.printers[0].is_active = False
    db.commit()
    refresh_cli.main(["--all"], session_factory=fabrica)
    db.expire_all()
    assert {s.printer_id for s in db.query(PrinterRiskSnapshot)} == {sembrado.printers[1].id}

    _configurar(monkeypatch, risk_historico_path=service.get_settings().risk_historico_path,
                risk_clientes_excluidos=sembrado.client_row.name)
    refresh_cli.main(["--all"], session_factory=fabrica)
    db.expire_all()
    assert db.query(PrinterRiskSnapshot).count() == 0 and _total(client, admin_headers) == 0


@necesita_motor
def test_refresh_de_una_impresora_no_toca_las_demas(db, db_engine, sembrado):
    fabrica = _fabrica(db_engine)
    refresh_cli.main(["--all"], session_factory=fabrica)
    refresh_cli.main(["--printer", sembrado.printers[0].id], session_factory=fabrica)
    db.expire_all()
    assert db.query(PrinterRiskSnapshot).count() == 4


@necesita_motor
def test_lectura_ignora_fila_de_equipo_sin_visitas(db, client, sembrado, admin_headers):
    p = sembrado.printers[2]            # sin reportes ni historial
    campos = dict(level="BAJO", risk_index=1.0, damaged_last_visit=False, previous_damages=0, visits_count=3,
                  short_history=False, last_visit_date=now().date(), valid_until=now().date() + timedelta(days=9),
                  model_version="v", computed_at=now(), inputs_json='{"visitas_app": 0, "visitas_historicas": 0}')
    for pz in ("cabezal", "rodillo"):
        db.add(PrinterRiskSnapshot(id=str(uuid.uuid4()), printer_id=p.id, piece=pz, **campos))
    db.commit()
    assert client.get(f"/api/admin/risk/printers/{p.id}", headers=admin_headers).status_code == 404
    assert _total(client, admin_headers) == 0


# --------------------------------------------------------------------------- job (CLI)

@necesita_motor
def test_job_all_es_idempotente(db, db_engine, sembrado):
    fabrica = _fabrica(db_engine)
    assert refresh_cli.main(["--all"], session_factory=fabrica) == 0
    primera = {(s.printer_id, s.piece): s.id for s in db.query(PrinterRiskSnapshot)}
    assert len(primera) == 4
    db.expire_all()
    assert refresh_cli.main(["--all"], session_factory=fabrica) == 0
    db.expire_all()
    assert {(s.printer_id, s.piece): s.id for s in db.query(PrinterRiskSnapshot)} == primera   # upsert, sin duplicados
    assert all(s.computed_by is None for s in db.query(PrinterRiskSnapshot))                    # lo hizo el job


@necesita_motor
def test_job_no_escribe_en_reports(db, db_engine, sembrado):
    antes = db.execute(sa.text("SELECT count(*) FROM reports")).scalar()
    refresh_cli.main(["--printer", sembrado.printers[0].id], session_factory=_fabrica(db_engine))
    assert db.execute(sa.text("SELECT count(*) FROM reports")).scalar() == antes


def test_job_sin_modelo_sale_con_error(db_engine, world, monkeypatch, tmp_path):
    monkeypatch.setattr(service, "get_settings",
                        lambda: SimpleNamespace(risk_enabled=True, risk_model_path=str(tmp_path / "no.joblib")))
    assert refresh_cli.main(["--all"], session_factory=_fabrica(db_engine)) == 1


def test_job_impresora_inexistente(db_engine, world):
    assert refresh_cli.main(["--printer", "nope"], session_factory=_fabrica(db_engine)) == 1


def test_job_ocupado_sale_75(db_engine, world, monkeypatch):
    def ocupado(db):
        raise snapshots.RefreshOcupado("x")
    monkeypatch.setattr(snapshots, "bloquear", ocupado)
    assert refresh_cli.main(["--all"], session_factory=_fabrica(db_engine)) == 75


def test_job_exige_un_modo():
    with pytest.raises(SystemExit) as e:
        refresh_cli.main([])
    assert e.value.code == 2


# --------------------------------------------------------------------------- migracion 016

def _migracion():
    import importlib.util
    from pathlib import Path
    ruta = Path(__file__).resolve().parents[1] / "alembic" / "versions" / "016_printer_risk_snapshots.py"
    spec = importlib.util.spec_from_file_location("mig016", ruta)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def _correr(engine, funcion):
    from alembic.migration import MigrationContext
    from alembic.operations import Operations
    with engine.begin() as con:
        with Operations.context(MigrationContext.configure(con)):
            funcion()


def _motor_vacio():
    from sqlalchemy.pool import StaticPool
    e = sa.create_engine("sqlite://", poolclass=StaticPool, connect_args={"check_same_thread": False})
    with e.begin() as con:
        con.execute(sa.text("CREATE TABLE printers (id VARCHAR PRIMARY KEY)"))
    return e


def test_migracion_metadatos():
    m = _migracion()
    assert (m.revision, m.down_revision) == ("016", "015")


def test_migracion_sube_baja_sube_e_idempotente():
    m, e = _migracion(), _motor_vacio()
    tiene = lambda: sa.inspect(e).has_table("printer_risk_snapshots")
    _correr(e, m.upgrade)
    assert tiene()
    assert "ix_printer_risk_snapshots_printer_id" in {i["name"] for i in sa.inspect(e).get_indexes("printer_risk_snapshots")}
    _correr(e, m.upgrade)                  # segunda vez: no-op, no falla
    assert tiene()
    _correr(e, m.downgrade)
    assert not tiene()
    _correr(e, m.upgrade)
    assert tiene()


def test_migracion_con_tabla_ya_creada_por_create_all():
    from app.database import Base
    import app.models  # noqa: F401
    m, e = _migracion(), _motor_vacio()
    Base.metadata.create_all(e)            # como hace main.py al arrancar
    assert sa.inspect(e).has_table("printer_risk_snapshots")
    _correr(e, m.upgrade)                  # no debe fallar ni duplicar
    _correr(e, m.downgrade)
    assert not sa.inspect(e).has_table("printer_risk_snapshots")


def test_unicidad_printer_piece(db, world):
    campos = dict(level="BAJO", risk_index=1.0, damaged_last_visit=False, previous_damages=0, visits_count=3,
                  short_history=False, last_visit_date=now().date(), valid_until=now().date(), model_version="v",
                  computed_at=now())
    db.add(PrinterRiskSnapshot(id="a", printer_id=world.printers[0].id, piece="cabezal", **campos))
    db.commit()
    db.add(PrinterRiskSnapshot(id="b", printer_id=world.printers[0].id, piece="cabezal", **campos))
    with pytest.raises(sa.exc.IntegrityError):
        db.commit()
    db.rollback()
