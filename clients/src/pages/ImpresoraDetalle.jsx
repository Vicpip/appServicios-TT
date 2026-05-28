import { useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { ChevronLeft, Printer, ChevronRight } from 'lucide-react'
import apiClient from '@/api/axios'
import StatusBadge from '@/components/StatusBadge'
import { SkeletonLine, SkeletonTable } from '@/components/Skeleton'
import EmptyState from '@/components/EmptyState'

const LIMIT = 10

function fmtDate(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString('es-MX', { day: 'numeric', month: 'short', year: 'numeric' })
}

function InfoRow({ label, value }) {
  if (value == null || value === '') return null
  return (
    <div className="flex items-start gap-2 py-2.5 border-b border-gray-50 last:border-0">
      <span className="text-xs text-gray-400 font-sans w-32 shrink-0 pt-0.5">{label}</span>
      <span className="text-sm text-[#1A1A2E] font-sans">{value}</span>
    </div>
  )
}

export default function ImpresoraDetalle() {
  const { id } = useParams()
  const [offset, setOffset] = useState(0)

  const { data: printer, isLoading: loadingPrinter, error: printerError } = useQuery({
    queryKey: ['portal', 'printer', id],
    queryFn: async () => {
      const res = await apiClient.get(`/api/portal/printers/${id}`)
      return res.data
    },
    staleTime: 60_000,
  })

  const { data: reportsData, isLoading: loadingReports } = useQuery({
    queryKey: ['portal', 'printer-reports', id, offset],
    queryFn: async () => {
      const res = await apiClient.get('/api/portal/reports', {
        params: { printer_id: id, limit: LIMIT, offset },
      })
      return res.data
    },
    staleTime: 60_000,
  })

  const reports = reportsData?.items ?? []
  const total = reportsData?.total ?? 0
  const totalPages = Math.ceil(total / LIMIT)
  const currentPage = Math.floor(offset / LIMIT) + 1

  return (
    <div className="space-y-5">
      <div>
        <Link to="/impresoras" className="inline-flex items-center gap-1 text-sm text-gray-500 hover:text-primary mb-3 transition-colors">
          <ChevronLeft size={15} />
          Mis Impresoras
        </Link>
        <h2 className="text-xl font-bold text-[#1A1A2E] font-heading">
          {loadingPrinter ? '…' : printer?.serial_number ?? 'Impresora'}
        </h2>
      </div>

      {printerError && (
        <p className="text-sm text-red-600" role="alert">Error al cargar la impresora.</p>
      )}

      {/* Printer info card */}
      <div className="bg-white rounded-xl border border-border shadow-sm p-5">
        <div className="flex items-center gap-3 mb-4">
          <div className="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center">
            <Printer size={18} className="text-primary" />
          </div>
          <div>
            <h3 className="text-sm font-semibold text-[#1A1A2E] font-heading">Información de la impresora</h3>
          </div>
        </div>

        {loadingPrinter ? (
          <div className="space-y-2">
            {Array.from({ length: 5 }).map((_, i) => (
              <SkeletonLine key={i} className="h-5 w-full" />
            ))}
          </div>
        ) : printer ? (
          <div>
            <InfoRow label="Número de serie" value={printer.serial_number} />
            <InfoRow label="Marca" value={printer.model_brand} />
            <InfoRow label="Modelo" value={printer.model_name} />
            {printer.model_dpi != null && (
              <InfoRow label="Resolución (DPI)" value={String(printer.model_dpi)} />
            )}
            <InfoRow label="Planta" value={printer.plant_name} />
            <InfoRow label="Área" value={printer.area_name} />
            <div className="flex items-start gap-2 py-2.5">
              <span className="text-xs text-gray-400 font-sans w-32 shrink-0 pt-0.5">Estado</span>
              <StatusBadge status={printer.is_active ? 'activo' : 'inactivo'} />
            </div>
          </div>
        ) : null}
      </div>

      {/* Service history */}
      <div className="bg-white rounded-xl border border-border shadow-sm overflow-hidden">
        <div className="px-5 py-4 border-b border-border">
          <h3 className="text-sm font-semibold text-[#1A1A2E] font-heading">Historial de servicio</h3>
          {total > 0 && <p className="text-xs text-gray-400 font-sans mt-0.5">{total} reporte{total !== 1 ? 's' : ''}</p>}
        </div>

        {loadingReports ? (
          <SkeletonTable rows={5} cols={4} />
        ) : reports.length === 0 ? (
          <EmptyState message="Sin reportes de servicio" />
        ) : (
          <>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="bg-gray-50 text-left">
                    {['Código', 'Tipo', 'Fecha', 'Estado'].map(col => (
                      <th key={col} className="px-5 py-2.5 text-xs font-semibold text-gray-400 uppercase tracking-wide font-sans">
                        {col}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-50">
                  {reports.map(r => (
                    <tr key={r.id} className="hover:bg-gray-50/60 transition-colors">
                      <td className="px-5 py-3 font-mono text-xs text-gray-600">
                        <Link to={`/reportes/${r.id}`} className="text-primary hover:underline">
                          {r.code ?? '—'}
                        </Link>
                      </td>
                      <td className="px-5 py-3 text-gray-600 font-sans">{r.service_type ?? '—'}</td>
                      <td className="px-5 py-3 text-gray-500 font-sans whitespace-nowrap">{fmtDate(r.service_date)}</td>
                      <td className="px-5 py-3"><StatusBadge status={r.status} /></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {totalPages > 1 && (
              <div className="flex items-center justify-between px-5 py-3 border-t border-border bg-gray-50">
                <p className="text-xs text-gray-400 font-sans">
                  Página {currentPage} de {totalPages}
                </p>
                <div className="flex items-center gap-1">
                  <button
                    onClick={() => setOffset(Math.max(0, offset - LIMIT))}
                    disabled={offset === 0}
                    className="flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium text-gray-600 hover:bg-gray-200 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
                  >
                    <ChevronLeft size={14} />
                    Anterior
                  </button>
                  <button
                    onClick={() => setOffset(offset + LIMIT)}
                    disabled={offset + LIMIT >= total}
                    className="flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium text-gray-600 hover:bg-gray-200 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
                  >
                    Siguiente
                    <ChevronRight size={14} />
                  </button>
                </div>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  )
}
