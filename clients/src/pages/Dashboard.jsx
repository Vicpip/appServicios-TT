import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import { Printer, FileText, ShieldCheck } from 'lucide-react'
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
  Legend,
} from 'recharts'
import apiClient from '@/api/axios'
import { useAuth } from '@/hooks/useAuth'
import StatusBadge from '@/components/StatusBadge'
import { SkeletonLine, SkeletonTable } from '@/components/Skeleton'
import EmptyState from '@/components/EmptyState'

const MONTH_LABELS = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic']
const PIE_COLORS = ['#1A4FD6', '#10b981', '#ef4444', '#8b5cf6', '#06b6d4', '#f59e0b']
const PIE_COLOR_OVERRIDES = { Correctivo: '#F97316' }

function fmtDate(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString('es-MX', { day: 'numeric', month: 'short', year: 'numeric' })
}

function buildMonthlyData(reports) {
  const now = new Date()
  const months = []
  for (let i = 11; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1)
    months.push({ year: d.getFullYear(), month: d.getMonth(), label: MONTH_LABELS[d.getMonth()], total: 0 })
  }
  for (const r of reports) {
    const d = new Date(r.service_date)
    const m = months.find(x => x.year === d.getFullYear() && x.month === d.getMonth())
    if (m) m.total++
  }
  return months
}

function buildPieData(reports) {
  const counts = {}
  for (const r of reports) {
    const key = r.service_type ?? 'Sin tipo'
    counts[key] = (counts[key] ?? 0) + 1
  }
  return Object.entries(counts).map(([name, value]) => ({ name, value }))
}

function KpiCard({ label, value, icon: Icon, loading, accent, iconColor, borderColor, to }) {
  return (
    <Link
      to={to}
      className={`bg-white rounded-xl p-5 border-l-4 shadow-sm flex items-center gap-4 hover:shadow-md transition-shadow ${borderColor}`}
    >
      <div className={`shrink-0 w-12 h-12 rounded-xl flex items-center justify-center ${accent}`}>
        <Icon size={22} className={iconColor} aria-hidden="true" />
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

export default function Dashboard() {
  const { user } = useAuth()

  const { data: printers = [], isLoading: loadingPrinters } = useQuery({
    queryKey: ['portal', 'printers'],
    queryFn: async () => {
      const res = await apiClient.get('/api/portal/printers')
      return res.data
    },
    staleTime: 60_000,
  })

  const { data: policies = [], isLoading: loadingPolicies } = useQuery({
    queryKey: ['portal', 'policies'],
    queryFn: async () => {
      const res = await apiClient.get('/api/portal/policies')
      return res.data
    },
    staleTime: 60_000,
  })

  const { data: allReports = [], isLoading: loadingReports } = useQuery({
    queryKey: ['portal', 'reports-all'],
    queryFn: async () => {
      const res = await apiClient.get('/api/portal/reports', { params: { limit: 100, offset: 0 } })
      return res.data.items ?? []
    },
    staleTime: 60_000,
  })

  const { data: recentReports = [], isLoading: loadingRecent } = useQuery({
    queryKey: ['portal', 'reports-recent'],
    queryFn: async () => {
      const res = await apiClient.get('/api/portal/reports', { params: { limit: 5, offset: 0 } })
      return res.data.items ?? []
    },
    staleTime: 60_000,
  })

  const currentYear = new Date().getFullYear()
  const reportsThisYear = allReports.filter(r => new Date(r.service_date).getFullYear() === currentYear).length

  const monthlyData = buildMonthlyData(allReports)
  const pieData = buildPieData(allReports)

  const kpis = [
    {
      label: 'Mis impresoras',
      value: printers.length,
      loading: loadingPrinters,
      icon: Printer,
      accent: 'bg-primary/10',
      iconColor: 'text-primary',
      borderColor: 'border-primary',
      to: '/impresoras',
    },
    {
      label: 'Pólizas activas',
      value: policies.length,
      loading: loadingPolicies,
      icon: ShieldCheck,
      accent: 'bg-emerald-50',
      iconColor: 'text-emerald-600',
      borderColor: 'border-emerald-500',
      to: '/polizas',
    },
    {
      label: `Reportes ${currentYear}`,
      value: reportsThisYear,
      loading: loadingReports,
      icon: FileText,
      accent: 'bg-amber-50',
      iconColor: 'text-amber-500',
      borderColor: 'border-amber-400',
      to: '/reportes',
    },
  ]

  return (
    <div className="space-y-6">
      {/* Welcome banner */}
      <div>
        <h2 className="text-xl font-bold text-[#1A1A2E] font-heading">
          Bienvenido, {user?.name ?? ''}
        </h2>
        <p className="text-sm text-gray-400 font-sans mt-0.5">
          {user?.client_name ?? ''}
          {user?.plant_name ? ` · ${user.plant_name}` : ''}
          {' · '}
          {new Date().toLocaleDateString('es-MX', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}
        </p>
      </div>

      {/* KPIs */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        {kpis.map(kpi => <KpiCard key={kpi.label} {...kpi} />)}
      </div>

      {/* Charts row */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* Line chart */}
        <div className="lg:col-span-2 bg-white rounded-xl border border-border shadow-sm p-5">
          <h3 className="text-sm font-semibold text-[#1A1A2E] font-heading mb-4">
            Reportes por mes — últimos 12 meses
          </h3>
          {loadingReports ? (
            <div className="h-[200px] flex items-center justify-center">
              <div className="h-4 w-40 rounded bg-gray-100 animate-pulse" />
            </div>
          ) : (
            <ResponsiveContainer width="100%" height={200}>
              <LineChart data={monthlyData} margin={{ top: 0, right: 0, left: -20, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" vertical={false} />
                <XAxis
                  dataKey="label"
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
                  contentStyle={{ borderRadius: '8px', border: '1px solid #e5e7eb', fontSize: '12px' }}
                  labelStyle={{ fontWeight: 600, color: '#1A1A2E' }}
                />
                <Line
                  type="monotone"
                  dataKey="total"
                  name="Reportes"
                  stroke="#1A4FD6"
                  strokeWidth={2}
                  dot={{ r: 3, fill: '#1A4FD6' }}
                  activeDot={{ r: 5 }}
                />
              </LineChart>
            </ResponsiveContainer>
          )}
        </div>

        {/* Pie chart */}
        <div className="bg-white rounded-xl border border-border shadow-sm p-5">
          <h3 className="text-sm font-semibold text-[#1A1A2E] font-heading mb-4">
            Por tipo de servicio
          </h3>
          {loadingReports ? (
            <div className="h-[200px] flex items-center justify-center">
              <div className="h-4 w-32 rounded bg-gray-100 animate-pulse" />
            </div>
          ) : pieData.length === 0 ? (
            <div className="h-[200px] flex items-center justify-center">
              <p className="text-sm text-gray-400">Sin datos</p>
            </div>
          ) : (
            <ResponsiveContainer width="100%" height={200}>
              <PieChart>
                <Pie
                  data={pieData}
                  cx="50%"
                  cy="50%"
                  innerRadius={50}
                  outerRadius={75}
                  paddingAngle={3}
                  dataKey="value"
                >
                  {pieData.map((entry, index) => (
                    <Cell key={index} fill={PIE_COLOR_OVERRIDES[entry.name] ?? PIE_COLORS[index % PIE_COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip
                  contentStyle={{ borderRadius: '8px', border: '1px solid #e5e7eb', fontSize: '12px' }}
                />
                <Legend
                  iconType="circle"
                  iconSize={8}
                  wrapperStyle={{ fontSize: '11px', paddingTop: '8px' }}
                />
              </PieChart>
            </ResponsiveContainer>
          )}
        </div>
      </div>

      {/* Recent reports */}
      <div className="bg-white rounded-xl border border-border shadow-sm overflow-hidden">
        <div className="flex items-center justify-between px-5 py-4 border-b border-border">
          <div className="flex items-center gap-2">
            <FileText size={16} className="text-primary" />
            <h3 className="text-sm font-semibold text-[#1A1A2E] font-heading">Reportes recientes</h3>
          </div>
          <Link to="/reportes" className="text-xs text-primary hover:underline font-sans">Ver todos</Link>
        </div>

        {loadingRecent ? (
          <SkeletonTable rows={5} cols={5} />
        ) : recentReports.length === 0 ? (
          <EmptyState message="Sin reportes aún" icon={FileText} />
        ) : (
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
                {recentReports.map(r => (
                  <tr key={r.id} className="hover:bg-gray-50/60 transition-colors">
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
        )}
      </div>
    </div>
  )
}
