import { useParams, Link } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { ChevronLeft, FileText, Download } from 'lucide-react'
import apiClient from '@/api/axios'
import StatusBadge from '@/components/StatusBadge'
import { SkeletonLine } from '@/components/Skeleton'

function fmtDate(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString('es-MX', { day: 'numeric', month: 'short', year: 'numeric' })
}

function InfoRow({ label, value }) {
  if (value == null || value === '') return null
  return (
    <div className="flex items-start gap-2 py-2.5 border-b border-gray-50 last:border-0">
      <span className="text-xs text-gray-400 font-sans w-40 shrink-0 pt-0.5">{label}</span>
      <span className="text-sm text-[#1A1A2E] font-sans">{value}</span>
    </div>
  )
}

export default function ReporteDetalle() {
  const { id } = useParams()

  const { data: report, isLoading, error } = useQuery({
    queryKey: ['portal', 'report', id],
    queryFn: async () => {
      const res = await apiClient.get(`/api/portal/reports/${id}`)
      return res.data
    },
    staleTime: 60_000,
  })

  return (
    <div className="space-y-5">
      <div>
        <Link to="/reportes" className="inline-flex items-center gap-1 text-sm text-gray-500 hover:text-primary mb-3 transition-colors">
          <ChevronLeft size={15} />
          Reportes
        </Link>
        <h2 className="text-xl font-bold text-[#1A1A2E] font-heading">
          {isLoading ? '…' : report?.code ? `Reporte ${report.code}` : 'Detalle del reporte'}
        </h2>
      </div>

      {error && (
        <p className="text-sm text-red-600" role="alert">Error al cargar el reporte.</p>
      )}

      {/* Main card */}
      <div className="bg-white rounded-xl border border-border shadow-sm p-5">
        <div className="flex items-start justify-between gap-3 mb-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center shrink-0">
              <FileText size={18} className="text-primary" />
            </div>
            <div>
              <h3 className="text-sm font-semibold text-[#1A1A2E] font-heading">Información del reporte</h3>
              {report && <StatusBadge status={report.status} />}
            </div>
          </div>

          {/* PDF download — disabled, coming soon */}
          <div className="flex items-center gap-2 shrink-0">
            <button
              disabled
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-border text-xs font-medium text-gray-400 cursor-not-allowed bg-gray-50"
              title="Próximamente"
            >
              <Download size={13} />
              Descargar PDF
            </button>
            {/* TODO: implement when GET /api/portal/reports/{id}/pdf is available */}
            <span className="inline-flex items-center px-2 py-0.5 rounded-full border text-xs font-medium bg-amber-50 text-amber-700 border-amber-200">
              Próximamente
            </span>
          </div>
        </div>

        {isLoading ? (
          <div className="space-y-2">
            {Array.from({ length: 8 }).map((_, i) => (
              <SkeletonLine key={i} className="h-5 w-full" />
            ))}
          </div>
        ) : report ? (
          <div>
            <InfoRow label="Código" value={report.code} />
            <InfoRow label="Impresora" value={report.printer_serial} />
            <InfoRow label="Técnico" value={report.tech_name} />
            <InfoRow label="Tipo de servicio" value={report.service_type} />
            <InfoRow label="Fecha de servicio" value={fmtDate(report.service_date)} />
            {report.linear_inches_counter != null && (
              <InfoRow label="Contador (pulg. lineales)" value={String(report.linear_inches_counter)} />
            )}
            {report.darkness_level != null && (
              <InfoRow label="Nivel de oscuridad" value={String(report.darkness_level)} />
            )}
            {report.photo_count > 0 && (
              <InfoRow label="Fotos adjuntas" value={`${report.photo_count} foto${report.photo_count !== 1 ? 's' : ''}`} />
            )}
            {report.signature_name && (
              <InfoRow
                label="Firmado por"
                value={[report.signature_name, report.signature_role].filter(Boolean).join(' · ')}
              />
            )}
            {report.notes && (
              <div className="py-2.5 border-b border-gray-50">
                <span className="text-xs text-gray-400 font-sans block mb-1">Notas</span>
                <p className="text-sm text-[#1A1A2E] font-sans whitespace-pre-wrap">{report.notes}</p>
              </div>
            )}
          </div>
        ) : null}
      </div>
    </div>
  )
}
