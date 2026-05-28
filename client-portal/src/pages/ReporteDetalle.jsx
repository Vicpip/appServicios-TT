import { useQuery } from '@tanstack/react-query'
import { useParams, Link } from 'react-router-dom'
import api from '../api/axios'
import StatusBadge from '../components/StatusBadge'
import Skeleton from '../components/Skeleton'
import EmptyState from '../components/EmptyState'

const fmtDate = (iso) =>
  iso
    ? new Date(iso).toLocaleDateString('es-MX', { day: 'numeric', month: 'long', year: 'numeric' })
    : '—'

function InfoRow({ label, value }) {
  return (
    <div className="flex flex-col sm:flex-row sm:items-start gap-1 sm:gap-4 py-3 border-b border-gray-50 last:border-0">
      <dt className="text-xs font-semibold text-gray-400 uppercase tracking-wide sm:w-40 flex-shrink-0">{label}</dt>
      <dd className="text-sm text-gray-700">{value || '—'}</dd>
    </div>
  )
}

export default function ReporteDetalle() {
  const { id } = useParams()

  const { data: report, isLoading, isError } = useQuery({
    queryKey: ['report', id],
    queryFn: () => api.get(`/api/portal/reports/${id}`).then((r) => r.data),
  })

  if (isError) {
    return (
      <EmptyState
        title="Reporte no encontrado"
        description="No se pudo cargar el reporte. Verifique el enlace."
        action={<Link to="/reportes" className="btn-primary">← Volver a reportes</Link>}
      />
    )
  }

  const parts   = report?.parts   || report?.partes   || []
  const actions = report?.actions || report?.acciones || []

  return (
    <div className="space-y-6 max-w-3xl">
      {/* Breadcrumb */}
      <nav className="text-sm text-gray-500">
        <Link to="/reportes" className="hover:text-primary font-sans">Reportes</Link>
        <span className="mx-2">/</span>
        <span className="text-gray-800 font-medium">
          {isLoading ? '…' : (report?.folio || `#${id}`)}
        </span>
      </nav>

      {/* Header card */}
      {isLoading ? (
        <Skeleton.Card />
      ) : (
        <div className="card">
          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
            <div>
              <p className="text-xs text-gray-400 font-medium uppercase tracking-wide mb-1">Reporte de servicio</p>
              <h2 className="text-xl font-bold text-[#1A1A2E] font-heading">{report?.folio || `#${id}`}</h2>
            </div>
            <div className="flex items-center gap-3">
              <StatusBadge status={report?.status || report?.estado} />
              {/* PDF download — placeholder */}
              <button
                disabled
                title="Próximamente disponible"
                className="btn-ghost text-gray-400 cursor-not-allowed opacity-60 border border-gray-200"
              >
                <svg className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                  <path d="M12 10v6m0 0l-3-3m3 3l3-3M3 17V7a2 2 0 012-2h6l2 2h6a2 2 0 012 2v8a2 2 0 01-2 2H5a2 2 0 01-2-2z" />
                </svg>
                <span>Descargar PDF</span>
                <span className="text-xs bg-amber-100 text-amber-700 px-1.5 py-0.5 rounded-full">Próximamente</span>
              </button>
            </div>
          </div>

          <dl>
            <InfoRow label="Impresora (serie)"   value={report?.printer_serial || report?.printer?.serial_number} />
            <InfoRow label="Modelo"              value={report?.printer?.model  || report?.modelo} />
            <InfoRow label="Tipo de servicio"    value={report?.service_type   || report?.tipo_servicio} />
            <InfoRow label="Técnico"             value={report?.technician     || report?.tecnico} />
            <InfoRow label="Fecha"               value={fmtDate(report?.date   || report?.created_at)} />
            <InfoRow label="Observaciones"       value={report?.notes          || report?.notas} />
          </dl>
        </div>
      )}

      {/* Parts used */}
      <div className="card">
        <h3 className="text-sm font-semibold text-[#1A1A2E] font-heading mb-4">Refacciones utilizadas</h3>
        {isLoading ? (
          <Skeleton.Table rows={3} cols={3} />
        ) : parts.length === 0 ? (
          <EmptyState title="Sin refacciones" description="No se registraron refacciones en este servicio." />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-100">
                  {['Descripción','Cantidad','Número de parte'].map((h) => (
                    <th key={h} className="text-left py-2.5 px-5 text-xs font-semibold text-gray-400 uppercase tracking-wide font-sans">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {parts.map((p, i) => (
                  <tr key={i} className="border-b border-gray-50 last:border-0">
                    <td className="py-2.5 px-3 text-gray-700">{p.description || p.descripcion || '—'}</td>
                    <td className="py-2.5 px-3 text-gray-600 tabular-nums">{p.quantity || p.cantidad || 1}</td>
                    <td className="py-2.5 px-3 font-mono text-xs text-gray-500">{p.part_number || p.numero_parte || '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Actions performed */}
      <div className="card">
        <h3 className="text-sm font-semibold text-[#1A1A2E] font-heading mb-4">Acciones realizadas</h3>
        {isLoading ? (
          <div className="space-y-2">{Array.from({length:3}).map((_,i)=><Skeleton key={i} className="h-5 w-full"/>)}</div>
        ) : actions.length === 0 ? (
          <EmptyState title="Sin acciones registradas" />
        ) : (
          <ul className="space-y-2">
            {actions.map((a, i) => (
              <li key={i} className="flex items-start gap-3 text-sm text-gray-700">
                <span className="mt-1.5 flex-shrink-0 h-1.5 w-1.5 rounded-full bg-primary" />
                {typeof a === 'string' ? a : (a.description || a.descripcion || JSON.stringify(a))}
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  )
}
