import { useQuery } from '@tanstack/react-query'
import api from '../api/axios'
import StatusBadge from '../components/StatusBadge'
import Skeleton from '../components/Skeleton'
import EmptyState from '../components/EmptyState'

const fmtDate = (iso) =>
  iso
    ? new Date(iso).toLocaleDateString('es-MX', { day: '2-digit', month: 'short', year: 'numeric' })
    : '—'

const ShieldIcon = ({ className }) => (
  <svg className={className} fill="none" stroke="currentColor" strokeWidth={1.6} viewBox="0 0 24 24" aria-hidden="true">
    <path d="M12 2L4 6v6c0 5.25 3.5 10.15 8 11.25C16.5 22.15 20 17.25 20 12V6l-8-4z" />
    <path d="M9 12l2 2 4-4" />
  </svg>
)

// ── PolicyCard — mirrors admin-web PolicyDetailPage card pattern ───────────────
function PolicyCard({ policy }) {
  const status    = (policy.status || policy.estado || '').toLowerCase()
  const isActive  = status === 'activa' || status === 'active'
  const isExpired = status === 'vencida'

  const borderColor = isActive
    ? 'border-emerald-500'
    : isExpired
      ? 'border-red-500'
      : 'border-gray-300'

  return (
    <div className={`bg-white rounded-xl border-l-4 shadow-sm p-5 flex flex-col gap-4 ${borderColor}`}>

      {/* Header */}
      <div className="flex items-start justify-between gap-3">
        <div className="flex items-center gap-3">
          <div className={`flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-xl ${isActive ? 'bg-emerald-50 text-emerald-600' : 'bg-gray-100 text-gray-400'}`}>
            <ShieldIcon className="h-5 w-5" />
          </div>
          <div className="min-w-0">
            <p className="font-semibold text-[#1A1A2E] text-sm font-sans">
              {policy.folio || policy.code || `Póliza #${policy.id}`}
            </p>
            <p className="text-xs text-gray-500 mt-0.5 font-sans">
              {policy.coverage_type || policy.tipo_cobertura || '—'}
            </p>
          </div>
        </div>
        <StatusBadge status={policy.status || policy.estado} />
      </div>

      {/* Dates */}
      <div className="grid grid-cols-2 gap-4">
        <div>
          <p className="text-xs text-gray-400 font-medium uppercase tracking-wide font-sans">Inicio</p>
          <p className="text-sm text-gray-700 mt-0.5 font-sans">
            {fmtDate(policy.start_date || policy.fecha_inicio)}
          </p>
        </div>
        <div>
          <p className="text-xs text-gray-400 font-medium uppercase tracking-wide font-sans">Vencimiento</p>
          <p className={`text-sm mt-0.5 font-medium font-sans ${isExpired ? 'text-red-600' : 'text-gray-700'}`}>
            {fmtDate(policy.end_date || policy.fecha_vencimiento)}
          </p>
        </div>
      </div>

      {/* SLA notes */}
      {(policy.sla_notes || policy.notas_sla) && (
        <div className="rounded-lg bg-surface px-4 py-3 text-xs text-gray-600 leading-relaxed border border-border font-sans">
          {policy.sla_notes || policy.notas_sla}
        </div>
      )}
    </div>
  )
}

export default function Polizas() {
  const { data: policies = [], isLoading, isError } = useQuery({
    queryKey: ['portal-policies'],
    queryFn: () => api.get('/api/portal/policies').then((r) => r.data),
  })

  const sorted = [...policies].sort((a, b) => {
    const aActive = (a.status || a.estado) === 'activa' ? 0 : 1
    const bActive = (b.status || b.estado) === 'activa' ? 0 : 1
    if (aActive !== bActive) return aActive - bActive
    return new Date(b.start_date || b.fecha_inicio || 0) - new Date(a.start_date || a.fecha_inicio || 0)
  })

  const active  = sorted.filter((p) => {
    const s = (p.status || p.estado || '').toLowerCase()
    return s === 'activa' || s === 'active'
  }).length
  const expired = sorted.filter((p) => (p.status || p.estado || '').toLowerCase() === 'vencida').length

  return (
    <div className="space-y-6">

      {/* Page header */}
      <div>
        <h2 className="text-xl font-bold text-[#1A1A2E] font-heading">Pólizas de mantenimiento</h2>
        <p className="text-sm text-gray-400 font-sans mt-0.5">Contratos de cobertura de servicio vigentes</p>
      </div>

      {/* Summary bar — mirrors admin-web badge pattern */}
      {!isLoading && policies.length > 0 && (
        <div className="flex flex-wrap gap-3">
          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full border text-xs font-medium font-sans bg-green-50 border-green-200 text-green-700">
            <span className="h-1.5 w-1.5 rounded-full bg-emerald-500 inline-block animate-pulse" />
            {active} activa{active !== 1 ? 's' : ''}
          </span>
          {expired > 0 && (
            <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full border text-xs font-medium font-sans bg-red-50 border-red-200 text-red-600">
              <span className="h-1.5 w-1.5 rounded-full bg-red-500 inline-block" />
              {expired} vencida{expired !== 1 ? 's' : ''}
            </span>
          )}
        </div>
      )}

      {/* Cards */}
      {isLoading ? (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {[0, 1, 2].map((i) => <Skeleton.Card key={i} />)}
        </div>
      ) : isError ? (
        <EmptyState title="Error al cargar pólizas" description="Intente de nuevo más tarde." />
      ) : sorted.length === 0 ? (
        <EmptyState
          icon={ShieldIcon}
          title="Sin pólizas"
          description="No tiene pólizas de mantenimiento registradas."
        />
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {sorted.map((policy) => (
            <PolicyCard key={policy.id} policy={policy} />
          ))}
        </div>
      )}
    </div>
  )
}
