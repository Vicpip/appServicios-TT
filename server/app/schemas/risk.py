"""Schemas del modulo de riesgo (admin). Pydantic v2."""
from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel

Nivel = Literal["ALTO", "MEDIO", "BAJO"]


class PiezaRiesgo(BaseModel):
    nivel: Nivel
    indice_riesgo: float                  # percentil 0-100 frente a lo observado en validacion; NO es una probabilidad
    danada_en_ultima_visita: bool
    danos_previos: int
    en_monitoreo: bool = False            # rodillo: evidencia debil, se muestra solo como seguimiento


class EquipoRiesgo(BaseModel):
    printer_id: str
    client_id: str
    numero_serie: str
    modelo_impresora: str
    fecha_ultima_visita: str
    vigente_hasta: str
    vigente: bool                         # False si la estimacion ya vencio (90 dias desde la ultima visita)
    visitas_registradas: int
    visitas_app: int
    visitas_historicas: int               # filas del CSV anterior a la app
    historial_corto: bool                 # menos de 3 visitas: la estimacion es poco fiable
    cabezal: PiezaRiesgo
    rodillo: PiezaRiesgo
    aviso: str


class RiesgoListado(BaseModel):
    total: int                            # antes de aplicar `limit`
    version_modelo: str
    horizonte_dias: int
    aviso: str
    equipos: list[EquipoRiesgo]
    excluidas_no_zebra: int = 0
    sin_visitas: int = 0


class ModeloInfo(BaseModel):
    version: str
    entrenado_en: str
    horizonte_dias: int
    n_visitas_base: int
    n_equipos_base: int
    n_filas_entrenamiento: int
    n_equipos_entrenamiento: int
    ultima_visita_en_base: str
    niveles: dict[str, str]
    piezas: dict[str, Any]
    metricas_referencia: dict[str, Any]
    historico_cargado: bool               # False si falta el CSV del historial anterior a la app
    n_filas_historico: int
    permitir_sin_historico: bool
    aviso: str


# --------------------------------------------------------------------------- snapshots (Fase C)

class PiezaSnapshot(PiezaRiesgo):
    dano_detectado_en_notas: bool = False  # la bandera de esta pieza se activo solo por las notas del reporte (no por el checklist)


class EquipoSnapshot(BaseModel):
    """Riesgo guardado de una impresora (lectura de printer_risk_snapshots; no se calcula al leer)."""
    printer_id: str
    client_id: str
    numero_serie: str
    modelo_impresora: str
    # Datos de la impresora, con los mismos nombres y fuente que PrinterListItem (GET /api/admin/printers)
    code: str | None = None               # printers.code
    client_name: str | None = None        # clients.name
    plant_id: str | None = None
    plant_name: str | None = None
    area_id: str | None = None
    area_name: str | None = None
    fecha_ultima_visita: str
    vigente_hasta: str
    vigente: bool                         # derivado al leer: valid_until >= hoy
    stale: bool                           # hay reportes mas nuevos que este calculo
    modelo_desactualizado: bool           # calculado con una version de modelo distinta a la cargada
    visitas_registradas: int
    visitas_app: int
    visitas_historicas: int
    historial_corto: bool
    cabezal: PiezaSnapshot
    rodillo: PiezaSnapshot
    version_modelo: str
    computed_at: datetime                 # UTC
    computed_by: str | None = None        # users.id; None = job diario
    aviso: str


class RiesgoSnapshots(BaseModel):
    total: int                            # antes de aplicar `limit`
    version_modelo: str | None            # del modelo cargado; None si no esta disponible
    horizonte_dias: int
    aviso: str
    equipos: list[EquipoSnapshot]
    sin_calcular: int = 0                 # impresoras que entran al calculo y no tienen snapshot (incluye las sin visitas)


class RefreshRespuesta(BaseModel):
    computed_at: datetime
    computed_by: str | None
    version_modelo: str
    equipos: list[EquipoSnapshot]
    sin_datos: int = 0                    # impresoras sin visitas ni historial: no se calcularon
    excluidas_no_zebra: int = 0
