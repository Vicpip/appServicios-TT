"""Diagnostico de solo lectura del modulo de riesgo.   python -m app.risk.diagnostico [--ejemplo RUTA] [--ventana-dias N]

Por impresora: visitas de la app, del CSV historico y combinadas; equipos con filas del CSV cerca del primer reporte de la
app (posible duplicado, para revision manual); cuantos tienen historial corto; distribucion de niveles por pieza; y una
comparacion informativa con modulo_riesgo/ejemplo_respuesta.json (las fechas de corte difieren). No escribe nada.

Con --paridad-hasta YYYY-MM-DD compara, recortando a esa fecha, las visitas combinadas (app + CSV) contra el CSV solo
(el de Aurora). Exige que la base se llame --base-esperada (servicios_copia) y solo imprime en consola.
"""
import argparse
import json
import logging
import sys
from collections import Counter
from datetime import timedelta
from pathlib import Path

from app.risk import HistorialNoDisponible, ModeloNoDisponible, queries, service

RAIZ = Path(__file__).resolve().parents[3]
EJEMPLO_DEFECTO = RAIZ / "modulo_riesgo" / "ejemplo_respuesta.json"


def posibles_duplicados(visitas, historico, ventana_dias: int = 3) -> list[tuple[str, str, list[str]]]:
    """(serie, primer reporte de la app, fechas del CSV a +-ventana_dias de ese reporte)."""
    claves = historico.numero_serie.map(queries._clave_serie)
    salida = []
    for clave, i in visitas.info.items():
        if i.corte is None:
            continue
        cerca = historico[(claves == clave)
                          & (historico.fecha.dt.date >= i.corte - timedelta(days=ventana_dias))
                          & (historico.fecha.dt.date <= i.corte + timedelta(days=ventana_dias))]
        if len(cerca):
            salida.append((i.numero_serie, str(i.corte), [str(f.date()) for f in cerca.fecha]))
    return salida


def comparar_con_ejemplo(equipos: list[dict], ruta: Path) -> dict:
    """Compara nivel e indice contra el JSON de Aurora para los equipos en comun. Solo informativo."""
    esperado = {e["numero_serie"]: e for e in json.loads(ruta.read_text(encoding="utf-8"))["equipos"]}
    comunes = [e for e in equipos if e["numero_serie"] in esperado]
    dif = {"en_comun": len(comunes), "nivel_distinto": {"cabezal": 0, "rodillo": 0}, "detalle": []}
    for e in comunes:
        ref = esperado[e["numero_serie"]]
        for pz in ("cabezal", "rodillo"):
            if e[pz]["nivel"] != ref[pz]["nivel"]:
                dif["nivel_distinto"][pz] += 1
                dif["detalle"].append((e["numero_serie"], pz, ref[pz]["nivel"], e[pz]["nivel"],
                                       ref[pz]["indice_riesgo"], e[pz]["indice_riesgo"]))
    return dif

GRUPOS_CAUSA = {
    "checklist": ("mantenimiento", "calibracion", "rodillo", "cabezal", "sensor_ribbon", "sensor_papel", "falla"),
    "contador": ("contador_1",), "tipo_servicio": ("tipo_servicio",), "fecha": ("fecha",), "modelo": ("modelo",),
}

_COL_FEATURE = {"fecha": "fecha_visita", "contador_1": "contador_visita", "falla": "falla_visita_actual"}   # nombre en features_visitas


def _ultimas(V):
    """Features y matriz_X de la ULTIMA visita de cada equipo, indexadas por clave de serie."""
    from app.risk import datos as D
    V = D.preparar_visitas(V)
    F = D.features_visitas(V)
    ult = F.groupby("numero_serie", sort=False).tail(1).reset_index(drop=True)
    X = D.matriz_X(ult)
    claves = ult.numero_serie.map(queries._clave_serie)
    return ult.set_index(claves), X.set_index(claves), V


def _iguales(a, b) -> bool:
    import pandas as pd
    if pd.isna(a) and pd.isna(b):
        return True
    if pd.isna(a) or pd.isna(b):
        return False
    try:
        return abs(float(a) - float(b)) < 1e-9
    except (TypeError, ValueError):
        return a == b


def _historia(V, clave: str):
    """Tuplas (fecha, contador, tipo, modelo, checklist) de las visitas de un equipo, en orden."""
    g = V[V.numero_serie.map(queries._clave_serie) == clave]
    cols = ["fecha", "contador_1", "tipo_servicio", "modelo", *GRUPOS_CAUSA["checklist"]]
    return [tuple(r) for r in g[cols].itertuples(index=False, name=None)]


def comparar_paridad(art, combinado, referencia, hasta) -> dict:
    """Combinado (app + CSV) vs CSV solo, ambos recortados a fecha <= hasta, para los equipos en comun."""
    import pandas as pd
    from app.risk import modelo as M
    corte = pd.Timestamp(hasta)
    A = combinado[combinado.fecha <= corte]
    B = referencia[referencia.fecha <= corte]
    pa = {queries._clave_serie(e["numero_serie"]): e for e in M.predecir(art, A, hoy=hasta)}
    pb = {queries._clave_serie(e["numero_serie"]): e for e in M.predecir(art, B, hoy=hasta)}
    ua, xa, VA = _ultimas(A) if len(A) else (None, None, A)
    ub, xb, VB = _ultimas(B) if len(B) else (None, None, B)
    comunes = sorted(set(pa) & set(pb))
    res = {"solo_combinado": sorted(set(pa) - set(pb)), "solo_csv": sorted(set(pb) - set(pa)),
           "comunes": len(comunes), "exactos": 0, "difieren": 0, "equipos": [], "causas": Counter()}
    for k in comunes:
        d = {"clave": k, "visitas": (int(ua.loc[k, "n_visita"]), int(ub.loc[k, "n_visita"])), "x": [], "piezas": [], "causas": set()}
        for c in xa.columns:
            if not _iguales(xa.loc[k, c], xb.loc[k, c]):
                d["x"].append((c, xa.loc[k, c], xb.loc[k, c]))
        for pz in ("cabezal", "rodillo"):
            a, b = pa[k][pz], pb[k][pz]
            if a["nivel"] != b["nivel"] or a["indice_riesgo"] != b["indice_riesgo"]:
                d["piezas"].append((pz, b["nivel"], b["indice_riesgo"], a["nivel"], a["indice_riesgo"]))
        for causa, cols in GRUPOS_CAUSA.items():
            if any(not _iguales(ua.loc[k, _COL_FEATURE.get(c, c)], ub.loc[k, _COL_FEATURE.get(c, c)]) for c in cols):
                d["causas"].add(causa)
        if d["visitas"][0] != d["visitas"][1]:
            d["causas"].add("n_visitas")
        if d["x"] or d["piezas"]:
            if _historia(VA, k)[:-1] != _historia(VB, k)[:-1] and d["visitas"][0] == d["visitas"][1]:
                d["causas"].add("historial_previo")
            res["difieren"] += 1
            res["causas"].update(d["causas"] or {"sin_causa_identificada"})
        else:
            res["exactos"] += 1
        res["equipos"].append(d)
    return res


def imprimir_paridad(res: dict, hasta) -> None:
    print(f"\n=== Paridad real hasta {hasta}: combinado (app + CSV) vs CSV de Aurora ===")
    print(f"Equipos en comun: {res['comunes']} | solo en combinado: {len(res['solo_combinado'])} | solo en CSV: {len(res['solo_csv'])}")
    for k in res["solo_combinado"]:
        print(f"  solo combinado: {k}")
    for k in res["solo_csv"]:
        print(f"  solo CSV: {k}")
    for d in res["equipos"]:
        estado = "difiere" if (d["x"] or d["piezas"]) else "exacto"
        print(f"\n{d['clave']}: visitas combinado={d['visitas'][0]} csv={d['visitas'][1]} -> {estado}"
              + (f" | causas: {', '.join(sorted(d['causas']))}" if d["causas"] else ""))
        for c, a, b in d["x"]:
            print(f"    matriz_X.{c}: combinado={a} csv={b}")
        for pz, nb, ib, na, ia in d["piezas"]:
            print(f"    {pz}: csv {nb} ({ib}) -> combinado {na} ({ia})")
    print(f"\nCoinciden exactos: {res['exactos']} | difieren: {res['difieren']} (de {res['comunes']} en comun)")
    if res["causas"]:
        print("Variables que explican las diferencias (equipos afectados):")
        for causa, n in res["causas"].most_common():
            print(f"  {causa}: {n}")


def verificar_base(esperada: str) -> bool:
    """Imprime host y nombre de la base; False si el nombre no es el esperado (la corrida debe abortar)."""
    from app.database import engine
    print(f"Base de datos: host={engine.url.host} nombre={engine.url.database}")
    if engine.url.database != esperada:
        print(f"ABORTADO: la base no es '{esperada}'. Apunta DATABASE_URL a la copia local.")
        return False
    return True


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Diagnostico de solo lectura del modulo de riesgo")
    ap.add_argument("--ejemplo", default=str(EJEMPLO_DEFECTO), help="JSON de referencia de Aurora")
    ap.add_argument("--ventana-dias", type=int, default=3, help="ventana para marcar posibles duplicados (default 3)")
    ap.add_argument("--paridad-hasta", metavar="YYYY-MM-DD",
                    help="compara visitas combinadas (app + CSV) contra el CSV solo, recortados a esa fecha")
    ap.add_argument("--base-esperada", default="servicios_copia", help="nombre de la base exigido con --paridad-hasta")
    args = ap.parse_args(argv)
    logging.basicConfig(level=logging.WARNING)
    hasta = None
    if args.paridad_hasta:
        from datetime import date
        hasta = date.fromisoformat(args.paridad_hasta)
        if not verificar_base(args.base_esperada):
            return 2
    from app.database import SessionLocal
    db = SessionLocal()
    try:
        try:
            hist = queries.cargar_historico()
        except HistorialNoDisponible as e:
            print(e)
            return 1
        visitas = queries.construir_visitas(db, historico=hist)
        print(f"Impresoras activas Zebra: {len(visitas.info)} | no Zebra excluidas: {len(visitas.excluidas)} | "
              f"sin visitas: {len(visitas.sin_datos)} | filas del CSV historico: {len(hist)}")
        for serie, modelo in visitas.excluidas:
            print(f"  excluida: {serie} ({modelo})")

        print("\nVisitas por impresora (app / CSV / combinadas):")
        for i in sorted(visitas.info.values(), key=lambda x: x.numero_serie):
            print(f"  {i.numero_serie:<18} {i.modelo:<18} app={i.visitas_app:<3} csv={i.visitas_historicas:<3} "
                  f"total={i.visitas_app + i.visitas_historicas}")

        dups = posibles_duplicados(visitas, hist, args.ventana_dias)
        print(f"\nPosibles duplicados (filas del CSV a +-{args.ventana_dias} dias del primer reporte de la app): {len(dups)}")
        for serie, corte, fechas in dups:
            print(f"  {serie}: primer reporte app {corte}; CSV {', '.join(fechas)}")

        try:
            res = service.calcular(db, historico=hist)
        except ModeloNoDisponible as e:
            print(f"\nSin modelo: no se calculan niveles ni comparacion ({e})")
            return 0
        cortos = sum(1 for e in res.equipos if e["historial_corto"])
        print(f"\nEquipos puntuados: {len(res.equipos)} | historial_corto (<3 visitas): {cortos} | "
              f"estimacion vencida: {sum(1 for e in res.equipos if not e['vigente'])} | modelo {res.version_modelo}")
        for pz in ("cabezal", "rodillo"):
            c = Counter(e[pz]["nivel"] for e in res.equipos)
            print(f"  {pz}: ALTO={c['ALTO']} MEDIO={c['MEDIO']} BAJO={c['BAJO']}")

        ruta = Path(args.ejemplo)
        if ruta.exists():
            d = comparar_con_ejemplo(res.equipos, ruta)
            print(f"\nComparacion informativa con {ruta.name} ({d['en_comun']} equipos en comun; las fechas de corte difieren):")
            print(f"  nivel distinto: cabezal={d['nivel_distinto']['cabezal']} rodillo={d['nivel_distinto']['rodillo']}")
            for serie, pz, ref, hoy, i_ref, i_hoy in d["detalle"]:
                print(f"  {serie} {pz}: Aurora {ref} ({i_ref}) -> ahora {hoy} ({i_hoy})")
        else:
            print(f"\nNo se encontro {ruta}: se omite la comparacion")
        if hasta is not None:
            imprimir_paridad(comparar_paridad(service.cargar_artefacto(), visitas.df, hist, hasta), hasta)
        return 0
    finally:
        db.close()


if __name__ == "__main__":
    sys.exit(main())
