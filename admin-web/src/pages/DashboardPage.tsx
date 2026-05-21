import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import {
  FileText,
  Building2,
  Printer,
  ShieldAlert,
  CheckCircle2,
  XCircle,
  Clock,
  RefreshCw,
  AlertTriangle,
  CheckCircle,
} from 'lucide-react'
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts'
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
  tech_name: string | null
  detalle: string | null
}

interface DashboardReportsByDay {
  fecha: string
  total: number
  preventivos: number
  correctivos: number
  diagnosticos: number
}

interface DashboardPrinterAttention {
  id: string
  code: string | null
  serial_number: string
  model_name: string | null
  client_name: string | null
  advertencias: string[]
}

interface DashboardPolicyExpiring {
  id: string
  folio: string
  client_name: string
  end_date: string
  dias_restantes: number
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function startOfMonth(): string {
  const d = new Date()
  return new Date(d.getFullYear(), d.getMonth(), 1).toISOString()
}

function now(): string {
  return new Date().toISOString()
}

function formatDatetime(iso: string): string {
  return new Date(iso).toLocaleDateString('es-MX', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

function dayLabel(fechaStr: string): string {
  const days = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb']
  // Parse as local date to avoid timezone offset shifting the day
  const [y, m, d] = fechaStr.split('-').map(Number) as [number, number, number]
  return days[new Date(y, m - 1, d).getDay()]
}

function translateAction(action: string): string {
  const map: Record<string, string> = {
    File_upload: 'Subida de archivo',
    Insert: 'Reporte nuevo',
    Update: 'Actualización',
  }
  return map[action] ?? action.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())
}

// ---------------------------------------------------------------------------
// KPI hooks
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
  return useQuery({
    queryKey: ['kpi', 'printers-attention'],
    queryFn: async () => {
      const res = await apiClient.get<PagedResponse<unknown>>(API.printers.list, {
        params: { printer_status: 'En Atención', limit: 200 },
      })
      return res.data.items?.length ?? 0
    },
    placeholderData: 0,
    retry: false,
  })
}

function useExpiringPolicies() {
  return useQuery({
    queryKey: ['kpi', 'policies-expiring'],
    queryFn: async () => {
      const res = await apiClient.get<PagedResponse<unknown>>(API.policies.list, {
        params: { status: 'Expiring', limit: 200 },
      })
      return res.data.items?.length ?? 0
    },
    placeholderData: 0,
    retry: false,
  })
}

// ---------------------------------------------------------------------------
// Dashboard detail hooks
// ---------------------------------------------------------------------------

function useReportsByDay() {
  return useQuery({
    queryKey: ['dashboard', 'reports-by-day'],
    queryFn: async () => {
      const res = await apiClient.get<DashboardReportsByDay[]>(API.dashboard.reportsByDay)
      return res.data
    },
    placeholderData: [] as DashboardReportsByDay[],
    retry: false,
  })
}

function useDashboardPrintersAttention() {
  return useQuery({
    queryKey: ['dashboard', 'printers-attention'],
    queryFn: async () => {
      const res = await apiClient.get<DashboardPrinterAttention[]>(API.dashboard.printersAttention)
      return res.data
    },
    placeholderData: [] as DashboardPrinterAttention[],
    retry: false,
  })
}

function useDashboardPoliciesExpiring() {
  return useQuery({
    queryKey: ['dashboard', 'policies-expiring'],
    queryFn: async () => {
      const res = await apiClient.get<DashboardPolicyExpiring[]>(API.dashboard.policiesExpiring)
      return res.data
    },
    placeholderData: [] as DashboardPolicyExpiring[],
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
    placeholderData: [] as SyncHistoryItem[],
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
  accent: string
  iconColor: string
  borderColor: string
  to: string
}

function KpiCard({ label, value, icon, loading, accent, iconColor, borderColor, to }: KpiCardProps) {
  return (
    <Link
      to={to}
      className={`bg-white rounded-xl p-5 border-l-4 shadow-sm flex items-center gap-4 cursor-pointer hover:shadow-md transition-shadow ${borderColor}`}
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
    </Link>
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
  const reportsByDay = useReportsByDay()
  const printersAttention = useDashboardPrintersAttention()
  const policiesExpiring = useDashboardPoliciesExpiring()
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
      to: '/reports',
    },
    {
      label: 'Clientes activos',
      value: clients.data as number,
      loading: clients.isLoading,
      icon: <Building2 size={22} />,
      accent: 'bg-emerald-50',
      iconColor: 'text-emerald-600',
      borderColor: 'border-emerald-500',
      to: '/clients',
    },
    {
      label: 'Impresoras en atención',
      value: printers.data as number,
      loading: printers.isLoading,
      icon: <Printer size={22} />,
      accent: 'bg-red-50',
      iconColor: 'text-red-500',
      borderColor: 'border-red-500',
      to: '/printers',
    },
    {
      label: 'Pólizas por vencer',
      value: policies.data as number,
      loading: policies.isLoading,
      icon: <ShieldAlert size={22} />,
      accent: 'bg-amber-50',
      iconColor: 'text-amber-500',
      borderColor: 'border-amber-400',
      to: '/policies',
    },
  ]

  const chartData = (reportsByDay.data as DashboardReportsByDay[]).map(d => ({
    ...d,
    dia: dayLabel(d.fecha),
  }))

  const printersData = printersAttention.data as DashboardPrinterAttention[]
  const policiesData = policiesExpiring.data as DashboardPolicyExpiring[]
  const syncData = syncHistory.data as SyncHistoryItem[]

  return (
    <div className="space-y-6">

      {/* Page title */}
      <div>
        <h2 className="text-xl font-bold text-[#1A1A2E] font-heading">Resumen general</h2>
        <p className="text-sm text-gray-400 font-sans mt-0.5">
          {new Date().toLocaleDateString('es-MX', {
            weekday: 'long',
            year: 'numeric',
            month: 'long',
            day: 'numeric',
          })}
        </p>
      </div>

      {/* KPI grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
        {kpis.map(kpi => (
          <KpiCard key={kpi.label} {...kpi} />
        ))}
      </div>

      {/* Reportes por día */}
      <div className="bg-white rounded-xl border border-border shadow-sm p-5">
        <h3 className="text-sm font-semibold text-[#1A1A2E] font-heading mb-4">
          Reportes por día — últimos 7 días
        </h3>
        {reportsByDay.isLoading ? (
          <div className="h-[200px] flex items-center justify-center">
            <div className="h-4 w-40 rounded bg-gray-100 animate-pulse" />
          </div>
        ) : (
          <ResponsiveContainer width="100%" height={200}>
            <BarChart data={chartData} margin={{ top: 0, right: 0, left: -20, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" vertical={false} />
              <XAxis
                dataKey="dia"
                tick={{ fontSize: 12, fill: '#9ca3af' }}
                axisLine={false}
                tickLine={false}
              />
              <YAxis
                allowDecimals={false}
                tick={{ fontSize: 12, fill: '#9ca3af' }}
                axisLine={false}
                tickLine={false}
              />
              <Tooltip
                contentStyle={{
                  borderRadius: '8px',
                  border: '1px solid #e5e7eb',
                  fontSize: '12px',
                }}
                labelStyle={{ fontWeight: 600, color: '#1A1A2E' }}
              />
              <Legend
                iconType="circle"
                iconSize={8}
                wrapperStyle={{ fontSize: '12px', paddingTop: '12px' }}
              />
              <Bar dataKey="preventivos" name="Preventivo" stackId="a" fill="#3b82f6" />
              <Bar dataKey="correctivos" name="Correctivo" stackId="a" fill="#ef4444" />
              <Bar
                dataKey="diagnosticos"
                name="Diagnóstico"
                stackId="a"
                fill="#f59e0b"
                radius={[4, 4, 0, 0]}
              />
            </BarChart>
          </ResponsiveContainer>
        )}
      </div>

      {/* Impresoras + Pólizas row */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">

        {/* Impresoras en atención */}
        <div className="bg-white rounded-xl border border-border shadow-sm overflow-hidden">
          <div className="flex items-center gap-2 px-5 py-4 border-b border-border">
            <Printer size={16} className="text-red-500" />
            <h3 className="text-sm font-semibold text-[#1A1A2E] font-heading">
              Impresoras en atención
            </h3>
          </div>

          {printersAttention.isLoading ? (
            <div className="p-5 space-y-2">
              {[1, 2, 3].map(i => (
                <div key={i} className="h-10 rounded bg-gray-100 animate-pulse" />
              ))}
            </div>
          ) : printersData.length === 0 ? (
            <div className="flex flex-col items-center gap-2 py-10 px-5 text-center">
              <CheckCircle size={28} className="text-green-500" />
              <p className="text-sm text-gray-400 font-sans">Todas las impresoras OK</p>
            </div>
          ) : (
            <ul className="divide-y divide-gray-50">
              {printersData.map(p => (
                <li key={p.id}>
                  <Link
                    to={`/printers/${p.id}`}
                    className="flex items-start gap-3 px-5 py-3.5 hover:bg-gray-50/60 transition-colors"
                  >
                    <AlertTriangle size={16} className="text-red-400 mt-0.5 shrink-0" />
                    <div className="min-w-0 flex-1">
                      <p className="text-sm font-medium text-[#1A1A2E] font-sans truncate">
                        {p.serial_number}
                        {p.model_name && (
                          <span className="text-gray-400 font-normal"> · {p.model_name}</span>
                        )}
                      </p>
                      {p.client_name && (
                        <p className="text-xs text-gray-400 font-sans truncate">{p.client_name}</p>
                      )}
                      <div className="flex flex-wrap gap-1 mt-1">
                        {p.advertencias.map(adv => (
                          <span
                            key={adv}
                            className="inline-block px-1.5 py-0.5 rounded text-[10px] font-medium bg-red-50 text-red-600 border border-red-100"
                          >
                            {adv}
                          </span>
                        ))}
                      </div>
                    </div>
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </div>

        {/* Pólizas próximas a vencer */}
        <div className="bg-white rounded-xl border border-border shadow-sm overflow-hidden">
          <div className="flex items-center gap-2 px-5 py-4 border-b border-border">
            <ShieldAlert size={16} className="text-amber-500" />
            <h3 className="text-sm font-semibold text-[#1A1A2E] font-heading">
              Pólizas próximas a vencer
            </h3>
          </div>

          {policiesExpiring.isLoading ? (
            <div className="p-5 space-y-2">
              {[1, 2, 3].map(i => (
                <div key={i} className="h-10 rounded bg-gray-100 animate-pulse" />
              ))}
            </div>
          ) : policiesData.length === 0 ? (
            <div className="px-5 py-10 text-center text-sm text-gray-400 font-sans">
              Sin pólizas por vencer pronto.
            </div>
          ) : (
            <ul className="divide-y divide-gray-50">
              {policiesData.map(p => (
                <li key={p.id}>
                  <Link
                    to={`/policies/${p.id}`}
                    className="flex items-center gap-3 px-5 py-3.5 hover:bg-gray-50/60 transition-colors"
                  >
                    <div className="min-w-0 flex-1">
                      <p className="text-sm font-medium text-[#1A1A2E] font-sans">{p.folio}</p>
                      <p className="text-xs text-gray-400 font-sans truncate">{p.client_name}</p>
                    </div>
                    <span
                      className={`shrink-0 inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium border ${
                        p.dias_restantes <= 7
                          ? 'bg-red-50 text-red-600 border-red-200'
                          : 'bg-amber-50 text-amber-700 border-amber-200'
                      }`}
                    >
                      {p.dias_restantes}d
                    </span>
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </div>
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
        ) : syncData.length === 0 ? (
          <div className="px-5 py-10 text-center text-sm text-gray-400 font-sans">
            Sin registros de sincronización aún.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="bg-gray-50 text-left">
                  {['Fecha', 'Tipo', 'Acción', 'Técnico', 'Detalle', 'Estado'].map(col => (
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
                {syncData.map(row => (
                  <tr key={row.id} className="hover:bg-gray-50/60 transition-colors">
                    <td className="px-5 py-3 text-gray-500 font-sans whitespace-nowrap">
                      {formatDatetime(row.synced_at)}
                    </td>
                    <td className="px-5 py-3">
                      <EntityTypeBadge type={row.entity_type} />
                    </td>
                    <td className="px-5 py-3 text-gray-600 font-sans">
                      {translateAction(row.action)}
                    </td>
                    <td className="px-5 py-3 text-gray-600 font-sans">
                      {row.tech_name ?? '—'}
                    </td>
                    <td className="px-5 py-3 text-gray-500 font-sans font-mono text-xs">
                      {row.detalle ?? '—'}
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
