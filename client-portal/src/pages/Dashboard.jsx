import { useQuery } from '@tanstack/react-query'
import {
  LineChart, Line, BarChart, Bar,
  XAxis, YAxis, CartesianGrid, Tooltip, Legend,
  ResponsiveContainer, PieChart, Pie, Cell,
} from 'recharts'
import { Link } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import api from '../api/axios'
import StatusBadge from '../components/StatusBadge'
import Skeleton from '../components/Skeleton'
import EmptyState from '../components/EmptyState'

// ── Normalize paginated-or-plain-array API responses ─────────────────────────
function normalizeList(raw) {
  if (!raw) return []
  if (Array.isArray(raw)) return raw
  if (Array.isArray(raw.items)) return raw.items
  if (Array.isArray(raw.data))  return raw.data
  return []
}

// ── Helpers ──────────────────────────────────────────────────────────────────
const fmtDate = (iso) =>
  iso
    ? new Date(iso).toLocaleDateString('es-MX', { day: '2-digit', month: 'short', year: 'numeric' })
    : '—'

const MONTH_LABELS = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic']

function groupByMonth(reports) {
  const now = new Date()
  const buckets = Array.from({ length: 12 }, (_, i) => {
    const d = new Date(now.getFullYear(), now.getMonth() - 11 + i, 1)
    return { month: MONTH_LABELS[d.getMonth()], year: d.getFullYear(), count: 0, key: `${d.getFullYear()}-${d.getMonth()}` }
  })
  reports.forEach((r) => {
    const d = new Date(r.service_date || r.created_at)
    const key = `${d.getFullYear()}-${d.getMonth()}`
    const bucket = buckets.find((b) => b.key === key)
    if (bucket) bucket.count++
  })
  return buckets.map(({ month, count }) => ({ month, reportes: count }))
}

function groupByType(reports) {
  const map = {}
  reports.forEach((r) => {
    const type = r.service_type || 'Otro'
    map[type] = (map[type] || 0) + 1
  })
  return Object.entries(map).map(([name, value]) => ({ name, value }))
}

const PIE_COLORS = ['#1A4FD6','#0F1B3D','#16A34A','#D97706','#DC2626','#7C3AED']

// ── KPI Card — mirrors admin-web DashboardPage KpiCard exactly ───────────────
function KpiCard({ label, value, icon, loading, accent, iconColor, borderColor, to }) {
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

// ── Printer icon ──────────────────────────────────────────────────────────────
const PrinterSVG = ({ size = 22 }) => (
  <svg width={size} height={size} fill="none" stroke="currentColor" strokeWidth={1.8} viewBox="0 0 24 24" aria-hidden="true">
    <path d="M6 9V4a1 1 0 011-1h10a1 1 0 011 1v5M6 18H4a1 1 0 01-1-1v-6a1 1 0 011-1h16a1 1 0 011 1v6a1 1 0 01-1 1h-2" />
    <rect x="6" y="14" width="12" height="7" rx="1" />
  </svg>
)
const PolicySVG = ({ size = 22 }) => (
  <svg width={size} height={size} fill="none" stroke="currentColor" strokeWidth={1.8} viewBox="0 0 24 24" aria-hidden="true">
    <path d="M12 2L4 6v6c0 5.25 3.5 10.15 8 11.25C16.5 22.15 20 17.25 20 12V6l-8-4z" />
    <path d="M9 12l2 2 4-4" />
  </svg>
)
const ReportSVG = ({ size = 22 }) => (
  <svg width={size} height={size} fill="none" stroke="currentColor" strokeWidth={1.8} viewBox="0 0 24 24" aria-hidden="true">
    <path d="M9 12h6M9 16h6M9 8h3M5 4h14a1 1 0 011 1v14a1 1 0 01-1 1H5a1 1 0 01-1-1V5a1 1 0 011-1z" />
  </svg>
)

// ── Dashboard ─────────────────────────────────────────────────────────────────
export default function Dashboard() {
  const { user } = useAuth()

  const { data: rawReports, isLoading: loadingReports } = useQuery({
    queryKey: ['portal-reports'],
    queryFn: () => api.get('/api/portal/reports').then((r) => r.data),
  })

  const { data: rawPrinters, isLoading: loadingPrinters } = useQuery({
    queryKey: ['portal-printers'],
    queryFn: () => api.get('/api/portal/printers').then((r) => r.data),
  })

  const { data: rawPolicies, isLoading: loadingPolicies } = useQuery({
    queryKey: ['portal-policies'],
    queryFn: () => api.get('/api/portal/policies').then((r) => r.data),
  })

  const reports  = normalizeList(rawReports)
  const printers = normalizeList(rawPrinters)
  const policies = normalizeList(rawPolicies)

  const lineData = groupByMonth(reports)
  const pieData  = groupByType(reports)
  const recent   = [...reports]
    .sort((a, b) => new Date(b.service_date || b.created_at) - new Date(a.service_date || a.created_at))
    .slice(0, 5)

  const activePolicies = policies.filter((p) => {
    const s = (p.status || '').toLowerCase()
    return s === 'activa' || s === 'active'
  }).length

  const thisYear    = new Date().getFullYear()
  const yearReports = reports.filter((r) =>
    new Date(r.service_date || r.created_at).getFullYear() === thisYear
  ).length

  const kpis = [
    {
      label: `Reportes en ${thisYear}`,
      value: yearReports,
      loading: loadingReports,
      icon: <ReportSVG />,
      accent: 'bg-primary/10',
      iconColor: 'text-primary',
      borderColor: 'border-primary',
      to: '/reportes',
    },
    {
      label: 'Impresoras registradas',
      value: printers.length,
      loading: loadingPrinters,
      icon: <PrinterSVG />,
      accent: 'bg-emerald-50',
      iconColor: 'text-emerald-600',
      borderColor: 'border-emerald-500',
      to: '/impresoras',
    },
    {
      label: 'Pólizas activas',
      value: activePolicies,
      loading: loadingPolicies,
      icon: <PolicySVG />,
      accent: 'bg-amber-50',
      iconColor: 'text-amber-500',
      borderColor: 'border-amber-400',
      to: '/polizas',
    },
  ]

  return (
    <div className="space-y-6">

      {/* Page header */}
      <div>
        <h2 className="text-xl font-bold text-[#1A1A2E] font-heading">Resumen general</h2>
        <p className="text-sm text-gray-400 font-sans mt-0.5">
          Bienvenido, {user?.name || 'Usuario'}
          {user?.clientName && <span> · {user.clientName}</span>}
          {user?.plantName && <span> · {user.plantName}</span>}
        </p>
      </div>

      {/* KPI grid — exact admin-web pattern */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        {kpis.map((kpi) => (
          <KpiCard key={kpi.label} {...kpi} />
        ))}
      </div>

      {/* Charts row */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">

        {/* Line chart — mirrors admin-web chart card */}
        <div className="bg-white rounded-xl border border-border shadow-sm p-5 lg:col-span-2">
          <h3 className="text-sm font-semibold text-[#1A1A2E] font-heading mb-4">
            Reportes por mes — últimos 12 meses
          </h3>
          {loadingReports ? (
            <div className="h-[200px] flex items-center justify-center">
              <div className="h-4 w-40 rounded bg-gray-100 animate-pulse" />
            </div>
          ) : (
            <ResponsiveContainer width="100%" height={200}>
              <LineChart data={lineData} margin={{ top: 4, right: 8, left: -20, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" vertical={false} />
                <XAxis dataKey="month" tick={{ fontSize: 12, fill: '#9ca3af' }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fontSize: 12, fill: '#9ca3af' }} axisLine={false} tickLine={false} allowDecimals={false} />
                <Tooltip
                  contentStyle={{ borderRadius: '8px', border: '1px solid #e5e7eb', fontSize: '12px' }}
                  labelStyle={{ fontWeight: 600, color: '#1A1A2E' }}
                />
                <Line
                  type="monotone"
                  dataKey="reportes"
                  stroke="#1A4FD6"
                  strokeWidth={2.5}
                  dot={{ r: 3, fill: '#1A4FD6' }}
                  activeDot={{ r: 5 }}
                  name="Reportes"
                />
              </LineChart>
            </ResponsiveContainer>
          )}
        </div>

        {/* Pie chart */}
        <div className="bg-white rounded-xl border border-border shadow-sm p-5">
          <h3 className="text-sm font-semibold text-[#1A1A2E] font-heading mb-4">Por tipo de servicio</h3>
          {loadingReports ? (
            <div className="h-[200px] flex items-center justify-center">
              <div className="h-4 w-40 rounded bg-gray-100 animate-pulse" />
            </div>
          ) : pieData.length === 0 ? (
            <EmptyState title="Sin datos" />
          ) : (
            <ResponsiveContainer width="100%" height={200}>
              <PieChart>
                <Pie
                  data={pieData}
                  cx="50%"
                  cy="45%"
                  outerRadius={72}
                  dataKey="value"
                  label={({ percent }) => `${(percent * 100).toFixed(0)}%`}
                  labelLine={false}
                  fontSize={11}
                >
                  {pieData.map((_, i) => (
                    <Cell key={i} fill={PIE_COLORS[i % PIE_COLORS.length]} />
                  ))}
                </Pie>
                <Legend iconSize={8} iconType="circle" wrapperStyle={{ fontSize: '12px', paddingTop: '12px' }} />
                <Tooltip
                  contentStyle={{ borderRadius: '8px', border: '1px solid #e5e7eb', fontSize: '12px' }}
                />
              </PieChart>
            </ResponsiveContainer>
          )}
        </div>
      </div>

      {/* Recent reports table — mirrors admin-web table card */}
      <div className="bg-white rounded-xl border border-border shadow-sm overflow-hidden">
        <div className="flex items-center justify-between px-5 py-4 border-b border-border">
          <h3 className="text-sm font-semibold text-[#1A1A2E] font-heading">Reportes recientes</h3>
          <Link to="/reportes" className="text-xs text-primary hover:underline font-sans">
            Ver todos →
          </Link>
        </div>

        {loadingReports ? (
          <div className="divide-y divide-gray-50">
            {Array.from({ length: 4 }).map((_, i) => (
              <div key={i} className="flex items-center gap-4 px-5 py-3.5 animate-pulse">
                <div className="h-4 w-20 rounded bg-gray-100" />
                <div className="h-4 w-14 rounded bg-gray-100" />
                <div className="h-4 w-16 rounded bg-gray-100 ml-auto" />
              </div>
            ))}
          </div>
        ) : recent.length === 0 ? (
          <div className="px-5 py-10 text-center text-sm text-gray-400 font-sans">
            Sin reportes registrados aún.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="bg-gray-50 text-left">
                  {['Serie', 'Tipo', 'Fecha', 'Estado'].map((col) => (
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
                {recent.map((r) => (
                  <tr key={r.id} className="hover:bg-gray-50/60 transition-colors">
                    <td className="px-5 py-3 font-medium text-[#1A1A2E] font-sans">
                      <Link to={`/reportes/${r.id}`} className="hover:text-primary">
                        {String(r.printer_serial ?? '—')}
                      </Link>
                    </td>
                    <td className="px-5 py-3 text-gray-600 font-sans">{String(r.service_type ?? '—')}</td>
                    <td className="px-5 py-3 text-gray-500 font-sans whitespace-nowrap">
                      {fmtDate(r.service_date || r.created_at)}
                    </td>
                    <td className="px-5 py-3">
                      <StatusBadge status={r.status} />
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
