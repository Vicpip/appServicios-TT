import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { useNavigate } from 'react-router-dom'
import { FileText, ChevronLeft, ChevronRight } from 'lucide-react'
import apiClient from '@/api/axios'
import StatusBadge from '@/components/StatusBadge'
import { SkeletonTable } from '@/components/Skeleton'
import EmptyState from '@/components/EmptyState'

const LIMIT = 20

function fmtDate(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString('es-MX', { day: 'numeric', month: 'short', year: 'numeric' })
}

export default function Reportes() {
  const navigate = useNavigate()
  const [offset, setOffset] = useState(0)
  const [selectedPrinter, setSelectedPrinter] = useState('')
  const [dateFrom, setDateFrom] = useState('')
  const [dateTo, setDateTo] = useState('')

  const { data: printers = [] } = useQuery({
    queryKey: ['portal', 'printers'],
    queryFn: async () => {
      const res = await apiClient.get('/api/portal/printers')
      return res.data
    },
    staleTime: 60_000,
  })

  const params = { limit: LIMIT, offset }
  if (selectedPrinter) params.printer_id = selectedPrinter

  const { data: reportsData, isLoading, error } = useQuery({
    queryKey: ['portal', 'reports', offset, selectedPrinter],
    queryFn: async () => {
      const res = await apiClient.get('/api/portal/reports', { params })
      return res.data
    },
    staleTime: 60_000,
  })

  const allItems = reportsData?.items ?? []
  const total = reportsData?.total ?? 0
  const totalPages = Math.ceil(total / LIMIT)
  const currentPage = Math.floor(offset / LIMIT) + 1

  // Client-side date filter
  const filtered = allItems.filter(r => {
    if (dateFrom && new Date(r.service_date) < new Date(dateFrom)) return false
    if (dateTo && new Date(r.service_date) > new Date(dateTo + 'T23:59:59')) return false
    return true
  })

  const handleFilterChange = () => {
    setOffset(0)
  }

  return (
    <div className="space-y-5">
      <div>
        <h2 className="text-xl font-bold text-[#1A1A2E] font-heading">Reportes de servicio</h2>
        {!isLoading && (
          <p className="text-sm text-gray-400 font-sans mt-0.5">
            {total} reporte{total !== 1 ? 's' : ''} en total
          </p>
        )}
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3">
        <select
          value={selectedPrinter}
          onChange={(e) => { setSelectedPrinter(e.target.value); handleFilterChange() }}
          className="px-3 py-2 rounded-lg border border-border text-sm bg-white focus:outline-none focus:ring-2 focus:ring-primary focus:border-primary"
        >
          <option value="">Todas las impresoras</option>
          {printers.map(p => (
            <option key={p.id} value={p.id}>{p.serial_number}</option>
          ))}
        </select>

        <div className="flex items-center gap-2">
          <input
            type="date"
            value={dateFrom}
            onChange={(e) => setDateFrom(e.target.value)}
            className="px-3 py-2 rounded-lg border border-border text-sm bg-white focus:outline-none focus:ring-2 focus:ring-primary focus:border-primary"
          />
          <span className="text-xs text-gray-400">—</span>
          <input
            type="date"
            value={dateTo}
            onChange={(e) => setDateTo(e.target.value)}
            className="px-3 py-2 rounded-lg border border-border text-sm bg-white focus:outline-none focus:ring-2 focus:ring-primary focus:border-primary"
          />
        </div>

        {(selectedPrinter || dateFrom || dateTo) && (
          <button
            onClick={() => { setSelectedPrinter(''); setDateFrom(''); setDateTo(''); setOffset(0) }}
            className="px-3 py-2 rounded-lg border border-border text-sm text-gray-500 hover:bg-gray-50 bg-white transition-colors"
          >
            Limpiar filtros
          </button>
        )}
      </div>

      {error && (
        <p className="text-sm text-red-600" role="alert">Error al cargar los reportes. Intenta recargar.</p>
      )}

      <div className="bg-white rounded-xl border border-border shadow-sm overflow-hidden">
        {isLoading ? (
          <SkeletonTable rows={8} cols={5} />
        ) : filtered.length === 0 ? (
          <EmptyState message="Sin reportes para los filtros seleccionados" icon={FileText} />
        ) : (
          <>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="bg-gray-50 text-left">
                    {['Código', 'Impresora', 'Tipo', 'Fecha', 'Estado'].map(col => (
                      <th key={col} className="px-5 py-2.5 text-xs font-semibold text-gray-400 uppercase tracking-wide font-sans">
                        {col}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-50">
                  {filtered.map(r => (
                    <tr
                      key={r.id}
                      onClick={() => navigate(`/reportes/${r.id}`)}
                      className="hover:bg-gray-50/60 transition-colors cursor-pointer"
                    >
                      <td className="px-5 py-3 font-mono text-xs text-gray-600">{r.code ?? '—'}</td>
                      <td className="px-5 py-3 text-gray-700 font-sans">{r.printer_serial ?? '—'}</td>
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
                  Página {currentPage} de {totalPages} · {total} reportes
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
