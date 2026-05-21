import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { Building2, Search, RotateCcw, ChevronLeft, ChevronRight, Plus, Pencil, Trash2, X, AlertTriangle } from 'lucide-react'
import apiClient from '@/api/client'
import { API } from '@/api/endpoints'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface ClientListItem {
  id: string
  name: string
  rfc: string | null
  address: string | null
  is_active: boolean
  plant_count: number
  printer_count: number
  active_policy_count: number
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

const PAGE_SIZE = 20

function CountChip({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium font-sans border ${color}`}>
      <span className="font-bold">{value}</span>
      <span className="text-[10px]">{label}</span>
    </span>
  )
}

// ---------------------------------------------------------------------------
// Client modal (create / edit)
// ---------------------------------------------------------------------------

interface ClientFormData {
  name: string
  rfc: string
  address: string
}

interface ClientModalProps {
  client?: ClientListItem | null
  onClose: () => void
}

function ClientModal({ client, onClose }: ClientModalProps) {
  const qc = useQueryClient()
  const isEdit = !!client

  const [form, setForm] = useState<ClientFormData>({
    name: client?.name ?? '',
    rfc: client?.rfc ?? '',
    address: client?.address ?? '',
  })
  const [error, setError] = useState<string | null>(null)

  const saveMutation = useMutation({
    mutationFn: async () => {
      const payload = {
        name: form.name,
        rfc: form.rfc || null,
        address: form.address || null,
      }
      if (isEdit) {
        await apiClient.put(API.clients.detail(client!.id), payload)
      } else {
        await apiClient.post(API.clients.create, payload)
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['clients'] })
      onClose()
    },
    onError: (err: unknown) => {
      const msg = (err as { response?: { data?: { detail?: string } } })?.response?.data?.detail
      setError(msg ?? 'Error al guardar.')
    },
  })

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError(null)
    if (!form.name.trim()) { setError('El nombre es obligatorio.'); return }
    saveMutation.mutate()
  }

  const inputCls = 'w-full text-sm font-sans border border-border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition-colors'
  const labelCls = 'block text-xs font-semibold text-gray-500 font-sans mb-1'

  return (
    <>
      <div className="fixed inset-0 bg-black/40 z-40" onClick={onClose} />
      <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div className="bg-white rounded-xl shadow-2xl w-full max-w-md flex flex-col">
          <div className="flex items-center justify-between px-6 py-4 border-b border-border">
            <div className="flex items-center gap-2">
              <Building2 size={16} className="text-primary" />
              <h3 className="font-semibold text-[#1A1A2E] font-heading">
                {isEdit ? 'Editar cliente' : 'Nuevo cliente'}
              </h3>
            </div>
            <button onClick={onClose} className="p-1.5 rounded-lg text-gray-400 hover:text-gray-700 hover:bg-gray-100 transition-colors">
              <X size={18} />
            </button>
          </div>

          <form onSubmit={handleSubmit}>
            <div className="px-6 py-5 space-y-4">
              <div>
                <label className={labelCls}>Nombre *</label>
                <input type="text" value={form.name} onChange={(e) => setForm((p) => ({ ...p, name: e.target.value }))} className={inputCls} placeholder="Empresa S.A. de C.V." />
              </div>
              <div>
                <label className={labelCls}>RFC</label>
                <input type="text" value={form.rfc} onChange={(e) => setForm((p) => ({ ...p, rfc: e.target.value.toUpperCase() }))} className={inputCls} placeholder="EMP960101ABC" />
              </div>
              <div>
                <label className={labelCls}>Dirección</label>
                <textarea value={form.address} onChange={(e) => setForm((p) => ({ ...p, address: e.target.value }))} rows={2} className={`${inputCls} resize-none`} placeholder="Calle, colonia, ciudad…" />
              </div>

              {error && (
                <div className="flex items-center gap-2 bg-red-50 border border-red-200 rounded-lg px-3 py-2.5">
                  <AlertTriangle size={14} className="text-red-500 shrink-0" />
                  <p className="text-sm text-red-600 font-sans">{error}</p>
                </div>
              )}
            </div>

            <div className="px-6 py-4 border-t border-border bg-gray-50 flex gap-2 justify-end">
              <button type="button" onClick={onClose} className="px-4 py-2 text-sm font-semibold text-gray-600 font-sans rounded-lg hover:bg-gray-100 transition-colors">Cancelar</button>
              <button type="submit" disabled={saveMutation.isPending} className="px-5 py-2 text-sm font-semibold text-white bg-primary hover:bg-primary-dark disabled:opacity-50 rounded-lg transition-colors font-sans">
                {saveMutation.isPending ? 'Guardando…' : isEdit ? 'Guardar cambios' : 'Crear cliente'}
              </button>
            </div>
          </form>
        </div>
      </div>
    </>
  )
}

// ---------------------------------------------------------------------------
// Delete confirm
// ---------------------------------------------------------------------------

function DeleteClientModal({ client, onClose }: { client: ClientListItem; onClose: () => void }) {
  const qc = useQueryClient()
  const deleteMutation = useMutation({
    mutationFn: async () => apiClient.delete(API.clients.detail(client.id)),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['clients'] }); onClose() },
  })

  return (
    <>
      <div className="fixed inset-0 bg-black/40 z-40" onClick={onClose} />
      <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div className="bg-white rounded-xl shadow-2xl w-full max-w-sm p-6">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 rounded-full bg-red-50 flex items-center justify-center shrink-0">
              <AlertTriangle size={18} className="text-red-500" />
            </div>
            <div>
              <h3 className="font-semibold text-[#1A1A2E] font-heading">Desactivar cliente</h3>
              <p className="text-sm text-gray-400 font-sans">El cliente quedará inactivo.</p>
            </div>
          </div>
          <p className="text-sm text-gray-600 font-sans mb-5">
            ¿Desactivar a <span className="font-semibold">{client.name}</span>?
          </p>
          <div className="flex gap-2 justify-end">
            <button onClick={onClose} className="px-4 py-2 text-sm font-semibold text-gray-600 font-sans rounded-lg hover:bg-gray-100 transition-colors">Cancelar</button>
            <button onClick={() => deleteMutation.mutate()} disabled={deleteMutation.isPending} className="px-4 py-2 text-sm font-semibold text-white bg-red-500 hover:bg-red-600 disabled:opacity-50 rounded-lg transition-colors font-sans">
              {deleteMutation.isPending ? 'Desactivando…' : 'Desactivar'}
            </button>
          </div>
        </div>
      </div>
    </>
  )
}

// ---------------------------------------------------------------------------
// Main page
// ---------------------------------------------------------------------------

export default function ClientsPage() {
  const navigate = useNavigate()
  const [search, setSearch] = useState('')
  const [debouncedSearch, setDebouncedSearch] = useState('')
  const [page, setPage] = useState(0)
  const [debounceTimer, setDebounceTimer] = useState<ReturnType<typeof setTimeout> | null>(null)
  const [showCreate, setShowCreate] = useState(false)
  const [editClient, setEditClient] = useState<ClientListItem | null>(null)
  const [deleteClient, setDeleteClient] = useState<ClientListItem | null>(null)

  function handleSearch(value: string) {
    setSearch(value)
    if (debounceTimer) clearTimeout(debounceTimer)
    const t = setTimeout(() => { setDebouncedSearch(value); setPage(0) }, 350)
    setDebounceTimer(t)
  }

  function clearSearch() {
    setSearch('')
    setDebouncedSearch('')
    setPage(0)
  }

  const queryParams = {
    limit: PAGE_SIZE,
    offset: page * PAGE_SIZE,
    ...(debouncedSearch && { search: debouncedSearch }),
  }

  const { data, isLoading, isFetching } = useQuery({
    queryKey: ['clients', queryParams],
    queryFn: async () => {
      const res = await apiClient.get<PagedResponse<ClientListItem>>(API.clients.list, { params: queryParams })
      return res.data
    },
    placeholderData: (prev) => prev,
    retry: false,
  })

  const total = data?.total ?? 0
  const items = data?.items ?? []
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE))

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h2 className="text-xl font-bold text-[#1A1A2E] font-heading">Clientes</h2>
          <p className="text-sm text-gray-400 font-sans mt-0.5">
            {isFetching ? 'Actualizando…' : `${total} cliente${total !== 1 ? 's' : ''}`}
          </p>
        </div>
        <div className="flex items-center gap-3 flex-wrap">
          {/* Search */}
          <div className="relative w-full sm:w-64">
            <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
            <input
              type="text"
              value={search}
              onChange={(e) => handleSearch(e.target.value)}
              placeholder="Buscar por nombre o RFC…"
              className="w-full pl-8 pr-8 py-2 text-sm font-sans border border-border rounded-lg bg-white text-gray-700 focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition-colors"
            />
            {search && (
              <button onClick={clearSearch} className="absolute right-2.5 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
                <RotateCcw size={13} />
              </button>
            )}
          </div>
          <button
            onClick={() => setShowCreate(true)}
            className="flex items-center gap-2 bg-primary hover:bg-primary-dark text-white text-sm font-semibold font-sans rounded-lg px-4 py-2 transition-colors"
          >
            <Plus size={15} />
            Nuevo cliente
          </button>
        </div>
      </div>

      {/* Table */}
      <div className="bg-white rounded-xl border border-border shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-gray-50 border-b border-border text-left">
                {['Cliente', 'RFC', 'Dirección', 'Cobertura', 'Estado', ''].map((h) => (
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
                    {Array.from({ length: 6 }).map((_, j) => (
                      <td key={j} className="px-4 py-3.5">
                        <div className="h-4 bg-gray-100 rounded" style={{ width: `${50 + ((i + j) % 3) * 20}%` }} />
                      </td>
                    ))}
                  </tr>
                ))
              ) : items.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-4 py-12 text-center text-sm text-gray-400 font-sans">
                    {debouncedSearch ? 'No se encontraron clientes con ese criterio.' : 'No hay clientes registrados.'}
                  </td>
                </tr>
              ) : (
                items.map((row) => (
                  <tr
                    key={row.id}
                    onClick={() => navigate(`/clients/${row.id}`)}
                    className="hover:bg-gray-50/60 transition-colors group cursor-pointer"
                  >
                    <td className="px-4 py-3.5">
                      <div className="flex items-center gap-2.5">
                        <div className="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center shrink-0">
                          <Building2 size={15} className="text-primary" />
                        </div>
                        <span className="font-semibold text-[#1A1A2E] font-sans">{row.name}</span>
                      </div>
                    </td>
                    <td className="px-4 py-3.5 font-mono text-xs text-gray-500">
                      {row.rfc ?? '—'}
                    </td>
                    <td className="px-4 py-3.5 text-gray-500 font-sans max-w-[200px] truncate">
                      {row.address ?? '—'}
                    </td>
                    <td className="px-4 py-3.5">
                      <div className="flex flex-wrap gap-1.5">
                        <CountChip label="plantas" value={row.plant_count} color="bg-sky-50 text-sky-700 border-sky-200" />
                        <CountChip label="impresoras" value={row.printer_count} color="bg-violet-50 text-violet-700 border-violet-200" />
                        <CountChip label="pólizas" value={row.active_policy_count} color="bg-emerald-50 text-emerald-700 border-emerald-200" />
                      </div>
                    </td>
                    <td className="px-4 py-3.5">
                      <span className={`inline-flex items-center px-2 py-0.5 rounded-full border text-xs font-medium font-sans ${
                        row.is_active
                          ? 'bg-green-50 text-green-700 border-green-200'
                          : 'bg-gray-100 text-gray-500 border-gray-200'
                      }`}>
                        {row.is_active ? 'Activo' : 'Inactivo'}
                      </span>
                    </td>
                    <td className="px-4 py-3.5">
                      <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                        <button
                          onClick={(e) => { e.stopPropagation(); setEditClient(row) }}
                          className="p-1.5 rounded-lg text-gray-400 hover:text-primary hover:bg-primary/10 transition-colors"
                          title="Editar"
                        >
                          <Pencil size={14} />
                        </button>
                        <button
                          onClick={(e) => { e.stopPropagation(); setDeleteClient(row) }}
                          className="p-1.5 rounded-lg text-gray-400 hover:text-red-500 hover:bg-red-50 transition-colors"
                          title="Desactivar"
                        >
                          <Trash2 size={14} />
                        </button>
                      </div>
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

      {showCreate && <ClientModal onClose={() => setShowCreate(false)} />}
      {editClient && <ClientModal client={editClient} onClose={() => setEditClient(null)} />}
      {deleteClient && <DeleteClientModal client={deleteClient} onClose={() => setDeleteClient(null)} />}
    </div>
  )
}
