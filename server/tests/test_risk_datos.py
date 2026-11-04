"""Datos reales -> visitas del modelo de riesgo (app/risk/queries.py). Se omite sin numpy/pandas; la paridad con el
modelo ademas necesita scikit-learn y el .joblib.
Las pruebas corren con un historial SINTETICO (seriales SN-TEST-*, tests/risk_sintetico.py); las mismas pruebas contra el
CSV real de Aurora (no versionado, datos de clientes) se omiten si el archivo no existe."""
import json
import logging
import uuid
from datetime import date, datetime, timedelta
from pathlib import Path

import pytest
from sqlalchemy import text

pytest.importorskip("numpy")
pytest.importorskip("pandas")

import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402

from app.models.area import Area  # noqa: E402
from app.models.catalog import CatalogModel  # noqa: E402
from app.models.client import Client  # noqa: E402
from app.models.plant import Plant  # noqa: E402
from app.models.policy import Policy, PolicyPrinter  # noqa: E402
from app.models.printer import Printer  # noqa: E402
from app.models.report import Report  # noqa: E402
from app.risk import datos as D  # noqa: E402
from app.risk import queries as Q  # noqa: E402
from tests.conftest import now  # noqa: E402
from tests.risk_sintetico import escribir_csv, historial_sintetico, settings_falsos  # noqa: E402

RAIZ = Path(__file__).resolve().parents[2]
CSV_REAL = next((p for p in (Q.RUTA_HISTORICO, RAIZ / "modulo_riesgo" / "datos_ejemplo" / "base_visitas_min.csv")
                 if p.is_file()), None)
HOY = date(2026, 10, 10)
VACIO = pd.DataFrame(columns=D.COLS)


# --------------------------------------------------------------------------- ayudas

class Sembrador:
    """Crea cliente/planta/area, modelos de catalogo, impresoras y reportes en la base de prueba."""

    def __init__(self, db):
        self.db = db
        self.client = Client(id=str(uuid.uuid4()), name="Cliente de prueba", is_active=True)
        self.plant = Plant(id=str(uuid.uuid4()), client_id=self.client.id, name="P1")
        db.add_all([self.client, self.plant])
        db.flush()
        self.area = Area(id=str(uuid.uuid4()), plant_id=self.plant.id, name="A1")
        db.add(self.area)
        db.flush()
        self.modelos: dict[tuple, CatalogModel] = {}
        self.n = 0

    def modelo(self, nombre: str, dpi: int, marca: str = "Zebra") -> CatalogModel:
        if (nombre, dpi, marca) not in self.modelos:
            m = CatalogModel(id=str(uuid.uuid4()), brand=marca, model_name=nombre, dpi=dpi, is_active=True)
            self.db.add(m)
            self.db.flush()
            self.modelos[(nombre, dpi, marca)] = m
        return self.modelos[(nombre, dpi, marca)]

    def impresora(self, serie: str, nombre="ZT411", dpi=300, marca="Zebra", activa=True) -> Printer:
        m = self.modelo(nombre, dpi, marca)
        p = Printer(id=str(uuid.uuid4()), qr_uuid=str(uuid.uuid4()), serial_number=serie, client_id=self.client.id,
                    plant_id=self.plant.id, area_id=self.area.id, model_id=m.id, is_active=activa)
        self.db.add(p)
        self.db.flush()
        return p

    def reporte(self, p: Printer, fecha, status="signed", tipo="Preventivo", contador=1000, cb=None,
                supersedes=None, notes=None) -> Report:
        self.n += 1
        r = Report(id=str(uuid.uuid4()), code=f"R-{self.n}", printer_id=p.id, tech_id="t", service_type=tipo,
                   status=status, service_date=datetime.combine(fecha, datetime.min.time()),
                   linear_inches_counter=contador, technical_checkboxes=json.dumps(cb) if cb is not None else "{}",
                   supersedes_report_id=supersedes, notes=notes, created_at=datetime(2026, 1, 1) + timedelta(seconds=self.n))
        self.db.add(r)
        self.db.flush()
        return r


def _checklist(fila) -> dict:
    return {"Mantenimiento general": bool(fila.mantenimiento), "Calibración sensores": bool(fila.calibracion),
            "Rodillo dañado": bool(fila.rodillo), "Cabezal dañado": bool(fila.cabezal),
            "Sensor ribbon dañado": bool(fila.sensor_ribbon), "Sensor papel dañado": bool(fila.sensor_papel),
            "Pruebas": False, "Otros": False}


def _parse_modelo(m: str) -> tuple[str, int]:
    nombre, dpi = m.rsplit("-", 1)
    return nombre, int(dpi[:-3])


def sembrar_filas(db, filas: pd.DataFrame, s: Sembrador | None = None) -> Sembrador:
    """Un reporte ORM por fila del CSV, en orden de (serie, fecha, fila_origen) -> created_at creciente."""
    s = s or Sembrador(db)
    impresoras = {}
    for fila in filas.sort_values(["numero_serie", "fecha", "fila_origen"]).itertuples():
        if fila.numero_serie not in impresoras:
            nombre, dpi = _parse_modelo(fila.modelo)
            impresoras[fila.numero_serie] = s.impresora(fila.numero_serie, nombre, dpi)
        contador = 0 if pd.isna(fila.contador_1) else int(fila.contador_1)
        s.reporte(impresoras[fila.numero_serie], fila.fecha.date(), tipo=fila.tipo_servicio, contador=contador,
                  cb=_checklist(fila))
    db.commit()
    return s


def _cero_a_nan(V: pd.DataFrame, desde=None) -> pd.DataFrame:
    """Lo que hace la consulta con los reportes de la app (contador 0 -> NaN), para armar la referencia."""
    V = V.copy()
    marca = (V.contador_1 == 0) if desde is None else ((V.contador_1 == 0) & (V.fecha.dt.date >= desde))
    V.loc[marca, "contador_1"] = np.nan
    return V


@pytest.fixture(scope="module", params=["sintetico", "real"])
def V(request):
    if request.param == "sintetico":
        return historial_sintetico()
    if CSV_REAL is None:
        pytest.skip("no existe el CSV real de Aurora (no se versiona)")
    return D.cargar_visitas(CSV_REAL)


@pytest.fixture(scope="module")
def art():
    pytest.importorskip("sklearn")
    pytest.importorskip("joblib")
    from app.risk import modelo as M
    from app.risk import service
    if not service.RUTA_MODELO_DEFECTO.exists():
        pytest.skip("falta server/ml_models/modelo_riesgo.joblib (no se versiona: copialo a mano o con scp)")
    return M.cargar(service.RUTA_MODELO_DEFECTO)


def _comparar(a: list[dict], b: list[dict]):
    a = {x["numero_serie"]: x for x in a}
    b = {x["numero_serie"]: x for x in b}
    assert a.keys() == b.keys()
    for sn in a:
        for pz in ("cabezal", "rodillo"):
            assert a[sn][pz] == b[sn][pz], (sn, pz)
        for k in ("fecha_ultima_visita", "visitas_registradas", "historial_corto", "vigente", "modelo_impresora"):
            assert a[sn][k] == b[sn][k], (sn, k)


# --------------------------------------------------------------------------- el CSV historico

def test_csv_real_historico_es_el_de_aurora():
    base = RAIZ / "modulo_riesgo" / "datos_ejemplo" / "base_visitas_min.csv"
    if not (Q.RUTA_HISTORICO.is_file() and base.is_file()):
        pytest.skip("no existe el CSV real de Aurora (no se versiona)")
    assert Q.RUTA_HISTORICO.read_bytes() == base.read_bytes()
    assert len(Q.cargar_historico(Q.RUTA_HISTORICO)) == 426


def test_historial_sintetico_es_inventado():
    S = historial_sintetico()
    assert set(S.numero_serie) == {f"SN-TEST-{k:03d}" for k in range(1, 15)}
    assert list(S.columns) == D.COLS and len(S) > 100
    pd.testing.assert_frame_equal(S, historial_sintetico())          # determinista


# --------------------------------------------------------------------------- (i) paridad y (ii) combinacion

def test_paridad_con_el_csv_de_aurora(db, art, V):
    """Reportes ORM sembrados desde el CSV, sin historial, dan los mismos resultados que predecir() directo."""
    from app.risk import modelo as M, service
    sembrar_filas(db, V)
    esperado = M.predecir(art, _cero_a_nan(V), hoy=HOY)
    res = service.calcular(db, hoy=HOY, historico=VACIO)
    assert len(res.equipos) == V.numero_serie.nunique()
    _comparar(esperado, res.equipos)
    assert all(e["visitas_historicas"] == 0 for e in res.equipos)
    assert sum(e["visitas_app"] for e in res.equipos) == len(V)


def _corte_sin_cercania(V: pd.DataFrame) -> date:
    """Fecha que parte el CSV sin que ninguna impresora tenga visitas a <=2 dias a ambos lados (para que el margen
    de duplicados no descarte nada). Se elige la que deja mas impresoras con historial en los dos lados."""
    mejor, mejor_n = None, -1
    for c in sorted(V.fecha.dt.date.unique())[1:]:
        ok, ambos = True, 0
        for _, g in V.groupby("numero_serie"):
            antes, despues = g[g.fecha.dt.date < c], g[g.fecha.dt.date >= c]
            if len(antes) and len(despues):
                ambos += 1
                if (despues.fecha.min().date() - antes.fecha.max().date()).days <= Q.MARGEN_DUPLICADO_DIAS:
                    ok = False
                    break
        if ok and ambos > mejor_n:
            mejor, mejor_n = c, ambos
    assert mejor is not None and mejor_n >= 10, "no hay una fecha de corte util en el CSV"
    return mejor


def test_combinacion_historial_mas_app_igual_al_csv_completo(db, art, V):
    """Parte posterior en ORM + parte anterior como historial == CSV completo."""
    from app.risk import modelo as M, service
    corte = _corte_sin_cercania(V)
    hist = V[V.fecha.dt.date < corte]
    sembrar_filas(db, V[V.fecha.dt.date >= corte])
    # Solo existen en `printers` los equipos con alguna visita desde el corte; los demas (solo CSV) no se puntuan (D-12).
    en_printers = V[V.fecha.dt.date >= corte].numero_serie.unique()
    assert 0 < len(en_printers) <= V.numero_serie.nunique()
    esperado = M.predecir(art, _cero_a_nan(V[V.numero_serie.isin(en_printers)], desde=corte), hoy=HOY)
    res = service.calcular(db, hoy=HOY, historico=hist)
    _comparar(esperado, res.equipos)
    con_ambos = [e for e in res.equipos if e["visitas_app"] and e["visitas_historicas"]]
    assert len(con_ambos) >= 10
    assert all(e["visitas_registradas"] == e["visitas_app"] + e["visitas_historicas"] for e in res.equipos)


def test_impresora_sin_reportes_usa_el_csv_completo(db, art, V):
    from app.risk import modelo as M, service
    sn = V.groupby("numero_serie").size().idxmax()
    nombre, dpi = _parse_modelo(V[V.numero_serie == sn].modelo.iloc[0])
    Sembrador(db).impresora(sn, nombre, dpi)
    db.commit()
    res = service.calcular(db, hoy=HOY, historico=V)
    assert len(res.equipos) == 1
    e = res.equipos[0]
    assert e["visitas_app"] == 0 and e["visitas_historicas"] == int((V.numero_serie == sn).sum())
    _comparar(M.predecir(art, V[V.numero_serie == sn], hoy=HOY), res.equipos)


def test_no_se_puntua_lo_que_no_existe_en_printers(db):
    """Series que solo estan en el CSV (no en printers) no se calculan."""
    Sembrador(db).impresora("SERIE-NUEVA")
    db.commit()
    v = Q.construir_visitas(db, historico=historial_sintetico())
    assert list(v.info) == ["SERIE-NUEVA"] and v.sin_datos == ["SERIE-NUEVA"] and len(v.df) == 0


# --------------------------------------------------------------------------- (iii) sin duplicados con el margen

def test_margen_de_dos_dias_evita_duplicar_la_visita(db):
    s = Sembrador(db)
    p = s.impresora("DUP-1")
    d0 = date(2026, 5, 10)
    s.reporte(p, d0)
    s.reporte(p, d0 + timedelta(days=30))
    db.commit()
    hist = D.preparar_visitas(pd.DataFrame([
        dict(numero_serie="DUP-1", fila_origen=i, fecha=d0 - timedelta(days=dias), modelo="ZT411-300dpi",
             tipo_servicio="Preventivo", contador_1=100 + i, mantenimiento=1, calibracion=0, rodillo=0, cabezal=0,
             sensor_ribbon=0, sensor_papel=0, falla=0)
        for i, dias in enumerate((60, 3, 2, 1, 0))]))
    v = Q.construir_visitas(db, historico=hist)
    i = v.info["DUP-1"]
    assert (i.visitas_app, i.visitas_historicas, i.corte) == (2, 2, d0)       # entran -60 y -3; no -2, -1, 0
    assert len(v.df) == 4
    fechas = [f.date() for f in v.df.fecha]
    assert d0 - timedelta(days=2) not in fechas and d0 - timedelta(days=1) not in fechas
    assert fechas.count(d0) == 1                                               # la visita del dia del corte, una sola vez
    assert list(v.df.fila_origen) == [0, 1, Q.OFFSET_APP, Q.OFFSET_APP + 1]    # las de la app van despues (D-13)


# --------------------------------------------------------------------------- (iv) contador 0, columnas y modelo

def test_contador_cero_es_dato_faltante_y_columnas_exactas(db):
    s = Sembrador(db)
    p = s.impresora("CNT-1", "zt411 ", 300)
    s.reporte(p, date(2026, 6, 1), contador=0, tipo=" correctivo ", cb={"Cabezal dañado": True, "Mantenimiento general": True})
    s.reporte(p, date(2026, 7, 1), contador=150, tipo="Diagnostico", cb={"Cabezal dañado": "true", "Rodillo dañado": 1})
    s.reporte(p, date(2026, 8, 1), contador=200, tipo="Instalación")
    db.commit()
    v = Q.construir_visitas(db, historico=VACIO)
    assert list(v.df.columns) == D.COLS
    a, b, c = (v.df.iloc[i] for i in range(3))
    assert pd.isna(a.contador_1) and b.contador_1 == 150 and c.contador_1 == 200
    assert (a.modelo, a.tipo_servicio, b.tipo_servicio, c.tipo_servicio) == ("ZT411-300dpi", "Correctivo", "Diagnóstico", "Instalación")
    assert (a.cabezal, a.mantenimiento, a.falla) == (1, 1, 1)
    assert (b.cabezal, b.rodillo, b.falla) == (0, 0, 0)         # solo `is True` cuenta: "true" y 1 no son True
    assert c.falla == 0 and c.mantenimiento == 0


def test_checklist_roto_no_truena(db):
    s = Sembrador(db)
    p = s.impresora("CB-1")
    for texto in ("no es json", "[1, 2]", "null", ""):
        r = s.reporte(p, date(2026, 6, 1))
        r.technical_checkboxes = texto
    db.commit()
    v = Q.construir_visitas(db, historico=VACIO)
    assert len(v.df) == 4 and int(v.df.falla.sum()) == 0


# --------------------------------------------------------------------------- (v) no Zebra

@pytest.mark.parametrize("marca,modelo,excluido", [
    ("HP", "LaserJet 4250n", True), ("HP", "LaserJet 600 M601", True), ("HP", "OfficeJet Pro 7740", True),
    ("Epson", "Microline 691", True), ("", "DVR", True), ("Zebra", "HP LaserJet", True),
    ("Zebra", "GC420t", False), ("Zebra", "ZD621", False), ("Zebra", "ZD420", False), ("Zebra", "ZQ520", False),
    ("Zebra", "ZE500", False), ("Zebra", "105 SL PLUS", False), ("Zebra", "ZM400", False),
    ("Zebra", "ZT411", False), ("Zebra", "110Xi4", False), ("Zebra Technologies", "220XI4", False),
])
def test_es_modelo_excluido(marca, modelo, excluido):
    assert Q.es_modelo_excluido(marca, modelo) is excluido


def test_no_zebra_no_se_puntua_y_se_registra(db, caplog):
    s = Sembrador(db)
    zebra = s.impresora("ZEB-1", "GC420t", 203)
    laser = s.impresora("HP-1", "LaserJet 4250n", 600, marca="HP")
    dvr = s.impresora("DVR-1", "DVR", 1, marca="Genérico")
    for p in (zebra, laser, dvr):
        s.reporte(p, date(2026, 6, 1))
        s.reporte(p, date(2026, 7, 1))
    db.commit()
    with caplog.at_level(logging.INFO, logger="app.risk.queries"):
        v = Q.construir_visitas(db, historico=VACIO)
    assert set(v.df.numero_serie) == {"ZEB-1"} and list(v.info) == ["ZEB-1"]
    assert sorted(x[0] for x in v.excluidas) == ["DVR-1", "HP-1"]
    assert "HP-1" in caplog.text and "DVR-1" in caplog.text


def test_exclusion_configurable(db):
    s = Sembrador(db)
    s.reporte(s.impresora("X-1", "ZT411", 300), date(2026, 6, 1))
    db.commit()
    assert Q.construir_visitas(db, historico=VACIO, excluidos=("ZT4",)).excluidas == [("X-1", "ZT411-300dpi")]


# --------------------------------------------------------------------------- (ix) polizas y (x) estados

def test_impresora_en_dos_polizas_no_duplica_datos(db, world):
    for p in world.printers[:2]:
        for dias in (90, 30, 5):
            r = Report(id=str(uuid.uuid4()), code=f"R-{uuid.uuid4().hex[:4]}", printer_id=p.id, tech_id="t",
                       service_type="Preventivo", status="signed", service_date=now() - timedelta(days=dias),
                       linear_inches_counter=100, technical_checkboxes="{}")
            db.add(r)
    db.commit()
    antes = Q.construir_visitas(db, historico=VACIO)
    p2 = Policy(id=str(uuid.uuid4()), code="P-002", client_id=world.client_row.id, folio="POL-2026-002",
                start_date=now() - timedelta(days=10), end_date=now() + timedelta(days=200), coverage_type="Integral",
                status="Active", frequency_maintenance="Semestral")
    db.add(p2)
    db.flush()
    for p in world.printers:
        db.add(PolicyPrinter(id=str(uuid.uuid4()), policy_id=p2.id, printer_id=p.id))
    db.commit()
    despues = Q.construir_visitas(db, historico=VACIO)
    assert len(antes.df) == len(despues.df) == 6
    pd.testing.assert_frame_equal(antes.df, despues.df)
    assert {i.visitas_app for i in despues.info.values()} == {3, 0}


def test_estados_elegibles_y_exclusiones(db):
    s = Sembrador(db)
    p = s.impresora("EST-1")
    dia = date(2026, 1, 1)
    incluidos = ["signed", "Signed", "Synced", "pending_delivery", "pending_group_signature"]
    for i, st in enumerate(incluidos + ["Draft", "Deleted", "algo_nuevo", "", "SIGNED"]):
        s.reporte(p, dia + timedelta(days=i), status=st)
    viejo = s.reporte(p, dia + timedelta(days=20))                       # reemplazado por otro
    s.reporte(p, dia + timedelta(days=21), supersedes=viejo.id)
    inactiva = s.impresora("EST-2", activa=False)
    s.reporte(inactiva, dia)
    db.commit()
    v = Q.construir_visitas(db, historico=VACIO)
    assert list(v.info) == ["EST-1"]
    assert v.info["EST-1"].visitas_app == len(incluidos) + 1               # + el que reemplaza; no el reemplazado ni Draft/Deleted
    assert Q.ESTADOS_ELEGIBLES == tuple(incluidos)
    assert dia + timedelta(days=20) not in [f.date() for f in v.df.fecha]


def test_filtra_por_printer_ids_y_cliente(db):
    s = Sembrador(db)
    a, b = s.impresora("F-A"), s.impresora("F-B")
    s.reporte(a, date(2026, 6, 1))
    s.reporte(b, date(2026, 6, 2))
    db.commit()
    assert list(Q.construir_visitas(db, [a.id], historico=VACIO).info) == ["F-A"]
    assert len(Q.construir_visitas(db, client_id=s.client.id, historico=VACIO).info) == 2
    assert len(Q.construir_visitas(db, client_id="otro", historico=VACIO).info) == 0
    assert len(Q.construir_visitas(db, [], historico=VACIO).info) == 0


# --------------------------------------------------------------------------- diagnostico (CLI de solo lectura)

def test_diagnostico_posibles_duplicados_y_salida(db, art, tmp_path, monkeypatch, capsys):
    from app.risk import diagnostico
    V = historial_sintetico()
    csv = tmp_path / "historial.csv"
    escribir_csv(V, csv)
    monkeypatch.setattr(Q, "get_settings", lambda: settings_falsos(risk_historico_path=str(csv)))
    sn = V.groupby("numero_serie").size().idxmax()
    g = V[V.numero_serie == sn]
    nombre, dpi = _parse_modelo(g.modelo.iloc[0])
    s = Sembrador(db)
    p = s.impresora(sn, nombre, dpi)
    primero = g.fecha.iloc[len(g) // 2].date()
    s.reporte(p, primero + timedelta(days=1))                    # a 1 dia de una visita del historial: posible duplicado
    db.commit()
    v = Q.construir_visitas(db)
    dups = diagnostico.posibles_duplicados(v, Q.cargar_historico(), 3)
    assert [d[0] for d in dups] == [sn] and str(primero) in dups[0][2]

    ref = tmp_path / "ref.json"
    ref.write_text(json.dumps({"equipos": [{"numero_serie": sn, "cabezal": {"nivel": "BAJO", "indice_riesgo": 1.0},
                                           "rodillo": {"nivel": "BAJO", "indice_riesgo": 1.0}}]}), encoding="utf-8")
    antes = db.execute(text("select count(*) from reports")).scalar()
    monkeypatch.setattr("app.database.SessionLocal", lambda: db)
    assert diagnostico.main(["--ejemplo", str(ref)]) == 0
    salida = capsys.readouterr().out
    assert "Posibles duplicados" in salida and sn in salida
    assert "historial_corto" in salida and "cabezal: ALTO=" in salida and "Comparacion informativa" in salida
    assert db.execute(text("select count(*) from reports")).scalar() == antes   # solo lectura


def test_diagnostico_sin_historial_avisa_y_falla(db, tmp_path, monkeypatch, capsys):
    from app.risk import diagnostico
    monkeypatch.setattr(Q, "get_settings", lambda: settings_falsos(risk_historico_path=str(tmp_path / "no_existe.csv")))
    monkeypatch.setattr("app.database.SessionLocal", lambda: db)
    assert diagnostico.main([]) == 1
    assert "historial" in capsys.readouterr().out.lower()


# --------------------------------------------------------------------------- series excluidas (RISK_SERIES_EXCLUIDAS)

def test_series_excluidas_por_configuracion(db, monkeypatch, caplog):
    s = Sembrador(db)
    for serie in ("DEMO-A", "DEMO-B", "REAL-1"):
        p = s.impresora(serie)
        s.reporte(p, date(2026, 6, 1))
        s.reporte(p, date(2026, 7, 1))
    db.commit()
    monkeypatch.setattr(Q, "get_settings", lambda: settings_falsos(risk_series_excluidas=" demo-a , DEMO-B ,, "))
    with caplog.at_level(logging.INFO, logger="app.risk.queries"):
        v = Q.construir_visitas(db, historico=VACIO)
    assert list(v.info) == ["REAL-1"] and set(v.df.numero_serie) == {"REAL-1"}
    assert v.excluidas == []                                  # no son "no Zebra": solo se registran en el log
    assert "RISK_SERIES_EXCLUIDAS" in caplog.text and "DEMO-A" in caplog.text and "DEMO-B" in caplog.text
    assert "REAL-1" not in caplog.text


def test_series_excluidas_por_defecto_no_excluye_nada(db, monkeypatch):
    s = Sembrador(db)
    s.reporte(s.impresora("REAL-1"), date(2026, 6, 1))
    db.commit()
    monkeypatch.setattr(Q, "get_settings", lambda: settings_falsos())
    assert list(Q.construir_visitas(db, historico=VACIO).info) == ["REAL-1"]
    from app.config import Settings
    assert Settings.model_fields["risk_series_excluidas"].default == ""


# --------------------------------------------------------------------------- diagnostico: --paridad-hasta

def test_paridad_combinado_vs_csv(db, art):
    from app.risk import diagnostico
    V = historial_sintetico()
    sembrar_filas(db, V)
    hasta = date(2026, 6, 30)
    comb = Q.construir_visitas(db, historico=VACIO).df
    ok = diagnostico.comparar_paridad(art, comb, V, hasta)
    assert ok["comunes"] == V.numero_serie.nunique() and ok["difieren"] == 0 and ok["exactos"] == ok["comunes"]

    sn = "SN-TEST-003"
    idx = comb[(comb.numero_serie == sn) & (comb.fecha <= pd.Timestamp(hasta))].index[-1]
    comb2 = comb.copy()
    comb2.loc[idx, "contador_1"] = 9_999_999.0
    comb2.loc[idx, "cabezal"] = 1 - int(comb2.loc[idx, "cabezal"])
    r = diagnostico.comparar_paridad(art, comb2, V, hasta)
    assert r["difieren"] == 1 and r["exactos"] == r["comunes"] - 1
    d = next(e for e in r["equipos"] if e["clave"] == sn)
    assert {"contador", "checklist"} <= d["causas"] and d["x"]
    assert r["causas"]["contador"] == 1 and r["causas"]["checklist"] == 1

    recorte = diagnostico.comparar_paridad(art, comb.iloc[:0], V, hasta)      # un lado vacio: nadie en comun
    assert recorte["comunes"] == 0 and len(recorte["solo_csv"]) > 0


def test_main_imprime_el_bloque_de_paridad(db, art, tmp_path, monkeypatch, capsys):
    """Regresion: --paridad-hasta debe llegar al bloque desde main(), no solo funcionar en comparar_paridad()."""
    from app.risk import diagnostico
    V = historial_sintetico()
    csv = tmp_path / "historial.csv"
    escribir_csv(V[V.fecha < pd.Timestamp("2026-01-01")], csv)
    sembrar_filas(db, V[V.fecha >= pd.Timestamp("2026-01-01")])
    monkeypatch.setattr(Q, "get_settings", lambda: settings_falsos(risk_historico_path=str(csv)))
    monkeypatch.setattr("app.database.SessionLocal", lambda: db)
    monkeypatch.setattr(diagnostico, "verificar_base", lambda esperada: True)      # el guard tiene su propia prueba
    assert diagnostico.main(["--paridad-hasta", "2026-06-30"]) == 0
    salida = capsys.readouterr().out
    assert "=== Paridad real hasta 2026-06-30" in salida
    assert "Equipos en comun:" in salida and "Coinciden exactos:" in salida
    assert "=== Paridad" not in _salida_sin_paridad(diagnostico, capsys)


def _salida_sin_paridad(diagnostico, capsys) -> str:
    diagnostico.main([])
    return capsys.readouterr().out


def test_paridad_aborta_si_la_base_no_es_la_copia(db, monkeypatch, capsys):
    from app.risk import diagnostico
    monkeypatch.setattr("app.database.SessionLocal", lambda: db)
    assert diagnostico.main(["--paridad-hasta", "2026-10-06"]) == 2          # la base de pruebas no se llama servicios_copia
    salida = capsys.readouterr().out
    assert "Base de datos: host=" in salida and "ABORTADO" in salida and "servicios_copia" in salida


# --------------------------------------------------------------------------- loader del historial

def test_loader_sin_archivo_lanza_error_claro(tmp_path, monkeypatch):
    from app.risk import HistorialNoDisponible
    ruta = tmp_path / "no_existe.csv"
    monkeypatch.setattr(Q, "get_settings", lambda: settings_falsos(risk_historico_path=str(ruta)))
    with pytest.raises(HistorialNoDisponible) as e:
        Q.cargar_historico()
    assert "historial de visitas" in str(e.value) and "RISK_PERMITIR_SIN_HISTORICO" in str(e.value)
    assert str(tmp_path) not in str(e.value)                              # el mensaje no lleva rutas
    assert Q.estado_historico() == (False, 0)


def test_loader_permitir_sin_historico_avisa_en_el_log(tmp_path, monkeypatch, caplog):
    monkeypatch.setattr(Q, "get_settings", lambda: settings_falsos(
        risk_historico_path=str(tmp_path / "no_existe.csv"), risk_permitir_sin_historico=True))
    with caplog.at_level(logging.WARNING, logger="app.risk.queries"):
        h = Q.cargar_historico()
    assert len(h) == 0 and list(h.columns) == D.COLS and "SIN historial" in caplog.text


def test_loader_lee_la_ruta_configurada(tmp_path, monkeypatch):
    csv = tmp_path / "h.csv"
    escribir_csv(historial_sintetico(), csv)
    monkeypatch.setattr(Q, "get_settings", lambda: settings_falsos(risk_historico_path=str(csv)))
    n = len(historial_sintetico())
    assert len(Q.cargar_historico()) == n and Q.estado_historico() == (True, n)


# --------------------------------------------------------------------------- criterio de Aurora: dano en notas

def _flags(db, notes, cb=None, activar=True, monkeypatch=None):
    s = Sembrador(db)
    p = s.impresora("NOTAS-1")
    s.reporte(p, date(2026, 6, 1), cb=cb, notes=notes)
    db.commit()
    monkeypatch.setattr(Q, "get_settings", lambda: settings_falsos(risk_inferir_dano_en_notas=activar))
    f = Q.construir_visitas(db, historico=VACIO).df.iloc[0]
    return int(f.cabezal), int(f.rodillo), int(f.falla)


def test_notas_de_cambio_marcan_la_pieza_aunque_el_checkbox_no(db, monkeypatch):
    cb = {"Cabezal dañado": False, "Rodillo dañado": False}
    assert _flags(db, "-Se realiza cambio de cabezal de impresión -Impresora Ok", cb, monkeypatch=monkeypatch) == (1, 0, 1)


def test_notas_de_otra_pieza_o_limpieza_no_marcan(db, monkeypatch):
    assert _flags(db, "Limpieza de cabezal. Spindle de ribbon dañado", {}, monkeypatch=monkeypatch) == (0, 0, 0)


def test_inferencia_apagada_solo_usa_el_checklist(db, monkeypatch):
    assert _flags(db, "Se realiza cambio de cabezal", {}, activar=False, monkeypatch=monkeypatch) == (0, 0, 0)


def test_el_checkbox_sigue_mandando_si_las_notas_no_dicen_nada(db, monkeypatch):
    assert _flags(db, "Impresora Ok", {"Rodillo dañado": True}, monkeypatch=monkeypatch) == (0, 1, 1)


def test_clientes_excluidos_por_configuracion(db, monkeypatch, caplog):
    s = Sembrador(db)
    s.reporte(s.impresora("CLI-A"), date(2026, 6, 1))
    db.commit()
    s.client.name = "Cliente de Prueba Ñandú"
    db.commit()
    monkeypatch.setattr(Q, "get_settings", lambda: settings_falsos(risk_clientes_excluidos=" otro , cliente de prueba nandu "))
    with caplog.at_level(logging.INFO, logger="app.risk.queries"):
        v = Q.construir_visitas(db, historico=VACIO)
    assert v.info == {} and v.excluidas == []
    assert "RISK_CLIENTES_EXCLUIDOS" in caplog.text and "nandu" not in caplog.text.lower()   # el nombre no se escribe en el log


def test_clientes_excluidos_por_defecto_no_excluye_nada(db, monkeypatch):
    s = Sembrador(db)
    s.reporte(s.impresora("CLI-B"), date(2026, 6, 1))
    db.commit()
    monkeypatch.setattr(Q, "get_settings", lambda: settings_falsos())
    assert list(Q.construir_visitas(db, historico=VACIO).info) == ["CLI-B"]
    from app.config import Settings
    assert Settings.model_fields["risk_clientes_excluidos"].default == ""
    assert Settings.model_fields["risk_inferir_dano_en_notas"].default is True
