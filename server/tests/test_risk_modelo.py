"""Pruebas del modulo de riesgo vendorizado (app/risk). Se omiten si no hay numpy/pandas/scikit-learn."""
import datetime as dt
from pathlib import Path

import pytest

pytest.importorskip("numpy")
pytest.importorskip("pandas")
pytest.importorskip("sklearn")
pytest.importorskip("joblib")

import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402

from app.risk import ModeloNoDisponible  # noqa: E402
from app.risk import datos as D  # noqa: E402
from app.risk import modelo as M  # noqa: E402

RAIZ = Path(__file__).resolve().parents[2]
CSV = RAIZ / "modulo_riesgo" / "datos_ejemplo" / "base_visitas_min.csv"
JOBLIB = Path(__file__).resolve().parents[1] / "ml_models" / "modelo_riesgo.joblib"

pytestmark = pytest.mark.skipif(not (CSV.exists() and JOBLIB.exists()), reason="faltan el CSV de ejemplo o server/ml_models/modelo_riesgo.joblib (el .joblib no se versiona: copialo a mano o con scp)")


@pytest.fixture(scope="module")
def V():
    return D.cargar_visitas(CSV)


@pytest.fixture(scope="module")
def art():
    return M.cargar(JOBLIB)


def _ultima(V, sn, **cambios):
    """Copia de V donde la ultima visita de `sn` cambia las columnas dadas."""
    V2 = V.copy()
    idx = V2[V2.numero_serie == sn].index[-1]
    for k, v in cambios.items():
        V2.loc[idx, k] = v
    return V2


def test_variables_ultima_visita_sin_etiqueta(V):
    F = D.features_visitas(V)
    assert len(F) == len(V)
    assert F.groupby("numero_serie").n_visita.max().sum() == len(V)


def test_variables_coinciden_con_entrenamiento(V):
    T, X = D.conjunto_entrenamiento(V)
    F = D.features_visitas(V)
    k = ["numero_serie", "fecha_visita", "fila_origen_visita"]
    m = T[k].merge(F.reset_index()[k + ["index"]], on=k)
    assert len(m) == len(T)
    Xf = D.matriz_X(F).loc[m["index"].values].reset_index(drop=True)
    assert np.allclose(Xf.fillna(-9).values.astype(float), X.fillna(-9).values.astype(float))


def test_no_usa_el_futuro(V):
    sn = V.groupby("numero_serie").size().idxmax()
    V2 = V.drop(V[V.numero_serie == sn].index[-1])
    F1 = D.features_visitas(V)
    F2 = D.features_visitas(V2)
    a = D.matriz_X(F1[F1.numero_serie == sn]).iloc[:-1].fillna(-9).values.astype(float)
    b = D.matriz_X(F2[F2.numero_serie == sn]).fillna(-9).values.astype(float)
    assert np.allclose(a, b)


def test_prediccion_formato_y_rangos(art, V):
    R = M.predecir(art, V)
    assert len(R) == V.numero_serie.nunique()
    for r in R:
        assert isinstance(r["vigente"], bool)
        for pz in ("cabezal", "rodillo"):
            assert r[pz]["nivel"] in ("ALTO", "MEDIO", "BAJO") and 0 <= r[pz]["indice_riesgo"] <= 100


def test_equipo_nuevo_con_una_visita(art, V):
    V1 = pd.concat([V, V.iloc[[0]].assign(numero_serie="NUEVO-001", fila_origen=9999)], ignore_index=True)
    r = [x for x in M.predecir(art, V1) if x["numero_serie"] == "NUEVO-001"][0]
    assert r["historial_corto"] is True and r["visitas_registradas"] == 1


def test_informacion_del_artefacto(art):
    info = M.informacion(art)
    assert info["horizonte_dias"] == 90 and set(info["piezas"]) == {"cabezal", "rodillo"}
    assert info["version"] == art["version"] and "aviso" in info


def test_nan_en_cabezal_y_rodillo_de_la_ultima_visita(art, V):
    sn = V.numero_serie.iloc[0]
    V2 = _ultima(V, sn, cabezal=np.nan, rodillo=np.nan)
    r = [x for x in M.predecir(art, V2) if x["numero_serie"] == sn][0]
    assert r["cabezal"]["danada_en_ultima_visita"] is False and r["rodillo"]["danada_en_ultima_visita"] is False
    assert r["cabezal"]["danos_previos"] >= 0 and r["rodillo"]["danos_previos"] >= 0


def test_banderas_no_numericas_cuentan_como_cero(V):
    sn = V.numero_serie.iloc[0]
    V2 = V.astype({"mantenimiento": object, "sensor_ribbon": object, "falla": object})
    V2 = _ultima(V2, sn, mantenimiento="si?", sensor_ribbon=None, falla="x")
    P = D.preparar_visitas(V2)
    u = P[P.numero_serie == sn].iloc[-1]
    assert (u.mantenimiento, u.sensor_ribbon, u.falla) == (0, 0, 0)
    assert P.cabezal.dtype.kind == "i" and P.contador_1.dtype.kind == "f"


def test_contador_no_numerico_es_nan(V):
    V2 = V.astype({"contador_1": object})
    V2.loc[V2.index[-1], "contador_1"] = "n/d"
    previos = D.preparar_visitas(V).contador_1.isna().sum() + int(pd.notna(V.contador_1.iloc[-1]))
    assert D.preparar_visitas(V2).contador_1.isna().sum() == previos


def test_faltan_columnas(V):
    with pytest.raises(ValueError, match="Faltan columnas"):
        D.preparar_visitas(V.drop(columns=["cabezal", "fecha"]))


def test_dataframe_vacio(art, V):
    assert M.predecir(art, V.iloc[0:0]) == []


@pytest.mark.parametrize("variante", ["correctivo", " Correctivo ", "CORRECTIVO", "Correctívo"])
def test_tipo_servicio_correctivo_equivale_al_canonico(art, V, variante):
    sn = V[V.tipo_servicio.map(D.normalizar_tipo_servicio) == "Preventivo"].numero_serie.iloc[0]
    canon = M.predecir(art, _ultima(V, sn, tipo_servicio="Correctivo"))
    assert D.normalizar_tipo_servicio(variante) == "Correctivo"
    assert M.predecir(art, _ultima(V, sn, tipo_servicio=variante)) == canon
    F = D.features_visitas(D.preparar_visitas(_ultima(V, sn, tipo_servicio=variante)))
    assert D.matriz_X(F).correctivo.sum() == D.matriz_X(D.features_visitas(D.preparar_visitas(_ultima(V, sn, tipo_servicio="Correctivo")))).correctivo.sum()


@pytest.mark.parametrize("variante", ["Diagnostico", "Diagn�stico", "DIAGNÓSTICO", " diagnóstico "])
def test_tipo_servicio_diagnostico(art, V, variante):
    assert D.normalizar_tipo_servicio(variante) == "Diagnóstico"
    sn = V.numero_serie.iloc[0]
    assert M.predecir(art, _ultima(V, sn, tipo_servicio=variante)) == M.predecir(art, _ultima(V, sn, tipo_servicio="Diagnóstico"))


def test_normalizar_tipo_servicio_otros():
    assert D.normalizar_tipo_servicio("Instalacion") == "Instalación"
    assert D.normalizar_tipo_servicio("preventivo ") == "Preventivo"
    assert D.normalizar_tipo_servicio(None) == ""
    assert D.normalizar_tipo_servicio(float("nan")) == ""
    assert D.normalizar_tipo_servicio(" Otro ") == "Otro"


def test_fam_opera_en_mayusculas():
    assert D.fam("zt610-300dpi") == D.fam("ZT610-300dpi") == "ZT6xx"
    assert D.fam(" 220xi4-203dpi ") == "Xi"
    assert D.fam("GC420t-203dpi") == "otros"


def test_vigente_true_y_false(art, V):
    R = M.predecir(art, V, hoy=dt.date(2000, 1, 1))
    assert R and all(r["vigente"] is True for r in R)
    R = M.predecir(art, V, hoy=dt.date(2100, 1, 1))
    assert all(r["vigente"] is False for r in R)
    r = R[0]
    limite = dt.date.fromisoformat(r["vigente_hasta"])
    assert M.predecir(art, V, hoy=limite)[0]["vigente"] is True
    assert M.predecir(art, V, hoy=limite + dt.timedelta(days=1))[0]["vigente"] is False


def test_vigente_por_defecto_usa_hoy(art, V):
    assert [r["vigente"] for r in M.predecir(art, V)] == [r["vigente"] for r in M.predecir(art, V, hoy=dt.date.today())]


def test_artefacto_cargado_con_n_jobs_1(art, V):
    for p in art["piezas"].values():
        assert all(m.n_jobs == 1 for m in p["modelos"])
    assert M.predecir(art, V)


def test_cargar_sin_archivo(tmp_path):
    with pytest.raises(ModeloNoDisponible) as e:
        M.cargar(tmp_path / "no_existe.joblib")
    assert isinstance(e.value.__cause__, FileNotFoundError)


def test_cargar_archivo_corrupto(tmp_path):
    malo = tmp_path / "malo.joblib"
    malo.write_bytes(b"esto no es un joblib")
    with pytest.raises(ModeloNoDisponible) as e:
        M.cargar(malo)
    assert e.value.__cause__ is not None


def test_cargar_estructura_inesperada(tmp_path):
    import joblib
    raro = tmp_path / "raro.joblib"
    joblib.dump({"otra": 1}, raro)
    with pytest.raises(ModeloNoDisponible):
        M.cargar(raro)
