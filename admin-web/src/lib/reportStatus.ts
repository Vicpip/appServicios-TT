// Estados de reporte: etiqueta en español y clases del badge. Fuente única para
// ReportsPage, TechnicianProfilePage y PrinterDetailPage.
export interface ReportStatusConfig {
  label: string
  classes: string
}

export const REPORT_STATUS: Record<string, ReportStatusConfig> = {
  Draft:               { label: 'Borrador',          classes: 'bg-gray-100 text-gray-600 border-gray-200' },
  Signed:              { label: 'Firmado',           classes: 'bg-blue-50 text-blue-700 border-blue-200' },
  signed:              { label: 'Firmado',           classes: 'bg-blue-50 text-blue-700 border-blue-200' },
  pending_delivery:    { label: 'Pendiente entrega', classes: 'bg-yellow-50 text-yellow-700 border-yellow-200' },
  Synced:              { label: 'Sincronizado',      classes: 'bg-emerald-50 text-emerald-700 border-emerald-200' },
  'Reviewed-Approved': { label: 'Aprobado',          classes: 'bg-green-50 text-green-700 border-green-200' },
  'Reviewed-Rejected': { label: 'Rechazado',         classes: 'bg-red-50 text-red-600 border-red-200' },
}

const FALLBACK_CLASSES = 'bg-gray-100 text-gray-600 border-gray-200'

export function reportStatusConfig(status: string): ReportStatusConfig {
  return REPORT_STATUS[status] ?? { label: status, classes: FALLBACK_CLASSES }
}
