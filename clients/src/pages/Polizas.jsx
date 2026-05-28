import { useQuery } from '@tanstack/react-query'
import { ShieldCheck } from 'lucide-react'
import apiClient from '@/api/axios'
import StatusBadge from '@/components/StatusBadge'
import { SkeletonCard } from '@/components/Skeleton'
import EmptyState from '@/components/EmptyState'

function fmtDate(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString('es-MX', { day: 'numeric', month: 'short', year: 'numeric' })
}

export default function Polizas() {
  const { data: policies = [], isLoading, error } = useQuery({
    queryKey: ['portal', 'policies'],
    queryFn: async () => {
      const res = await apiClient.get('/api/portal/policies')
      return res.data
    },
    staleTime: 60_000,
  })

  return (
    <div className="space-y-5">
      <div>
        <h2 className="text-xl font-bold text-[#1A1A2E] font-heading">Mis Pólizas</h2>
        {!isLoading && (
          <p className="text-sm text-gray-400 font-sans mt-0.5">
            {policies.length} póliza{policies.length !== 1 ? 's' : ''} activa{policies.length !== 1 ? 's' : ''}
          </p>
        )}
      </div>

      {error && (
        <p className="text-sm text-red-600" role="alert">Error al cargar las pólizas. Intenta recargar.</p>
      )}

      {isLoading ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {Array.from({ length: 3 }).map((_, i) => <SkeletonCard key={i} />)}
        </div>
      ) : policies.length === 0 ? (
        <EmptyState message="No tienes pólizas activas" icon={ShieldCheck} />
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {policies.map(p => (
            <div key={p.id} className="bg-white rounded-xl border border-border shadow-sm p-5">
              <div className="flex items-start justify-between gap-2 mb-3">
                <div className="w-9 h-9 rounded-lg bg-emerald-50 flex items-center justify-center shrink-0">
                  <ShieldCheck size={17} className="text-emerald-600" />
                </div>
                {/* Endpoint only returns active policies — always show Activa */}
                <StatusBadge status="activa" />
              </div>

              <p className="font-mono text-sm font-semibold text-[#1A1A2E] truncate">{p.folio}</p>
              {p.coverage_type && (
                <p className="text-xs text-gray-500 font-sans mt-0.5">{p.coverage_type}</p>
              )}

              <div className="mt-3 space-y-1.5">
                <p className="text-xs text-gray-400 font-sans">
                  {fmtDate(p.start_date)} → {fmtDate(p.end_date)}
                </p>
                {p.frequency_maintenance && (
                  <p className="text-xs text-gray-400 font-sans">
                    Mantenimiento: {p.frequency_maintenance}
                  </p>
                )}
                {p.sla_notes && (
                  <p className="text-xs text-gray-400 font-sans line-clamp-2">{p.sla_notes}</p>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
