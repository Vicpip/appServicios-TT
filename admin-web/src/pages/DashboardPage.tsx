import { useQuery } from '@tanstack/react-query'
import {
  FileText,
  Building2,
  Printer,
  ShieldAlert,
  CheckCircle2,
  XCircle,
  Clock,
  RefreshCw,
} from 'lucide-react'
import apiClient from '@/api/client'
import { API } from '@/api/endpoints'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface PagedResponse<T> {
  total: number
  offset: number
  limit: number
  items: T[]
}

interface SyncHistoryItem {
  id: string
  entity_type: string
  entity_id: string
  action: string
  status: string
  error_message: string | null
  synced_at: string
}

// ---------------------------------------------------------------------------
// Date helpers
// ---------------------------------------------------------------------------

function startOfMonth(): string {
  const d = new Date()
  return new Date(d.getFullYear(), d.getMonth(), 1).toISOString()
}

function now(): string {
  return new Date().toISOString()
}

function formatDatetime(iso: string): string {
  const d = new Date(iso)
  return d.toLocaleDateString('es-MX', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

// ---------------------------------------------------------------------------
// KPI queries
// ---------------------------------------------------------------------------

function useReportsThisMonth() {
  return useQuery({
    queryKey: ['kpi', 'reports-month'],
    queryFn: async () => {
      const res = await apiClient.get<PagedResponse<unknown>>(API.reports.list, {
        params: { date_from: startOfMonth(), date_to: now(), limit: 1 },
      })
      return res.data.total ?? 0
    },
    placeholderData: 0,
    retry: false,
  })
}

function useActiveClients() {
  return useQuery({
    queryKey: ['kpi', 'clients'],
    queryFn: async () => {
      const res = await apiClient.get<PagedResponse<unknown>>(API.clients.list, {
        params: { limit: 1 },
      })
      return res.data.total ?? 0
    },
    placeholderData: 0,
    retry: false,
  })
}

function usePrintersInAttention() {
  // Status filter is applied in Python post-query, so `total` ≠ filtered count.
  // Fetch all and count items.
  return useQuery({
    queryKey: ['kpi', 'printers-attention'],
    queryFn: async () => {
      const res = await apiClient.get<PagedResponse<unknown>>(API.printers.list, {
        params: { printer_status: 'En Atención', limit: 500 },
      })
      return res.data.items?.length ?? 0
    },
    placeholderData: 0,
    retry: false,
  })
}

function useExpiringPolicies() {
  // Same as above — status filtered in Python.
  return useQuery({
    queryKey: ['kpi', 'policies-expiring'],
    queryFn: async () => {
      const res = await apiClient.get<PagedResponse<unknown>>(API.policies.list, {
        params: { status: 'Expiring', limit: 500 },
      })
      return res.data.items?.length ?? 0
    },
    placeholderData: 0,
    retry: false,
  })
}

function useRecentSync() {
  return useQuery({
    queryKey: ['kpi', 'sync-history'],
    queryFn: async () => {
      const res = await apiClient.get<PagedResponse<SyncHistoryItem>>(API.sync.history, {
        params: { limit: 5 },
      })
      return res.data.items ?? []
    },
    placeholderData: [],
    retry: false,
    refetchInterval: 30_000,
  })
}

// ---------------------------------------------------------------------------
// Sub-components
// ---------------------------------------------------------------------------

interface KpiCardProps {
  label: string
  value: number | undefined
  icon: React.ReactNode
  loading: boolean
  accent: string   // Tailwind bg class for icon circle
  iconColor: string
  borderColor: string
}

function KpiCard({ label, value, icon, loading, accent, iconColor, borderColor }: KpiCardProps) {
  return (
    <div
      className={`bg-white rounded-xl p-5 border-l-4 shadow-sm flex items-center gap-4 ${borderColor}`}
    >
      <div className={`shrink-0 w-12 h-12 rounded-xl flex items-center justify-center ${accent}`}>
        <span className={iconColor}>{icon}</span>
      </div>
      <div className="min-w-0">
        <p className="text-sm text-gray-500 font-sans leading-tight">{label}</p>
        {loading ? (
          <div className="mt-1.5 h-7 w-12 rounded-md bg-gray-100 animate-pulse" />
        ) : (
          <p className="text-3xl font-bold text-[#1A1A2E] font-heading leading-none mt-0.5">
            {value ?? 0}
          </p>
        )}
      </div>
    </div>
  )
}

const STATUS_CONFIG: Record<string, { label: string; icon: React.ReactNode; classes: string }> = {
  synced: {
    label: 'Sincronizado',
    icon: <CheckCircle2 size={13} />,
    classes: 'bg-green-50 text-green-700 border-green-200',
  },
  error: {
    label: 'Error',
    icon: <XCircle size={13} />,
    classes: 'bg-red-50 text-red-600 border-red-200',
  },
  pending: {
    label: 'Pendiente',
    icon: <Clock size={13} />,
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
    <span
      className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full border text-xs font-medium font-sans ${cfg.classes}`}
    >
      {cfg.icon}
      {cfg.label}
    </span>
  )
}

function EntityTypeBadge({ type }: { type: string }) {
  const map: Record<string, string> = {
    report: 'Reporte',
    file: 'Archivo',
    signature: 'Firma',
  }
  return (
    <span className="text-xs font-medium text-gray-500 font-sans">
      {map[type] ?? type}
    </span>
  )
}

// ---------------------------------------------------------------------------
// Main component
// ---------------------------------------------------------------------------

export default function DashboardPage() {
  const reports = useReportsThisMonth()
  const clients = useActiveClients()
  const printers = usePrintersInAttention()
  const policies = useExpiringPolicies()
  const syncHistory = useRecentSync()

  const kpis: KpiCardProps[] = [
    {
      label: 'Reportes este mes',
      value: reports.data as number,
      loading: reports.isLoading,
      icon: <FileText size={22} />,
      accent: 'bg-primary/10',
      iconColor: 'text-primary',
      borderColor: 'border-primary',
    },
    {
      label: 'Clientes activos',
      value: clients.data as number,
      loading: clients.isLoading,
      icon: <Building2 size={22} />,
      accent: 'bg-emerald-50',
      iconColor: 'text-emerald-600',
      borderColor: 'border-emerald-500',
    },
    {
      label: 'Impresoras en atención',
      value: printers.data as number,
      loading: printers.isLoading,
      icon: <Printer size={22} />,
      accent: 'bg-red-50',
      iconColor: 'text-red-500',
      borderColor: 'border-red-500',
    },
    {
      label: 'Pólizas por vencer',
      value: policies.data as number,
      loading: policies.isLoading,
      icon: <ShieldAlert size={22} />,
      accent: 'bg-amber-50',
      iconColor: 'text-amber-500',
      borderColor: 'border-amber-400',
    },
  ]

  return (
    <div className="space-y-6">

      {/* Page title */}
      <div>
        <h2 className="text-xl font-bold text-[#1A1A2E] font-heading">Resumen general</h2>
        <p className="text-sm text-gray-400 font-sans mt-0.5">
          {new Date().toLocaleDateString('es-MX', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}
        </p>
      </div>

      {/* KPI grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
        {kpis.map((kpi) => (
          <KpiCard key={kpi.label} {...kpi} />
        ))}
      </div>

      {/* Sync history table */}
      <div className="bg-white rounded-xl border border-border shadow-sm overflow-hidden">
        <div className="flex items-center justify-between px-5 py-4 border-b border-border">
          <div className="flex items-center gap-2">
            <RefreshCw size={16} className="text-primary" />
            <h3 className="text-sm font-semibold text-[#1A1A2E] font-heading">
              Últimas sincronizaciones
            </h3>
          </div>
          {syncHistory.isFetching && (
            <span className="text-xs text-gray-400 font-sans animate-pulse">Actualizando…</span>
          )}
        </div>

        {syncHistory.isLoading ? (
          <div className="divide-y divide-gray-50">
            {Array.from({ length: 4 }).map((_, i) => (
              <div key={i} className="flex items-center gap-4 px-5 py-3.5 animate-pulse">
                <div className="h-4 w-20 rounded bg-gray-100" />
                <div className="h-4 w-14 rounded bg-gray-100" />
                <div className="h-4 w-16 rounded bg-gray-100 ml-auto" />
              </div>
            ))}
          </div>
        ) : (syncHistory.data as SyncHistoryItem[]).length === 0 ? (
          <div className="px-5 py-10 text-center text-sm text-gray-400 font-sans">
            Sin registros de sincronización aún.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="bg-gray-50 text-left">
                  <th className="px-5 py-2.5 text-xs font-semibold text-gray-400 uppercase tracking-wide font-sans">
                    Fecha
                  </th>
                  <th className="px-5 py-2.5 text-xs font-semibold text-gray-400 uppercase tracking-wide font-sans">
                    Tipo
                  </th>
                  <th className="px-5 py-2.5 text-xs font-semibold text-gray-400 uppercase tracking-wide font-sans">
                    Acción
                  </th>
                  <th className="px-5 py-2.5 text-xs font-semibold text-gray-400 uppercase tracking-wide font-sans">
                    Estado
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-50">
                {(syncHistory.data as SyncHistoryItem[]).map((row) => (
                  <tr key={row.id} className="hover:bg-gray-50/60 transition-colors">
                    <td className="px-5 py-3 text-gray-500 font-sans whitespace-nowrap">
                      {formatDatetime(row.synced_at)}
                    </td>
                    <td className="px-5 py-3">
                      <EntityTypeBadge type={row.entity_type} />
                    </td>
                    <td className="px-5 py-3 text-gray-600 font-sans capitalize">
                      {row.action}
                    </td>
                    <td className="px-5 py-3">
                      <StatusBadge status={row.status} />
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
