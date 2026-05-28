import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { useNavigate } from 'react-router-dom'
import { Search, Printer } from 'lucide-react'
import apiClient from '@/api/axios'
import StatusBadge from '@/components/StatusBadge'
import { SkeletonCard } from '@/components/Skeleton'
import EmptyState from '@/components/EmptyState'

function fmtDate(iso) {
  if (!iso) return null
  return new Date(iso).toLocaleDateString('es-MX', { day: 'numeric', month: 'short', year: 'numeric' })
}

export default function Impresoras() {
  const navigate = useNavigate()
  const [search, setSearch] = useState('')

  const { data: printers = [], isLoading, error } = useQuery({
    queryKey: ['portal', 'printers'],
    queryFn: async () => {
      const res = await apiClient.get('/api/portal/printers')
      return res.data
    },
    staleTime: 60_000,
  })

  const filtered = printers.filter(p => {
    const q = search.toLowerCase()
    return (
      (p.serial_number ?? '').toLowerCase().includes(q) ||
      (p.model_name ?? '').toLowerCase().includes(q) ||
      (p.model_brand ?? '').toLowerCase().includes(q)
    )
  })

  return (
    <div className="space-y-5">
      <div>
        <h2 className="text-xl font-bold text-[#1A1A2E] font-heading">Mis Impresoras</h2>
        <p className="text-sm text-gray-400 font-sans mt-0.5">
          {isLoading ? '…' : `${printers.length} impresora${printers.length !== 1 ? 's' : ''} registrada${printers.length !== 1 ? 's' : ''}`}
        </p>
      </div>

      {/* Search */}
      <div className="relative max-w-sm">
        <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" aria-hidden="true" />
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Buscar por serie o modelo…"
          className="w-full pl-9 pr-3 py-2.5 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-primary bg-white"
        />
      </div>

      {error && (
        <p className="text-sm text-red-600" role="alert">
          Error al cargar las impresoras. Intenta recargar la página.
        </p>
      )}

      {isLoading ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {Array.from({ length: 6 }).map((_, i) => <SkeletonCard key={i} />)}
        </div>
      ) : filtered.length === 0 ? (
        <EmptyState
          message={search ? 'Sin resultados para tu búsqueda' : 'No tienes impresoras registradas'}
          icon={Printer}
        />
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {filtered.map(p => (
            <button
              key={p.id}
              onClick={() => navigate(`/impresoras/${p.id}`)}
              className="text-left bg-white rounded-xl border border-border shadow-sm p-5 hover:shadow-md hover:border-primary/30 transition-all cursor-pointer"
            >
              <div className="flex items-start justify-between gap-2 mb-3">
                <div className="w-9 h-9 rounded-lg bg-primary/10 flex items-center justify-center shrink-0">
                  <Printer size={17} className="text-primary" aria-hidden="true" />
                </div>
                <StatusBadge status={p.is_active ? 'activo' : 'inactivo'} />
              </div>
              <p className="font-mono text-sm font-semibold text-[#1A1A2E] truncate">{p.serial_number}</p>
              {(p.model_brand || p.model_name) && (
                <p className="text-xs text-gray-500 font-sans mt-0.5 truncate">
                  {[p.model_brand, p.model_name].filter(Boolean).join(' ')}
                </p>
              )}
              <div className="mt-3 space-y-1">
                {p.plant_name && (
                  <p className="text-xs text-gray-400 font-sans truncate">Planta: {p.plant_name}</p>
                )}
                {p.area_name && (
                  <p className="text-xs text-gray-400 font-sans truncate">Área: {p.area_name}</p>
                )}
                {p.last_service_date && (
                  <p className="text-xs text-gray-400 font-sans">
                    Último servicio: {fmtDate(p.last_service_date)}
                  </p>
                )}
              </div>
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
