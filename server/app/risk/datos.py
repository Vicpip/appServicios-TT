"""Datos: lectura de visitas, variables por visita, etiquetas a 90 dias y matriz de entrada del modelo.
La logica de variables es la misma que se uso en la evaluacion del capitulo 5."""
import re
import unicodedata

import numpy as np
import pandas as pd

COLS = ['numero_serie', 'fila_origen', 'fecha', 'modelo', 'tipo_servicio', 'contador_1', 'mantenimiento',
        'calibracion', 'rodillo', 'cabezal', 'sensor_ribbon', 'sensor_papel', 'falla']
COLS_BINARIAS = ['mantenimiento', 'calibracion', 'rodillo', 'cabezal', 'sensor_ribbon', 'sensor_papel', 'falla']
HORIZONTE_DIAS = 90

# Prefijo (sin acentos, en minusculas) -> etiqueta canonica. Por prefijo porque el CSV de Aurora trae
# "Diagn�stico" (caracter de reemplazo U+FFFD) en lugar de "Diagnóstico".
_TIPOS_SERVICIO = (('preventiv', 'Preventivo'), ('correctiv', 'Correctivo'),
                   ('diagn', 'Diagnóstico'), ('instal', 'Instalación'))


def normalizar_tipo_servicio(valor):
    """strip + casefold + sin acentos; reconoce variantes por prefijo. Lo desconocido se devuelve limpio (strip)."""
    if valor is None or (isinstance(valor, float) and np.isnan(valor)):
        return ''
    texto = str(valor).strip()
    base = unicodedata.normalize('NFKD', texto.casefold())
    base = ''.join(c for c in base if not unicodedata.combining(c))
    for prefijo, canonico in _TIPOS_SERVICIO:
        if base.startswith(prefijo):
            return canonico
    return texto


def fam(m):
    m = str(m).strip().upper()
    if re.match(r'ZT4(10|11|20|21)', m): return 'ZT41x_42x'
    if m.startswith('ZT510'): return 'ZT510'
    if re.match(r'ZT6(10|20)', m): return 'ZT6xx'
    if re.match(r'(110|140|220)X', m): return 'Xi'
    return 'otros'

FAMILIAS = ['ZT41x_42x', 'ZT510', 'ZT6xx', 'Xi', 'otros']

def validar_visitas(V):
    faltan = [c for c in COLS if c not in V.columns]
    if faltan:
        raise ValueError(f'Faltan columnas en las visitas: {faltan}')
    return V

def preparar_visitas(V):
    """Normaliza tipos y orden. V debe traer las columnas de COLS (una fila por visita).
    Las banderas 0/1 faltantes o no numericas cuentan como 0; contador_1 es numerico y admite NaN."""
    V = validar_visitas(V)[COLS].copy()
    V['numero_serie'] = V.numero_serie.astype(str)
    V['fecha'] = pd.to_datetime(V.fecha)
    V['fila_origen'] = pd.to_numeric(V.fila_origen, errors='coerce').fillna(0).astype(int)
    for c in COLS_BINARIAS:
        V[c] = pd.to_numeric(V[c], errors='coerce').fillna(0).astype(int)
    V['contador_1'] = pd.to_numeric(V.contador_1, errors='coerce').astype(float)
    V['tipo_servicio'] = V.tipo_servicio.map(normalizar_tipo_servicio)
    return V.sort_values(['numero_serie', 'fecha', 'fila_origen']).reset_index(drop=True)

def cargar_visitas(ruta):
    V = pd.read_excel(ruta, sheet_name='base_visitas') if str(ruta).lower().endswith(('.xlsx', '.xls')) else pd.read_csv(ruta, dtype={'numero_serie': str})
    return preparar_visitas(V)

def features_visitas(V):
    """Variables de CADA visita usando solo informacion hasta esa visita (no necesita visita siguiente)."""
    b = V.copy()
    b['familia_modelo'] = b.modelo.map(fam)
    g = b.groupby('numero_serie')
    b['n_visita'] = g.cumcount() + 1
    b['dias_desde_visita_previa'] = g.fecha.diff().dt.days
    inc = b.contador_1 - g.contador_1.shift(1)
    b['incremento_contador'] = inc.where(inc >= 0)
    b['pulgadas_por_dia'] = b.incremento_contador / b.dias_desde_visita_previa.where(b.dias_desde_visita_previa > 0)
    b['fallas_previas_acum'] = g.falla.cumsum() - b.falla
    b['falla_visita_previa'] = g.falla.shift(1)
    b = b.rename(columns={'fecha': 'fecha_visita', 'fila_origen': 'fila_origen_visita', 'falla': 'falla_visita_actual', 'contador_1': 'contador_visita'})
    b['sensores'] = ((b.sensor_ribbon + b.sensor_papel) > 0).astype(int)
    b = b.sort_values(['numero_serie', 'fecha_visita', 'fila_origen_visita']).reset_index(drop=True)
    for c in ['rodillo', 'cabezal', 'sensores']:
        b['acum_' + c] = b.groupby('numero_serie')[c].cumsum()
    return b

def etiquetas_90d(V, dias=HORIZONTE_DIAS):
    lab = []
    for sn, g in V.groupby('numero_serie'):
        g = g.reset_index(drop=True)
        for i in range(len(g) - 1):
            w = g.iloc[i + 1:]
            w = w[(w.fecha - g.fecha[i]).dt.days <= dias]
            if len(w):
                lab.append((sn, g.fecha[i], int(g.fila_origen[i]), int(w.cabezal.max()), int(w.rodillo.max())))
    return pd.DataFrame(lab, columns=['numero_serie', 'fecha_visita', 'fila_origen_visita', 'y_cabezal90', 'y_rodillo90'])

def matriz_X(F):
    X = pd.DataFrame({
        'log_contador': np.log1p(F.contador_visita), 'log_pulg_dia': np.log1p(F.pulgadas_por_dia),
        'log_dias_previa': np.log1p(F.dias_desde_visita_previa),
        'n_visita': F.n_visita, 'fallas_previas_acum': F.fallas_previas_acum,
        'falla_visita_previa': F.falla_visita_previa, 'falla_visita_actual': F.falla_visita_actual,
        'rodillo': F.rodillo, 'cabezal': F.cabezal, 'sensores': F.sensores,
        'mantenimiento': F.mantenimiento, 'calibracion': F.calibracion,
        'correctivo': (F.tipo_servicio.map(normalizar_tipo_servicio) == 'Correctivo').astype(int),
        'acum_rodillo': F.acum_rodillo, 'acum_cabezal': F.acum_cabezal, 'acum_sensores': F.acum_sensores})
    for f in FAMILIAS:                      # columnas fijas: no depende de que la entrada traiga todas las familias
        X['fam_' + f] = (F.familia_modelo == f).astype(int)
    for c in ['log_contador', 'log_pulg_dia', 'log_dias_previa', 'falla_visita_previa']:
        X[c + '_na'] = X[c].isna().astype(int)
    return X

def conjunto_entrenamiento(V):
    """Visitas con etiqueta a 90 dias conocida (tienen al menos una revisita en la ventana)."""
    F = features_visitas(V)
    L = etiquetas_90d(V)
    T = F.merge(L, on=['numero_serie', 'fecha_visita', 'fila_origen_visita'], how='inner').reset_index(drop=True)
    return T, matriz_X(T)
