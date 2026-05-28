import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import api from '../api/axios'
import StatusBadge from '../components/StatusBadge'
import Skeleton from '../components/Skeleton'
import EmptyState from '../components/EmptyState'

const fmtDate = (iso) =>
  iso
    ? new Date(iso).toLocaleDateString('es-MX', { day: '2-digit', month: 'short', year: 'numeric' })
    : '—'

const PAGE_SIZE = 20

export default function Reportes() {
  const [printerFilter, setPrinterFilter] = useState('')
  const [dateFrom, setDateFrom]           = useState('')
  const [dateTo, setDateTo]               = useState('')
  const [page, setPage]                   = useState(0)

  const { data: printers = [] } = useQuery({
    queryKey: ['portal-printers'],
    queryFn: () => api.get('/api/portal/printers').then((r) => r.data),
  })

  const { data: reports = [], isLoading, isError } = useQuery({
    queryKey: ['portal-reports'],
    queryFn: () => api.get('/api/portal/reports').then((r) => r.data),
  })

  const filtered = reports.filter((r) => {
    const printerId = String(r.printer_id || r.printer?.id || '')
    if (printerFilter && printerId !== printerFilter) return false
    const d = new Date(r.date || r.created_at)
    if (dateFrom && d < new Date(dateFrom)) return false
    if (dateTo   && d > new Date(dateTo + 'T23:59:59')) return false
    return true
  })

  const totalPages = Math.ceil(filtered.length / PAGE_SIZE)
  const paginated  = filtered.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE)

  const resetFilters = () => {
    setPrinterFilter('')
    setDateFrom('')
    setDateTo('')
    setPage(0)
  }

  return (
    <div className="space-y-5">

      {/* Page header */}
      <div>
        <h2 className="text-xl font-bold text-[#1A1A2E] font-heading">Reportes de servicio</h2>
        <p className="text-sm text-gray-400 font-sans mt-0.5">Historial de intervenciones técnicas registradas</p>
      </div>

      {/* Filters card — matches admin-web card pattern */}
      <div className="bg-white rounded-xl border border-border shadow-sm p-5">
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
          <div>
            <label htmlFor="filter-printer" className="block text-xs font-medium text-gray-500 font-sans mb-1">Impresora</label>
            <select
              id="filter-printer"
              className="input"
              value={printerFilter}
              onChange={(e) => { setPrinterFilter(e.target.value); setPage(0) }}
            >
              <option value="">Todas las impresoras</option>
              {printers.map((p) => (
                <option key={p.id} value={String(p.id)}>
                  {p.serial_number} — {p.model || p.modelo}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label htmlFor="filter-from" className="block text-xs font-medium text-gray-500 font-sans mb-1">Desde</label>
            <input id="filter-from" type="date" className="input" value={dateFrom} onChange={(e) => { setDateFrom(e.target.value); setPage(0) }} />
          </div>
          <div>
            <label htmlFor="filter-to" className="block text-xs font-medium text-gray-500 font-sans mb-1">Hasta</label>
            <input id="filter-to" type="date" className="input" value={dateTo} onChange={(e) => { setDateTo(e.target.value); setPage(0) }} />
          </div>
        </div>
        {(printerFilter || dateFrom || dateTo) && (
          <button onClick={resetFilters} className="mt-3 text-xs text-primary hover:underline font-sans">
            Limpiar filtros
          </button>
        )}
      </div>

      {/* Table card — mirrors admin-web table pattern */}
      <div className="bg-white rounded-xl border border-border shadow-sm overflow-hidden">
        {isLoading ? (
          <div className="divide-y divide-gray-50">
            {Array.from({ length: 5 }).map((_, i) => (
              <div key={i} className="flex items-center gap-4 px-5 py-3.5 animate-pulse">
                <div className="h-4 w-20 rounded bg-gray-100" />
                <div className="h-4 w-32 rounded bg-gray-100" />
                <div className="h-4 w-24 rounded bg-gray-100" />
                <div className="h-4 w-16 rounded bg-gray-100 ml-auto" />
              </div>
            ))}
          </div>
        ) : isError ? (
          <div className="p-6">
            <EmptyState title="Error al cargar reportes" description="Intente de nuevo más tarde." />
          </div>
        ) : paginated.length === 0 ? (
          <div className="p-6">
            <EmptyState
              title="Sin reportes"
              description={
                filtered.length === 0 && reports.length > 0
                  ? 'No hay reportes para los filtros seleccionados.'
                  : 'No tiene reportes registrados.'
              }
            />
          </div>
        ) : (
          <>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="bg-gray-50 text-left">
                    {['Folio', 'Serie', 'Tipo de servicio', 'Fecha', 'Estado'].map((col) => (
                      <th
                        key={col}
                        className="px-5 py-2.5 text-xs font-semibold text-gray-400 uppercase tracking-wide font-sans"
                      >
                        {col}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-50">
                  {paginated.map((r) => (
                    <tr
                      key={r.id}
                      className="hover:bg-gray-50/60 transition-colors cursor-pointer"
                      onClick={() => window.location.href = `/reportes/${r.id}`}
                    >
                      <td className="px-5 py-3 font-mono text-xs text-gray-500">{r.folio || `#${r.id}`}</td>
                      <td className="px-5 py-3 font-medium text-[#1A1A2E] font-sans">
                        {r.printer_serial || r.printer?.serial_number || '—'}
                      </td>
                      <td className="px-5 py-3 text-gray-600 font-sans">{r.service_type || r.tipo_servicio || '—'}</td>
                      <td className="px-5 py-3 text-gray-500 font-sans whitespace-nowrap">
                        {fmtDate(r.service_date || r.date || r.created_at)}
                      </td>
                      <td className="px-5 py-3"><StatusBadge status={r.status || r.estado} /></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {/* Pagination — mirrors admin-web style */}
            {totalPages > 1 && (
              <div className="flex items-center justify-between px-5 py-3 border-t border-border bg-gray-50">
                <p className="text-xs text-gray-500 font-sans">
                  Mostrando {page * PAGE_SIZE + 1}–{Math.min((page + 1) * PAGE_SIZE, filtered.length)} de {filtered.length}
                </p>
                <div className="flex gap-1">
                  <button
                    disabled={page === 0}
                    onClick={() => setPage((p) => p - 1)}
                    className="btn-ghost text-xs px-3 py-1 disabled:opacity-40"
                  >
                    ← Anterior
                  </button>
                  <button
                    disabled={page >= totalPages - 1}
                    onClick={() => setPage((p) => p + 1)}
                    className="btn-ghost text-xs px-3 py-1 disabled:opacity-40"
                  >
                    Siguiente →
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
