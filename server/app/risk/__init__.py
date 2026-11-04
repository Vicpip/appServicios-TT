"""Modulo de riesgo de piezas (cabezal y rodillo) a 90 dias.

Vendorizado del modulo de Aurora (modulo_riesgo/). Este paquete no importa
numpy, pandas ni scikit-learn al cargarse: la app debe arrancar sin ellos.
"""


class ModeloNoDisponible(RuntimeError):
    """El artefacto del modelo no existe o no se pudo cargar (p. ej. version de scikit-learn distinta)."""


class HistorialNoDisponible(ModeloNoDisponible):
    """Falta el CSV del historial anterior a la app y no se permitio calcular sin el. `str(e)` no lleva rutas."""
