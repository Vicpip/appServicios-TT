"""Entrenamiento, registro, y prediccion de riesgo a 90 dias por pieza (cabezal y rodillo)."""
import json, hashlib, datetime as dt
import numpy as np
import pandas as pd
import joblib
from . import ModeloNoDisponible
from . import datos as D

PIEZAS = {'cabezal': 'y_cabezal90', 'rodillo': 'y_rodillo90'}
# Semillas del ensamble final. Los umbrales ALTO/MEDIO se calculan con los puntajes fuera de muestra de
# oof_scores(), que usa solo las 2 primeras semillas (_ajustar(...)[:2]) por velocidad, mientras que el
# modelo final usa las 5. Esa diferencia se midio: el ALTO real queda en 28.9 % (cabezal) y 32.7 % (rodillo)
# frente al 30 % objetivo, con correlacion de rangos 0.999. Es despreciable y NO se cambia (cambiarlo
# obligaria a reentrenar y a rehacer las metricas del TT). Ver ml_models/MODEL_CARD.md.
SEMILLAS = 5
NIVEL_ALTO_PCT = 70      # puntaje en el 30 % mas alto de lo observado fuera de muestra -> ALTO (el 30 % evaluado en el capitulo 5)
NIVEL_MEDIO_PCT = 50     # siguiente 20 % -> MEDIO; el resto -> BAJO
AVISO = ('Estimacion estadistica del riesgo de que la pieza aparezca danada en alguna visita de los proximos 90 dias. '
         'No es una fecha de falla ni una garantia. Basada en pocos equipos; el desempeno mejora al acumular reportes.')

def crear_rf(semilla, n_jobs=-1):
    from sklearn.ensemble import RandomForestClassifier
    return RandomForestClassifier(n_estimators=300, max_depth=4, min_samples_leaf=5, max_features='sqrt',
                                  class_weight='balanced_subsample', random_state=semilla, n_jobs=n_jobs)

def _ajustar(X, y, med):
    return [crear_rf(s).fit(X.fillna(med), y) for s in range(SEMILLAS)]

def _puntuar(modelos, X, med):
    return np.mean([m.predict_proba(X.fillna(med))[:, 1] for m in modelos], axis=0)

def oof_scores(X, y, grp, nrep=3):
    """Puntajes fuera de muestra (validacion agrupada por equipo), promediados entre repeticiones."""
    from sklearn.model_selection import StratifiedGroupKFold
    from sklearn.metrics import average_precision_score
    S = np.zeros((nrep, len(y)))
    for rep in range(nrep):
        for tr, te in StratifiedGroupKFold(5, shuffle=True, random_state=rep).split(X, y, grp):
            med = X.iloc[tr].median()
            S[rep, te] = _puntuar(_ajustar(X.iloc[tr], y[tr], med)[:2], X.iloc[te], med)
    pr = float(np.mean([average_precision_score(y, s) for s in S]))
    return S.mean(axis=0), pr

def entrenar(V):
    """Entrena un modelo por pieza con toda la base. Devuelve el artefacto (dict) listo para guardar.
    `metricas_referencia` se calcula con los datos de esta corrida (no hay cifras escritas a mano)."""
    T, X = D.conjunto_entrenamiento(V)
    grp = T.numero_serie.values
    n_equipos, n_visitas = int(V.numero_serie.nunique()), int(len(V))
    art = {'piezas': {}, 'columnas': list(X.columns), 'horizonte_dias': D.HORIZONTE_DIAS, 'aviso': AVISO,
           'entrenado_en': dt.datetime.now().isoformat(timespec='seconds'),
           'n_visitas_base': n_visitas, 'n_equipos_base': n_equipos,
           'n_filas_entrenamiento': int(len(T)), 'n_equipos_entrenamiento': int(T.numero_serie.nunique()),
           'ultima_visita_en_base': str(V.fecha.max().date())}
    for pz, col in PIEZAS.items():
        y = T[col].astype(int).values
        med = X.median()
        oof, pr = oof_scores(X, y, grp)
        art['piezas'][pz] = dict(modelos=_ajustar(X, y, med), medianas=med, oof_ordenado=np.sort(oof),
                                 umbral_alto=float(np.percentile(oof, NIVEL_ALTO_PCT)), umbral_medio=float(np.percentile(oof, NIVEL_MEDIO_PCT)),
                                 positivos=int(y.sum()), tasa_base=float(y.mean()), pr_auc_validacion=pr)
    art['metricas_referencia'] = {
        'evaluacion': 'Validacion agrupada por equipo (5 particiones x 3 repeticiones) de esta corrida de entrenamiento',
        'n_equipos': n_equipos, 'n_visitas': n_visitas,
        **{f'{pz}_90d': {'pr_auc_validacion': round(p['pr_auc_validacion'], 3), 'tasa_base': round(p['tasa_base'], 3),
                         'positivos': p['positivos']} for pz, p in art['piezas'].items()},
        'limitaciones': ['Solo visitas con revisita dentro de 90 dias (sesgo de seleccion)',
                         'Rodillo: evidencia debil; tratar como en monitoreo',
                         'Pocos equipos; intervalos amplios'],
    }
    art['version'] = hashlib.sha1((art['entrenado_en'] + str(art['n_filas_entrenamiento'])).encode()).hexdigest()[:8]
    return art

def guardar(art, ruta):
    joblib.dump(art, ruta)

def cargar(ruta):
    """Carga el artefacto. Lanza ModeloNoDisponible (con la causa) si falta el archivo o joblib/sklearn fallan."""
    try:
        art = joblib.load(ruta)
        for p in art['piezas'].values():
            for m in p['modelos']:
                m.n_jobs = 1                # un solo proceso en la VPS: nada de hilos extra al predecir
    except FileNotFoundError as e:
        raise ModeloNoDisponible(f'No existe el archivo del modelo: {ruta}') from e
    except Exception as e:                  # version de sklearn distinta, archivo corrupto, estructura inesperada
        raise ModeloNoDisponible(f'No se pudo cargar el modelo {ruta}: {e}') from e
    return art

def _nivel(score, p):
    return 'ALTO' if score >= p['umbral_alto'] else ('MEDIO' if score >= p['umbral_medio'] else 'BAJO')

def _a_fecha(hoy):
    if hoy is None:
        return dt.date.today()
    return pd.Timestamp(hoy).date()

def predecir(art, V, hoy=None, con_entradas=False):
    """Riesgo a 90 dias de la ULTIMA visita de cada equipo. V = visitas (columnas de datos.COLS).
    `hoy` (fecha, opcional) fija la fecha de referencia de `vigente`; por defecto la fecha actual.
    `con_entradas=True` agrega a cada equipo `entradas`: las variables NUMERICAS que vio el modelo en la ultima visita
    (nunca texto: ni notas ni serie); sirve para auditar el calculo guardado."""
    V = D.preparar_visitas(V)
    if V.empty:
        return []
    hoy = _a_fecha(hoy)
    F = D.features_visitas(V)
    ult = F.groupby('numero_serie', sort=False).tail(1).reset_index(drop=True)
    X = D.matriz_X(ult)[art['columnas']]
    filas = []
    sc = {pz: _puntuar(p['modelos'], X, p['medianas']) for pz, p in art['piezas'].items()}
    for i, r in ult.iterrows():
        hasta = (r.fecha_visita + pd.Timedelta(days=art['horizonte_dias'])).date()
        d = dict(numero_serie=r.numero_serie, modelo_impresora=r.modelo, fecha_ultima_visita=str(r.fecha_visita.date()),
                 vigente_hasta=str(hasta), vigente=bool(hoy <= hasta),
                 visitas_registradas=int(r.n_visita), historial_corto=bool(r.n_visita < 3))
        if con_entradas:
            d['entradas'] = {c: (None if pd.isna(v) else float(v)) for c, v in X.iloc[i].items()}
        for pz, p in art['piezas'].items():
            s = float(sc[pz][i])
            pct = float(np.searchsorted(p['oof_ordenado'], s, side='right') / len(p['oof_ordenado']) * 100)
            d[pz] = dict(nivel=_nivel(s, p), indice_riesgo=round(pct, 1), danada_en_ultima_visita=bool(r[pz] == 1),
                         danos_previos=int(r['acum_' + pz] - (1 if r[pz] == 1 else 0)))
        filas.append(d)
    return filas

def informacion(art):
    p = art['piezas']
    return dict(version=art['version'], entrenado_en=art['entrenado_en'], horizonte_dias=art['horizonte_dias'],
                n_visitas_base=art['n_visitas_base'], n_equipos_base=art['n_equipos_base'],
                n_filas_entrenamiento=art['n_filas_entrenamiento'], n_equipos_entrenamiento=art['n_equipos_entrenamiento'],
                ultima_visita_en_base=art['ultima_visita_en_base'],
                niveles={'ALTO': f'puntaje en el {100-NIVEL_ALTO_PCT} % mas alto observado en validacion',
                         'MEDIO': f'siguiente {NIVEL_ALTO_PCT-NIVEL_MEDIO_PCT} %', 'BAJO': f'resto ({NIVEL_MEDIO_PCT} %)'},
                piezas={k: dict(positivos_entrenamiento=v['positivos'], tasa_base=round(v['tasa_base'], 3),
                                pr_auc_validacion=round(v['pr_auc_validacion'], 3)) for k, v in p.items()},
                metricas_referencia=art['metricas_referencia'], aviso=art['aviso'])
