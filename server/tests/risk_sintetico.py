"""Historial de visitas SINTETICO para las pruebas del modulo de riesgo.

Todo es inventado (seriales SN-TEST-001..., fechas y banderas al azar con semilla fija): el repo es publico y el
historial real de clientes no se versiona. numpy/pandas se importan dentro de las funciones: importar este modulo no los exige.
"""
from datetime import date, timedelta
from types import SimpleNamespace


MODELOS = ("ZT411-300dpi", "110XI4-203dpi", "ZT610-300dpi", "ZT510-203dpi", "ZE500-300dpi")
TIPOS = ("Preventivo", "Preventivo", "Preventivo", "Correctivo", "Diagnóstico", "Diagn�stico")


def historial_sintetico(n_equipos: int = 14, semilla: int = 7):
    """Visitas inventadas con las columnas de datos.COLS. Los dos ultimos equipos terminan en 2024 (solo historial)."""
    import numpy as np
    import pandas as pd
    from app.risk import datos as D
    rng = np.random.default_rng(semilla)
    filas = []
    for k in range(1, n_equipos + 1):
        serie = f"SN-TEST-{k:03d}"
        modelo = MODELOS[k % len(MODELOS)]
        dia = date(2023, 6, 1) + timedelta(days=int(rng.integers(0, 60)))
        fin = date(2024, 6, 30) if k > n_equipos - 2 else date(2026, 9, 30)
        contador = int(rng.integers(1_000, 50_000))
        fila_origen = 0
        while dia < fin:
            fila_origen += 1
            contador += int(rng.integers(500, 20_000))
            cab, rod, sr, sp = (int(rng.random() < p) for p in (0.18, 0.12, 0.05, 0.05))
            filas.append(dict(
                numero_serie=serie, fila_origen=fila_origen, fecha=dia, modelo=modelo,
                tipo_servicio=TIPOS[int(rng.integers(0, len(TIPOS)))],
                contador_1=np.nan if rng.random() < 0.05 else contador,
                mantenimiento=int(rng.random() < 0.9), calibracion=int(rng.random() < 0.4),
                rodillo=rod, cabezal=cab, sensor_ribbon=sr, sensor_papel=sp, falla=int(any((cab, rod, sr, sp)))))
            if rng.random() < 0.08:                       # a veces dos visitas el mismo dia
                dia = dia
                continue
            dia += timedelta(days=int(rng.integers(20, 120)))
    return D.preparar_visitas(pd.DataFrame(filas, columns=D.COLS))


def escribir_csv(V, ruta) -> None:
    V.to_csv(ruta, index=False)


def settings_falsos(**cambios) -> SimpleNamespace:
    """Reemplazo de get_settings() para las pruebas del modulo de riesgo."""
    base = dict(risk_enabled=True, risk_model_path="", risk_historico_path="", risk_permitir_sin_historico=False,
                risk_series_excluidas="", risk_clientes_excluidos="", risk_inferir_dano_en_notas=True)
    base.update(cambios)
    return SimpleNamespace(**base)
