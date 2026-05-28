import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import api from '../api/axios'
import StatusBadge from '../components/StatusBadge'
import Skeleton from '../components/Skeleton'
import EmptyState from '../components/EmptyState'

const PrinterIcon = ({ className }) => (
  <svg className={className} fill="none" stroke="currentColor" strokeWidth={1.6} viewBox="0 0 24 24" aria-hidden="true">
    <path d="M6 9V4a1 1 0 011-1h10a1 1 0 011 1v5M6 18H4a1 1 0 01-1-1v-6a1 1 0 011-1h16a1 1 0 011 1v6a1 1 0 01-1 1h-2" />
    <rect x="6" y="14" width="12" height="7" rx="1" />
    <circle cx="17.5" cy="11.5" r=".75" fill="currentColor" />
  </svg>
)

export default function Impresoras() {
  const [search, setSearch] = useState('')

  const { data: printers = [], isLoading, isError } = useQuery({
    queryKey: ['portal-printers'],
    queryFn: () => api.get('/api/portal/printers').then((r) => r.data),
  })

  const filtered = printers.filter((p) => {
    const q = search.toLowerCase()
    return (
      !q ||
      (p.serial_number || '').toLowerCase().includes(q) ||
      (p.model || '').toLowerCase().includes(q)
    )
  })

  return (
    <div className="space-y-6">

      {/* Page header */}
      <div>
        <h2 className="text-xl font-bold text-[#1A1A2E] font-heading">Impresoras</h2>
        <p className="text-sm text-gray-400 font-sans mt-0.5">Equipos registrados en su contrato de servicio</p>
      </div>

      {/* Search bar */}
      <div className="flex flex-col sm:flex-row sm:items-center gap-3">
        <div className="relative flex-1">
          <svg
            className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400"
            fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24"
          >
            <path d="M21 21l-4.35-4.35M17 11A6 6 0 111 11a6 6 0 0116 0z" />
          </svg>
          <input
            id="impresoras-search"
            type="search"
            className="input pl-10"
            placeholder="Buscar por número de serie o modelo…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
        <p className="text-sm text-gray-500 font-sans flex-shrink-0">
          {filtered.length} impresora{filtered.length !== 1 ? 's' : ''}
        </p>
      </div>

      {/* Grid */}
      {isLoading ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          {Array.from({ length: 8 }).map((_, i) => <Skeleton.Card key={i} />)}
        </div>
      ) : isError ? (
        <EmptyState
          title="Error al cargar impresoras"
          description="No se pudo obtener la lista. Intente de nuevo más tarde."
        />
      ) : filtered.length === 0 ? (
        <EmptyState
          icon={PrinterIcon}
          title="Sin impresoras"
          description={search ? 'No se encontraron resultados para su búsqueda.' : 'No tiene impresoras registradas.'}
        />
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          {filtered.map((p) => (
            <Link
              key={p.id}
              to={`/impresoras/${p.id}`}
              className="bg-white rounded-xl border border-border shadow-sm p-5 flex flex-col gap-3
                         hover:shadow-md hover:-translate-y-0.5 transition-all duration-200 group"
            >
              {/* Header */}
              <div className="flex items-start justify-between">
                <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/10 text-primary group-hover:bg-primary group-hover:text-white transition-colors">
                  <PrinterIcon className="h-5 w-5" />
                </div>
                <StatusBadge status={p.status || p.estado} />
              </div>

              {/* Info */}
              <div className="min-w-0">
                <p className="font-semibold text-[#1A1A2E] text-sm truncate font-sans">{p.serial_number || '—'}</p>
                <p className="text-xs text-gray-500 truncate mt-0.5 font-sans">{p.model || p.modelo || '—'}</p>
              </div>

              {/* Footer */}
              <div className="mt-auto flex flex-col gap-0.5 border-t border-border pt-3">
                <p className="text-xs text-gray-400 font-sans">
                  <span className="font-medium text-gray-600">Planta:</span> {p.plant || p.planta || '—'}
                </p>
                <p className="text-xs text-gray-400 font-sans">
                  <span className="font-medium text-gray-600">Área:</span> {p.area || '—'}
                </p>
              </div>
            </Link>
          ))}
        </div>
      )}
    </div>
  )
}
