// Contrato del módulo de riesgo (server/app/schemas/risk.py). Único lugar de tipos del módulo.

export type Nivel = 'ALTO' | 'MEDIO' | 'BAJO'
export type Pieza = 'cabezal' | 'rodillo'

export interface PiezaSnapshot {
  nivel: Nivel
  /** Percentil 0-100 de riesgo relativo. NO es una probabilidad. */
  indice_riesgo: number
  danada_en_ultima_visita: boolean
  danos_previos: number
  /** Rodillo: evidencia débil, solo seguimiento. */
  en_monitoreo: boolean
  /** La bandera se activó solo por las notas del reporte, no por el checklist. */
  dano_detectado_en_notas: boolean
}

export interface EquipoSnapshot {
  printer_id: string
  client_id: string
  numero_serie: string
  modelo_impresora: string
  /** Mismos nombres y fuente que PrinterListItem (/api/admin/printers). */
  code: string | null
  client_name: string | null
  plant_id: string | null
  plant_name: string | null
  area_id: string | null
  area_name: string | null
  fecha_ultima_visita: string
  vigente_hasta: string
  vigente: boolean
  /** Hay reportes más nuevos que este cálculo. */
  stale: boolean
  /** Calculado con una versión de modelo distinta a la cargada. */
  modelo_desactualizado: boolean
  visitas_registradas: number
  visitas_app: number
  visitas_historicas: number
  historial_corto: boolean
  cabezal: PiezaSnapshot
  rodillo: PiezaSnapshot
  version_modelo: string
  computed_at: string
  computed_by: string | null
  aviso: string
}

export interface RiesgoSnapshots {
  total: number
  version_modelo: string | null
  horizonte_dias: number
  aviso: string
  equipos: EquipoSnapshot[]
  sin_calcular: number
}

export interface RefreshRespuesta {
  computed_at: string
  computed_by: string | null
  version_modelo: string
  equipos: EquipoSnapshot[]
  sin_datos: number
  excluidas_no_zebra: number
}

export interface ModeloInfo {
  version: string
  entrenado_en: string
  horizonte_dias: number
  historico_cargado: boolean
  aviso: string
}

export interface RiskListParams {
  level?: Nivel
  piece?: Pieza
  client_id?: string
  limit: number
}
