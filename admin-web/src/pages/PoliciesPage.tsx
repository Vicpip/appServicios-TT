import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  ShieldCheck, Plus, Pencil, Trash2, X, ChevronLeft, ChevronRight, AlertTriangle,
} from 'lucide-react'
import apiClient from '@/api/client'
import { API } from '@/api/endpoints'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface PolicyListItem {
  id: string
  code: string | null
  folio: string
  client_name: string
  coverage_type: string
  start_date: string
  end_date: string
  status: string
  printer_count: number
  sla_notes: string | null
}

interface PolicyDetail extends PolicyListItem {
  client_id: string
  printers: PolicyPrinterItem[]
}

interface PolicyPrinterItem {
  id: string
  code: string | null
  serial_number: string
  plant_name: string | null
  area_name: string | null
}

interface ClientOption {
  id: string
  name: string
}

interface PrinterOption {
  id: string
  code: string | null
  serial_number: string
  client_name: string | null
}

interface PagedResponse<T> {
  total: number
  offset: number
  limit: number
  items: T[]
}

interface PolicyFormData {
  client_id: string
  folio: string
  start_date: string
  end_date: string
  coverage_type: string
  sla_notes: string
}

const EMPTY_FORM: PolicyFormData = {
  client_id: '',
  folio: '',
  start_date: '',
  end_date: '',
  coverage_type: '',
  sla_notes: '',
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const PAGE_SIZE = 20

function fmtDate(iso: string) {
  return new Date(iso).toLocaleDateString('es-MX', {
    day: '2-digit', month: 'short', year: 'numeric',
  })
}

const STATUS_STYLES: Record<string, { label: string; classes: string }> = {
  Active:   { label: 'Activa',    classes: 'bg-green-50 text-green-700 border-green-200' },
  Expiring: { label: 'Por vencer', classes: 'bg-amber-50 text-amber-700 border-amber-200' },
  Expired:  { label: 'Vencida',   classes: 'bg-red-50 text-red-600 border-red-200' },
}

function StatusBadge({ status }: { status: string }) {
  const cfg = STATUS_STYLES[status] ?? { label: status, classes: 'bg-gray-100 text-gray-500 border-gray-200' }
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded-full border text-xs font-medium font-sans ${cfg.classes}`}>
      {cfg.label}
    </span>
  )
}

// ---------------------------------------------------------------------------
// Policy modal (create / edit)
// ---------------------------------------------------------------------------

interface PolicyModalProps {
  policy?: PolicyDetail | null
  onClose: () => void
}

function PolicyModal({ policy, onClose }: PolicyModalProps) {
  const qc = useQueryClient()
  const isEdit = !!policy

  const [form, setForm] = useState<PolicyFormData>(
    isEdit
      ? {
          client_id: policy!.client_id,
          folio: policy!.folio,
          start_date: policy!.start_date.slice(0, 10),
          end_date: policy!.end_date.slice(0, 10),
          coverage_type: policy!.coverage_type,
          sla_notes: policy!.sla_notes ?? '',
        }
      : EMPTY_FORM,
  )

  const [selectedPrinters, setSelectedPrinters] = useState<string[]>(
    isEdit ? policy!.printers.map((p) => p.id) : [],
  )

  const [error, setError] = useState<string | null>(null)

  function setField<K extends keyof PolicyFormData>(key: K, value: PolicyFormData[K]) {
    setForm((prev) => ({ ...prev, [key]: value }))
    if (key === 'client_id') setSelectedPrinters([])
  }

  // Clients for dropdown
  const { data: clientsData } = useQuery({
    queryKey: ['filter-clients'],
    queryFn: async () => {
      const res = await apiClient.get<PagedResponse<ClientOption>>(API.clients.list, { params: { limit: 200 } })
      return res.data.items
    },
    staleTime: 60_000,
  })

  // Printers filtered by selected client
  const { data: printersData } = useQuery({
    queryKey: ['printers-for-client', form.client_id],
    queryFn: async () => {
      const res = await apiClient.get<PagedResponse<PrinterOption>>(API.printers.list, {
        params: { client_id: form.client_id, limit: 500 },
      })
      return res.data.items
    },
    enabled: !!form.client_id,
    staleTime: 30_000,
  })

  function togglePrinter(id: string) {
    setSelectedPrinters((prev) =>
      prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id],
    )
  }

  const saveMutation = useMutation({
    mutationFn: async () => {
      const payload = {
        client_id: form.client_id,
        folio: form.folio,
        start_date: new Date(form.start_date).toISOString(),
        end_date: new Date(form.end_date).toISOString(),
        coverage_type: form.coverage_type,
        sla_notes: form.sla_notes || null,
      }

      let policyId: string
      if (isEdit) {
        await apiClient.put(API.policies.detail(policy!.id), payload)
        policyId = policy!.id
      } else {
        const res = await apiClient.post<PolicyDetail>(API.policies.list, payload)
        policyId = res.data.id
      }

      // Assign printers
      await apiClient.post(API.policies.printers(policyId), { printer_ids: selectedPrinters })
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['policies'] })
      onClose()
    },
    onError: (err: unknown) => {
      const msg = (err as { response?: { data?: { detail?: string } } })?.response?.data?.detail
      setError(msg ?? 'Error al guardar la póliza.')
    },
  })

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError(null)
    if (!form.client_id || !form.folio || !form.start_date || !form.end_date || !form.coverage_type) {
      setError('Completa todos los campos obligatorios.')
      return
    }
    if (new Date(form.start_date) >= new Date(form.end_date)) {
      setError('La fecha de inicio debe ser anterior a la fecha de fin.')
      return
    }
    saveMutation.mutate()
  }

  const inputCls = 'w-full text-sm font-sans border border-border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition-colors'
  const labelCls = 'block text-xs font-semibold text-gray-500 font-sans mb-1'

  return (
    <>
      <div className="fixed inset-0 bg-black/40 z-40" onClick={onClose} />
      <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div className="bg-white rounded-xl shadow-2xl w-full max-w-lg max-h-[90vh] flex flex-col">
          {/* Header */}
          <div className="flex items-center justify-between px-6 py-4 border-b border-border shrink-0">
            <div className="flex items-center gap-2">
              <ShieldCheck size={16} className="text-primary" />
              <h3 className="font-semibold text-[#1A1A2E] font-heading">
                {isEdit ? 'Editar póliza' : 'Nueva póliza'}
              </h3>
            </div>
            <button onClick={onClose} className="p-1.5 rounded-lg text-gray-400 hover:text-gray-700 hover:bg-gray-100 transition-colors">
              <X size={18} />
            </button>
          </div>

          {/* Body */}
          <form onSubmit={handleSubmit} className="flex-1 overflow-y-auto">
            <div className="px-6 py-5 space-y-4">
              {/* Client */}
              <div>
                <label className={labelCls}>Cliente *</label>
                <select
                  value={form.client_id}
                  onChange={(e) => setField('client_id', e.target.value)}
                  className={inputCls}
                  disabled={isEdit}
                >
                  <option value="">Seleccionar cliente…</option>
                  {clientsData?.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
                </select>
              </div>

              <div className="grid grid-cols-2 gap-3">
                {/* Folio */}
                <div>
                  <label className={labelCls}>Folio *</label>
                  <input
                    type="text"
                    value={form.folio}
                    onChange={(e) => setField('folio', e.target.value)}
                    placeholder="FOL-2024-001"
                    className={inputCls}
                  />
                </div>
                {/* Coverage type */}
                <div>
                  <label className={labelCls}>Tipo de cobertura *</label>
                  <input
                    type="text"
                    value={form.coverage_type}
                    onChange={(e) => setField('coverage_type', e.target.value)}
                    placeholder="Preventivo, Correctivo…"
                    className={inputCls}
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className={labelCls}>Fecha inicio *</label>
                  <input type="date" value={form.start_date} onChange={(e) => setField('start_date', e.target.value)} className={inputCls} />
                </div>
                <div>
                  <label className={labelCls}>Fecha fin *</label>
                  <input type="date" value={form.end_date} onChange={(e) => setField('end_date', e.target.value)} className={inputCls} />
                </div>
              </div>

              {/* SLA notes */}
              <div>
                <label className={labelCls}>Notas SLA</label>
                <textarea
                  value={form.sla_notes}
                  onChange={(e) => setField('sla_notes', e.target.value)}
                  rows={2}
                  placeholder="Condiciones especiales, tiempos de respuesta…"
                  className={`${inputCls} resize-none`}
                />
              </div>

              {/* Printers assignment */}
              {form.client_id && (
                <div>
                  <label className={labelCls}>
                    Impresoras asignadas
                    {selectedPrinters.length > 0 && (
                      <span className="ml-1.5 text-primary">({selectedPrinters.length})</span>
                    )}
                  </label>
                  {!printersData ? (
                    <div className="h-8 bg-gray-50 rounded-lg animate-pulse" />
                  ) : printersData.length === 0 ? (
                    <p className="text-xs text-gray-400 font-sans py-2">No hay impresoras para este cliente.</p>
                  ) : (
                    <div className="border border-border rounded-lg max-h-40 overflow-y-auto divide-y divide-gray-50">
                      {printersData.map((p) => (
                        <label
                          key={p.id}
                          className="flex items-center gap-3 px-3 py-2.5 cursor-pointer hover:bg-gray-50 transition-colors"
                        >
                          <input
                            type="checkbox"
                            checked={selectedPrinters.includes(p.id)}
                            onChange={() => togglePrinter(p.id)}
                            className="accent-primary"
                          />
                          <span className="font-mono text-xs text-primary font-semibold">{p.code ?? '—'}</span>
                          <span className="text-sm text-gray-600 font-sans">{p.serial_number}</span>
                        </label>
                      ))}
                    </div>
                  )}
                </div>
              )}

              {error && (
                <div className="flex items-center gap-2 bg-red-50 border border-red-200 rounded-lg px-3 py-2.5">
                  <AlertTriangle size={14} className="text-red-500 shrink-0" />
                  <p className="text-sm text-red-600 font-sans">{error}</p>
                </div>
              )}
            </div>

            {/* Footer */}
            <div className="px-6 py-4 border-t border-border bg-gray-50 flex gap-2 justify-end shrink-0">
              <button
                type="button"
                onClick={onClose}
                className="px-4 py-2 text-sm font-semibold text-gray-600 font-sans rounded-lg hover:bg-gray-100 transition-colors"
              >
                Cancelar
              </button>
              <button
                type="submit"
                disabled={saveMutation.isPending}
                className="px-5 py-2 text-sm font-semibold text-white bg-primary hover:bg-primary-dark disabled:opacity-50 rounded-lg transition-colors font-sans"
              >
                {saveMutation.isPending ? 'Guardando…' : isEdit ? 'Guardar cambios' : 'Crear póliza'}
              </button>
            </div>
          </form>
        </div>
      </div>
    </>
  )
}

// ---------------------------------------------------------------------------
// Delete confirm modal
// ---------------------------------------------------------------------------

function DeleteModal({ policy, onClose }: { policy: PolicyListItem; onClose: () => void }) {
  const qc = useQueryClient()

  const deleteMutation = useMutation({
    mutationFn: async () => {
      await apiClient.delete(API.policies.detail(policy.id))
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['policies'] })
      onClose()
    },
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
              <h3 className="font-semibold text-[#1A1A2E] font-heading">Eliminar póliza</h3>
              <p className="text-sm text-gray-400 font-sans">Esta acción no se puede deshacer.</p>
            </div>
          </div>
          <p className="text-sm text-gray-600 font-sans mb-5">
            ¿Eliminar la póliza <span className="font-semibold">{policy.folio}</span> de{' '}
            <span className="font-semibold">{policy.client_name}</span>?
          </p>
          <div className="flex gap-2 justify-end">
            <button
              onClick={onClose}
              className="px-4 py-2 text-sm font-semibold text-gray-600 font-sans rounded-lg hover:bg-gray-100 transition-colors"
            >
              Cancelar
            </button>
            <button
              onClick={() => deleteMutation.mutate()}
              disabled={deleteMutation.isPending}
              className="px-4 py-2 text-sm font-semibold text-white bg-red-500 hover:bg-red-600 disabled:opacity-50 rounded-lg transition-colors font-sans"
            >
              {deleteMutation.isPending ? 'Eliminando…' : 'Eliminar'}
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

export default function PoliciesPage() {
  const [clientFilter, setClientFilter] = useState('')
  const [statusFilter, setStatusFilter] = useState('')
  const [page, setPage] = useState(0)
  const [showCreate, setShowCreate] = useState(false)
  const [editPolicy, setEditPolicy] = useState<PolicyDetail | null>(null)
  const [deletePolicy, setDeletePolicy] = useState<PolicyListItem | null>(null)

  const { data: clientsData } = useQuery({
    queryKey: ['filter-clients'],
    queryFn: async () => {
      const res = await apiClient.get<PagedResponse<ClientOption>>(API.clients.list, { params: { limit: 200 } })
      return res.data.items
    },
    staleTime: 60_000,
  })

  const queryParams = {
    limit: PAGE_SIZE,
    offset: page * PAGE_SIZE,
    ...(clientFilter && { client_id: clientFilter }),
    ...(statusFilter && { status: statusFilter }),
  }

  const { data, isLoading, isFetching } = useQuery({
    queryKey: ['policies', queryParams],
    queryFn: async () => {
      const res = await apiClient.get<PagedResponse<PolicyListItem>>(API.policies.list, { params: queryParams })
      return res.data
    },
    placeholderData: (prev) => prev,
    retry: false,
  })

  const total = data?.total ?? 0
  const items = data?.items ?? []
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE))

  // Load detail for edit
  async function openEdit(policy: PolicyListItem) {
    const res = await apiClient.get<PolicyDetail>(API.policies.detail(policy.id))
    setEditPolicy(res.data)
  }

  const selectCls = 'text-sm font-sans border border-border rounded-lg px-3 py-2 bg-white text-gray-700 focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition-colors'

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h2 className="text-xl font-bold text-[#1A1A2E] font-heading">Pólizas</h2>
          <p className="text-sm text-gray-400 font-sans mt-0.5">
            {isFetching ? 'Actualizando…' : `${total} póliza${total !== 1 ? 's' : ''}`}
          </p>
        </div>
        <button
          onClick={() => setShowCreate(true)}
          className="flex items-center gap-2 bg-primary hover:bg-primary-dark text-white text-sm font-semibold font-sans rounded-lg px-4 py-2 transition-colors"
        >
          <Plus size={15} />
          Nueva póliza
        </button>
      </div>

      {/* Filters */}
      <div className="bg-white rounded-xl border border-border p-4 shadow-sm">
        <div className="flex flex-wrap gap-3">
          <select value={clientFilter} onChange={(e) => { setClientFilter(e.target.value); setPage(0) }} className={selectCls}>
            <option value="">Todos los clientes</option>
            {clientsData?.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>
          <select value={statusFilter} onChange={(e) => { setStatusFilter(e.target.value); setPage(0) }} className={selectCls}>
            <option value="">Todos los estados</option>
            <option value="Active">Activas</option>
            <option value="Expiring">Por vencer</option>
            <option value="Expired">Vencidas</option>
          </select>
          {(clientFilter || statusFilter) && (
            <button onClick={() => { setClientFilter(''); setStatusFilter(''); setPage(0) }} className="text-xs text-gray-400 hover:text-primary font-sans transition-colors">
              Limpiar
            </button>
          )}
        </div>
      </div>

      {/* Table */}
      <div className="bg-white rounded-xl border border-border shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-gray-50 border-b border-border text-left">
                {['Código', 'Folio', 'Cliente', 'Cobertura', 'Vigencia', 'Impresoras', 'Estado', ''].map((h) => (
                  <th key={h} className="px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide font-sans whitespace-nowrap">
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {isLoading ? (
                Array.from({ length: 6 }).map((_, i) => (
                  <tr key={i} className="animate-pulse">
                    {Array.from({ length: 8 }).map((_, j) => (
                      <td key={j} className="px-4 py-3.5">
                        <div className="h-4 bg-gray-100 rounded" style={{ width: `${50 + ((i + j) % 3) * 20}%` }} />
                      </td>
                    ))}
                  </tr>
                ))
              ) : items.length === 0 ? (
                <tr>
                  <td colSpan={8} className="px-4 py-12 text-center text-sm text-gray-400 font-sans">
                    <ShieldCheck size={28} className="mx-auto mb-2 text-gray-200" />
                    No se encontraron pólizas con los filtros aplicados.
                  </td>
                </tr>
              ) : (
                items.map((row) => (
                  <tr key={row.id} className="hover:bg-gray-50/60 transition-colors">
                    <td className="px-4 py-3.5 font-mono text-xs text-primary font-semibold whitespace-nowrap">
                      {row.code ?? '—'}
                    </td>
                    <td className="px-4 py-3.5 font-mono text-xs text-gray-600">
                      {row.folio}
                    </td>
                    <td className="px-4 py-3.5 text-gray-700 font-sans max-w-[160px] truncate">
                      {row.client_name}
                    </td>
                    <td className="px-4 py-3.5 text-gray-600 font-sans">
                      {row.coverage_type}
                    </td>
                    <td className="px-4 py-3.5 text-gray-500 font-sans whitespace-nowrap text-xs">
                      {fmtDate(row.start_date)} — {fmtDate(row.end_date)}
                    </td>
                    <td className="px-4 py-3.5 text-center">
                      <span className="inline-flex items-center justify-center w-7 h-7 rounded-full bg-primary/10 text-primary text-xs font-bold font-sans">
                        {row.printer_count}
                      </span>
                    </td>
                    <td className="px-4 py-3.5">
                      <StatusBadge status={row.status} />
                    </td>
                    <td className="px-4 py-3.5">
                      <div className="flex items-center gap-1">
                        <button
                          onClick={() => openEdit(row)}
                          className="p-1.5 rounded-lg text-gray-400 hover:text-primary hover:bg-primary/10 transition-colors"
                          title="Editar"
                        >
                          <Pencil size={14} />
                        </button>
                        <button
                          onClick={() => setDeletePolicy(row)}
                          className="p-1.5 rounded-lg text-gray-400 hover:text-red-500 hover:bg-red-50 transition-colors"
                          title="Eliminar"
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

      {/* Modals */}
      {showCreate && <PolicyModal onClose={() => setShowCreate(false)} />}
      {editPolicy && <PolicyModal policy={editPolicy} onClose={() => setEditPolicy(null)} />}
      {deletePolicy && <DeleteModal policy={deletePolicy} onClose={() => setDeletePolicy(null)} />}
    </div>
  )
}
