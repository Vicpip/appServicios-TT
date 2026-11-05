import axios from 'axios'
import type { Nivel, Pieza } from '@/types/risk'

export const RIESGO_AYUDA =
  'Estimación estadística de riesgo de daño en los próximos 90 días. No es un diagnóstico.'

export const RIESGO_AYUDA_INDICE =
  'El índice es un percentil de riesgo relativo (0 a 100), no una probabilidad.'

export const PIEZA_LABEL: Record<Pieza, string> = {
  cabezal: 'Cabezal',
  rodillo: 'Rodillo',
}

export const NIVEL_ORDEN: Record<Nivel, number> = { ALTO: 3, MEDIO: 2, BAJO: 1 }

/** Fecha 'YYYY-MM-DD' sin desplazamiento por zona horaria. */
export function fmtFecha(iso: string): string {
  const [y, m, d] = iso.slice(0, 10).split('-').map(Number)
  if (!y || !m || !d) return iso
  return new Date(y, m - 1, d).toLocaleDateString('es-MX', {
    day: '2-digit', month: 'short', year: 'numeric',
  })
}

/** El servidor manda UTC; si llega sin zona se interpreta como UTC. */
export function fmtFechaHora(iso: string): string {
  const conZona = /(Z|[+-]\d{2}:?\d{2})$/.test(iso) ? iso : `${iso}Z`
  const d = new Date(conZona)
  if (Number.isNaN(d.getTime())) return iso
  return d.toLocaleString('es-MX', {
    day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit',
  })
}

export type RiskErrorContext = 'impresora' | 'poliza'

function statusOf(err: unknown): number | null {
  return axios.isAxiosError(err) && err.response ? err.response.status : null
}

function detailOf(err: unknown): string | null {
  if (!axios.isAxiosError(err)) return null
  const detail: unknown = (err.response?.data as { detail?: unknown } | undefined)?.detail
  return typeof detail === 'string' && detail.trim() ? detail : null
}

/** El módulo se considera apagado/sin modelo solo con 503 o 404 en model/info. */
export function isModuleOffError(err: unknown): boolean {
  const s = statusOf(err)
  return s === 503 || s === 404
}

/** Mensaje en español para un error del POST de refresh (nunca genérico). */
export function refreshErrorMessage(err: unknown, ctx: RiskErrorContext): string {
  const status = statusOf(err)
  const detail = detailOf(err)
  if (status === 409) return 'Ya hay una actualización en curso, intenta en un momento.'
  if (status === 503) {
    const extra = detail && !detail.startsWith('Modelo de riesgo no disponible') ? ` ${detail}` : ''
    return `El modelo de riesgo no está disponible.${extra}`
  }
  if (status === 404) {
    return detail ?? (ctx === 'poliza'
      ? 'No se encontró la póliza o no tiene impresoras con riesgo calculable.'
      : 'No se encontró la impresora o no tiene datos para estimar su riesgo.')
  }
  if (status === 401 || status === 403) return 'Tu sesión no tiene permiso para actualizar el riesgo.'
  if (status !== null && status >= 500) {
    return detail ?? 'El servidor no pudo actualizar el riesgo. Revisa el registro del servidor.'
  }
  if (axios.isAxiosError(err) && err.code === 'ECONNABORTED') {
    return 'La actualización tardó demasiado. Revisa más tarde si se completó.'
  }
  if (axios.isAxiosError(err) && !err.response) {
    return 'No se pudo conectar con el servidor. Revisa tu conexión.'
  }
  return detail ?? `No se pudo actualizar el riesgo (código ${status ?? 'desconocido'}).`
}

/** Mensaje para fallos de lectura (GET). */
export function readErrorMessage(err: unknown): string {
  const status = statusOf(err)
  if (status === 503) return 'El modelo de riesgo no está disponible.'
  if (axios.isAxiosError(err) && !err.response) return 'No se pudo conectar con el servidor.'
  return detailOf(err) ?? `No se pudo cargar el riesgo (código ${status ?? 'desconocido'}).`
}

export function isNotFound(err: unknown): boolean {
  return statusOf(err) === 404
}

export function notFoundDetail(err: unknown): string | null {
  return detailOf(err)
}
