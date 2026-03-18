import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { RefreshCw, CheckCircle2, XCircle, Clock, ChevronLeft, ChevronRight } from 'lucide-react'
import apiClient from '@/api/client'
import { API } from '@/api/endpoints'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface SyncHistoryItem {
  id: string
  entity_type: string
  entity_id: string
  action: string
  status: string
  error_message: string | null
  synced_at: string
  server_response: string | null
}

interface SyncStatusData {
  synced: number
  pending: number
  failed: number
}

interface PagedResponse<T> {
  total: number
  offset: number
  limit: number
  items: T[]
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const PAGE_SIZE = 25

function fmtDatetime(iso: string) {
  return new Date(iso).toLocaleDateString('es-MX', {
    day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  })
}

const STATUS_CONFIG: Record<string, { label: string; icon: React.ReactNode; classes: string }> = {
  synced: {
    label: 'Sincronizado',
    icon: <CheckCircle2 size={12} />,
    classes: 'bg-green-50 text-green-700 border-green-200',
  },
  error: {
    label: 'Error',
    icon: <XCircle size={12} />,
    classes: 'bg-red-50 text-red-600 border-red-200',
  },
  pending: {
    label: 'Pendiente',
    icon: <Clock size={12} />,
    classes: 'bg-amber-50 text-amber-700 border-amber-200',
  },
}

function StatusBadge({ status }: { status: string }) {
  const cfg = STATUS_CONFIG[status] ?? {
    label: status,
    icon: null,
    classes: 'bg-gray-50 text-gray-600 border-gray-200',
  }
  return (
    <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full border text-xs font-medium font-sans ${cfg.classes}`}>
      {cfg.icon}{cfg.label}
    </span>
  )
}

const ENTITY_LABELS: Record<string, string> = {
  report: 'Reporte',
  file: 'Archivo',
  signature: 'Firma',
}

function EntityBadge({ type }: { type: string }) {
  const colors: Record<string, string> = {
    report: 'bg-blue-50 text-blue-700 border-blue-200',
    file: 'bg-violet-50 text-violet-700 border-violet-200',
    signature: 'bg-emerald-50 text-emerald-700 border-emerald-200',
  }
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded-full border text-xs font-medium font-sans ${colors[type] ?? 'bg-gray-50 text-gray-600 border-gray-200'}`}>
      {ENTITY_LABELS[type] ?? type}
    </span>
  )
}

// ---------------------------------------------------------------------------
// Main page
// ---------------------------------------------------------------------------

export default function SyncPage() {
  const [statusFilter, setStatusFilter] = useState('')
  const [entityFilter, setEntityFilter] = useState('')
  const [dateFrom, setDateFrom] = useState('')
  const [dateTo, setDateTo] = useState('')
  const [page, setPage] = useState(0)

  // Summary counters
  const { data: syncStatus } = useQuery({
    queryKey: ['sync-status'],
    queryFn: async () => {
      const res = await apiClient.get<SyncStatusData>(API.sync.status)
      return res.data
    },
    refetchInterval: 30_000,
    retry: false,
  })

  const queryParams = {
    limit: PAGE_SIZE,
    offset: page * PAGE_SIZE,
    ...(statusFilter && { status: statusFilter }),
    ...(entityFilter && { entity_type: entityFilter }),
    ...(dateFrom && { date_from: new Date(dateFrom).toISOString() }),
    ...(dateTo && { date_to: new Date(dateTo + 'T23:59:59').toISOString() }),
  }

  const { data, isLoading, isFetching } = useQuery({
    queryKey: ['sync-history', queryParams],
    queryFn: async () => {
      const res = await apiClient.get<PagedResponse<SyncHistoryItem>>(API.sync.history, { params: queryParams })
      return res.data
    },
    placeholderData: (prev) => prev,
    retry: false,
    refetchInterval: 30_000,
  })

  const total = data?.total ?? 0
  const items = data?.items ?? []
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE))

  const hasFilters = statusFilter || entityFilter || dateFrom || dateTo

  function resetFilters() {
    setStatusFilter('')
    setEntityFilter('')
    setDateFrom('')
    setDateTo('')
    setPage(0)
  }

  const selectCls = 'text-sm font-sans border border-border rounded-lg px-3 py-2 bg-white text-gray-700 focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition-colors'

  return (
    <div className="space-y-4">
      {/* Header */}
      <div>
        <h2 className="text-xl font-bold text-[#1A1A2E] font-heading">Sincronización</h2>
        <p className="text-sm text-gray-400 font-sans mt-0.5">
          Historial de actividad de sync desde la app móvil
        </p>
      </div>

      {/* Counter cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="bg-white rounded-xl border border-emerald-100 shadow-sm p-5 flex items-center gap-4 border-l-4 border-l-emerald-500">
          <div className="w-10 h-10 rounded-xl bg-emerald-50 flex items-center justify-center shrink-0">
            <CheckCircle2 size={18} className="text-emerald-600" />
          </div>
          <div>
            <p className="text-sm text-gray-500 font-sans">Sincronizados</p>
            <p className="text-2xl font-bold text-[#1A1A2E] font-heading leading-none mt-0.5">
              {syncStatus?.synced ?? 0}
            </p>
          </div>
        </div>

        <div className="bg-white rounded-xl border border-red-100 shadow-sm p-5 flex items-center gap-4 border-l-4 border-l-red-500">
          <div className="w-10 h-10 rounded-xl bg-red-50 flex items-center justify-center shrink-0">
            <XCircle size={18} className="text-red-500" />
          </div>
          <div>
            <p className="text-sm text-gray-500 font-sans">Con error</p>
            <p className="text-2xl font-bold text-[#1A1A2E] font-heading leading-none mt-0.5">
              {syncStatus?.failed ?? 0}
            </p>
          </div>
        </div>

        <div className="bg-white rounded-xl border border-amber-100 shadow-sm p-5 flex items-center gap-4 border-l-4 border-l-amber-400">
          <div className="w-10 h-10 rounded-xl bg-amber-50 flex items-center justify-center shrink-0">
            <Clock size={18} className="text-amber-500" />
          </div>
          <div>
            <p className="text-sm text-gray-500 font-sans">Pendientes</p>
            <p className="text-2xl font-bold text-[#1A1A2E] font-heading leading-none mt-0.5">
              {syncStatus?.pending ?? 0}
            </p>
          </div>
        </div>
      </div>

      {/* Filters */}
      <div className="bg-white rounded-xl border border-border p-4 shadow-sm">
        <div className="flex flex-wrap gap-3 items-end">
          <select value={statusFilter} onChange={(e) => { setStatusFilter(e.target.value); setPage(0) }} className={selectCls}>
            <option value="">Todos los estados</option>
            <option value="synced">Sincronizado</option>
            <option value="error">Error</option>
            <option value="pending">Pendiente</option>
          </select>
          <select value={entityFilter} onChange={(e) => { setEntityFilter(e.target.value); setPage(0) }} className={selectCls}>
            <option value="">Todos los tipos</option>
            <option value="report">Reporte</option>
            <option value="file">Archivo</option>
            <option value="signature">Firma</option>
          </select>
          <div className="flex flex-col gap-0.5">
            <label className="text-[10px] text-gray-400 font-sans uppercase tracking-wide pl-0.5">Desde</label>
            <input type="date" value={dateFrom} onChange={(e) => { setDateFrom(e.target.value); setPage(0) }} className={selectCls} />
          </div>
          <div className="flex flex-col gap-0.5">
            <label className="text-[10px] text-gray-400 font-sans uppercase tracking-wide pl-0.5">Hasta</label>
            <input type="date" value={dateTo} onChange={(e) => { setDateTo(e.target.value); setPage(0) }} className={selectCls} />
          </div>
          {hasFilters && (
            <button onClick={resetFilters} className="text-xs text-gray-400 hover:text-primary font-sans transition-colors self-end pb-2">
              Limpiar
            </button>
          )}
          {isFetching && (
            <span className="text-xs text-gray-400 font-sans animate-pulse self-end pb-2">Actualizando…</span>
          )}
        </div>
      </div>

      {/* Table */}
      <div className="bg-white rounded-xl border border-border shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-gray-50 border-b border-border text-left">
                {['Fecha', 'Tipo', 'Acción', 'Estado', 'Error'].map((h) => (
                  <th key={h} className="px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide font-sans whitespace-nowrap">
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {isLoading ? (
                Array.from({ length: 8 }).map((_, i) => (
                  <tr key={i} className="animate-pulse">
                    {Array.from({ length: 5 }).map((_, j) => (
                      <td key={j} className="px-4 py-3.5">
                        <div className="h-4 bg-gray-100 rounded" style={{ width: `${50 + ((i + j) % 3) * 20}%` }} />
                      </td>
                    ))}
                  </tr>
                ))
              ) : items.length === 0 ? (
                <tr>
                  <td colSpan={5} className="px-4 py-12 text-center text-sm text-gray-400 font-sans">
                    <RefreshCw size={28} className="mx-auto mb-2 text-gray-200" />
                    Sin registros de sincronización con los filtros aplicados.
                  </td>
                </tr>
              ) : (
                items.map((row) => (
                  <tr key={row.id} className="hover:bg-gray-50/60 transition-colors">
                    <td className="px-4 py-3 text-gray-500 font-sans whitespace-nowrap text-xs">
                      {fmtDatetime(row.synced_at)}
                    </td>
                    <td className="px-4 py-3">
                      <EntityBadge type={row.entity_type} />
                    </td>
                    <td className="px-4 py-3 text-gray-600 font-sans capitalize">
                      {row.action}
                    </td>
                    <td className="px-4 py-3">
                      <StatusBadge status={row.status} />
                    </td>
                    <td className="px-4 py-3 text-gray-400 font-sans text-xs max-w-[240px] truncate" title={row.error_message ?? ''}>
                      {row.error_message ?? '—'}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        {total > PAGE_SIZE && (
          <div className="flex items-center justify-between px-4 py-3 border-t border-border bg-gray-50">
            <span className="text-xs text-gray-400 font-sans">
              Página {page + 1} de {totalPages} · {total} total
            </span>
            <div className="flex items-center gap-1">
              <button
                onClick={() => setPage((p) => Math.max(0, p - 1))}
                disabled={page === 0}
                className="p-1.5 rounded-lg text-gray-400 hover:text-primary hover:bg-primary/10 disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
              >
                <ChevronLeft size={16} />
              </button>
              {Array.from({ length: Math.min(totalPages, 5) }, (_, i) => {
                const pg = totalPages <= 5 ? i : Math.max(0, Math.min(page - 2, totalPages - 5)) + i
                return (
                  <button
                    key={pg}
                    onClick={() => setPage(pg)}
                    className={`w-7 h-7 text-xs rounded-lg font-sans font-medium transition-colors ${pg === page ? 'bg-primary text-white' : 'text-gray-500 hover:bg-gray-100'}`}
                  >
                    {pg + 1}
                  </button>
                )
              })}
              <button
                onClick={() => setPage((p) => Math.min(totalPages - 1, p + 1))}
                disabled={page >= totalPages - 1}
                className="p-1.5 rounded-lg text-gray-400 hover:text-primary hover:bg-primary/10 disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
              >
                <ChevronRight size={16} />
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
