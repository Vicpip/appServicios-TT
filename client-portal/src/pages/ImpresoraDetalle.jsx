import { useQuery } from '@tanstack/react-query'
import { useParams, Link } from 'react-router-dom'
import api from '../api/axios'
import StatusBadge from '../components/StatusBadge'
import Skeleton from '../components/Skeleton'
import EmptyState from '../components/EmptyState'

const fmtDate = (iso) =>
  iso
    ? new Date(iso).toLocaleDateString('es-MX', { day: '2-digit', month: 'long', year: 'numeric' })
    : '—'

// Minimal QR placeholder (SVG grid)
function QrPlaceholder({ value }) {
  return (
    <div className="inline-flex flex-col items-center gap-2">
      <div className="h-24 w-24 rounded-lg border-2 border-gray-200 bg-gray-50 flex items-center justify-center">
        <svg width="64" height="64" viewBox="0 0 64 64" fill="none">
          {/* Simple QR-like pattern */}
          {[0,1,2,3,4,5,6].flatMap((r) =>
            [0,1,2,3,4,5,6].map((c) => {
              const isCorner =
                (r < 2 && c < 2) || (r < 2 && c > 4) || (r > 4 && c < 2)
              return (
                <rect
                  key={`${r}-${c}`}
                  x={c * 9 + 1}
                  y={r * 9 + 1}
                  width={8}
                  height={8}
                  rx={1}
                  fill={isCorner || Math.random() > 0.5 ? '#1B3A6B' : 'transparent'}
                />
              )
            })
          )}
        </svg>
      </div>
      <p className="text-xs text-gray-400 font-mono">{value}</p>
    </div>
  )
}

export default function ImpresoraDetalle() {
  const { id } = useParams()

  const { data: printer, isLoading: loadingPrinter, isError } = useQuery({
    queryKey: ['printer', id],
    queryFn: () => api.get(`/api/portal/printers/${id}`).then((r) => r.data),
  })

  const { data: history = [], isLoading: loadingHistory } = useQuery({
    queryKey: ['printer-history', id],
    queryFn: () => api.get(`/api/portal/printers/${id}/reports`).then((r) => r.data),
    enabled: !!id,
  })

  if (isError) {
    return (
      <EmptyState
        title="Impresora no encontrada"
        description="No se pudo cargar la información. Verifique el enlace."
        action={<Link to="/impresoras" className="btn-primary">← Volver a impresoras</Link>}
      />
    )
  }

  return (
    <div className="space-y-6 max-w-4xl">
      {/* Breadcrumb */}
      <nav className="text-sm text-gray-500">
        <Link to="/impresoras" className="hover:text-primary font-sans">Impresoras</Link>
        <span className="mx-2">/</span>
        <span className="text-[#1A1A2E] font-medium font-sans">
          {loadingPrinter ? '…' : (printer?.serial_number ?? id)}
        </span>
      </nav>

      {/* Printer info card */}
      {loadingPrinter ? (
        <Skeleton.Card />
      ) : (
        <div className="card">
          <div className="flex flex-col sm:flex-row sm:items-start gap-6">
            {/* QR */}
            <div className="flex-shrink-0">
              <QrPlaceholder value={printer?.serial_number ?? '—'} />
            </div>

            {/* Details */}
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-3 mb-4">
                <h2 className="text-xl font-bold text-[#1A1A2E] font-heading">
                  {printer?.serial_number ?? '—'}
                </h2>
                <StatusBadge status={printer?.status || printer?.estado} />
              </div>

              <dl className="grid grid-cols-1 sm:grid-cols-2 gap-x-8 gap-y-3">
                {[
                  ['Modelo',  printer?.model || printer?.modelo],
                  ['Planta',  printer?.plant || printer?.planta],
                  ['Área',    printer?.area],
                  ['Marca',   printer?.brand || printer?.marca],
                ].map(([label, val]) => (
                  <div key={label}>
                    <dt className="text-xs font-medium text-gray-400 uppercase tracking-wide font-sans">{label}</dt>
                     <dd className="text-sm font-medium text-gray-700 mt-0.5 font-sans">{val || '—'}</dd>
                  </div>
                ))}
              </dl>
            </div>
          </div>
        </div>
      )}

      {/* Service history */}
      <div className="card">
        <h3 className="text-sm font-semibold text-[#1A1A2E] font-heading mb-4">Historial de servicio</h3>
        {loadingHistory ? (
          <Skeleton.Table rows={4} cols={4} />
        ) : history.length === 0 ? (
          <EmptyState title="Sin historial" description="No hay reportes de servicio para esta impresora." />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-100">
                  {['Fecha','Tipo de servicio','Técnico','Estado'].map((h) => (
                    <th key={h} className="text-left py-2.5 px-5 text-xs font-semibold text-gray-400 uppercase tracking-wide font-sans">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {history.map((r) => (
                  <tr key={r.id} className="table-row-hover border-b border-gray-50 last:border-0">
                    <td className="py-3 px-3 text-gray-500">{fmtDate(r.date || r.created_at)}</td>
                    <td className="py-3 px-3 text-gray-700">{r.service_type || r.tipo_servicio || '—'}</td>
                    <td className="py-3 px-3 text-gray-600">{r.technician || r.tecnico || '—'}</td>
                    <td className="py-3 px-3">
                      <Link to={`/reportes/${r.id}`} className="inline-flex items-center gap-2 hover:text-primary">
                        <StatusBadge status={r.status || r.estado} />
                        <span className="text-xs text-primary font-sans">Ver →</span>
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  )
}
