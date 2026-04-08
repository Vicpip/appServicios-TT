import { useState, useEffect } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  ShieldCheck, Plus, Pencil, Trash2, X, ChevronLeft, ChevronRight, AlertTriangle, Users, ClipboardList, Printer, Search, CalendarCheck, Play,
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
  frequency_maintenance: string | null
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

interface PolicyPrinterAssignmentItem {
  id: string
  policy_id: string
  printer_id: string
  printer_serial: string | null
  technician_id: string
  technician_name: string | null
  technician_code: string | null
  assigned_at: string
}

interface PolicyDeliveryItem {
  id: string
  policy_id: string
  delivery_date: string
  signature_name: string
  signature_role: string
  tech_id: string
  signature_image_path: string | null
  report_count: number
}

interface PolicyDeliveryDetailReport {
  report_id: string
  serial_number: string | null
  model_name: string | null
  service_type: string
  service_date: string | null
  status: string
}

interface PolicyDeliveryDetail {
  id: string
  policy_id: string
  policy_folio: string | null
  delivery_date: string
  signature_name: string
  signature_role: string
  tech_id: string
  tech_name: string | null
  report_count: number
  reports: PolicyDeliveryDetailReport[]
}

interface PolicyVisitItem {
  id: string
  policy_id: string
  visit_number: number
  scheduled_date: string | null
  status: string  // scheduled | in_progress | completed
  started_at: string | null
  completed_at: string | null
  created_at: string
  attended_count: number
  total_printers: number
}

interface TechnicianOption {
  id: string
  code: string | null
  name: string
  email: string
  role: string
  reports_count: number
  last_sync_at: string | null
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
  frequency_maintenance: string
}

const COVERAGE_OPTIONS = ['Básica', 'Extendida', 'Premium']

const FREQUENCY_OPTIONS = [
  'Mensual (12 visitas)',
  'Bimestral (6 visitas)',
  'Trimestral (4 visitas)',
  'Semestral (2 visitas)',
  'Anual (1 visita)',
]

const EMPTY_FORM: PolicyFormData = {
  client_id: '',
  folio: '',
  start_date: '',
  end_date: '',
  coverage_type: '',
  sla_notes: '',
  frequency_maintenance: '',
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
          frequency_maintenance: policy!.frequency_maintenance ?? '',
        }
      : EMPTY_FORM,
  )

  const [selectedPrinters, setSelectedPrinters] = useState<string[]>(
    isEdit ? policy!.printers.map((p) => p.id) : [],
  )
  const [showPrinterPicker, setShowPrinterPicker] = useState(false)
  const [printerSearch, setPrinterSearch] = useState('')

  const [error, setError] = useState<string | null>(null)

  function setField<K extends keyof PolicyFormData>(key: K, value: PolicyFormData[K]) {
    setForm((prev) => ({ ...prev, [key]: value }))
    if (key === 'client_id') {
      setSelectedPrinters([])
      setShowPrinterPicker(false)
      setPrinterSearch('')
    }
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

  // Next folio suggestion (only when creating)
  const { data: nextFolioData } = useQuery({
    queryKey: ['next-folio'],
    queryFn: async () => {
      const res = await apiClient.get<{ folio: string }>(API.policies.nextFolio)
      return res.data.folio
    },
    enabled: !isEdit,
    staleTime: 0,
  })

  useEffect(() => {
    if (!isEdit && nextFolioData) {
      setForm((prev) => (prev.folio === '' ? { ...prev, folio: nextFolioData } : prev))
    }
  }, [nextFolioData, isEdit])

  // Printers filtered by selected client (limit 200 = backend max)
  const { data: printersData } = useQuery({
    queryKey: ['printers-for-client', form.client_id],
    queryFn: async () => {
      const res = await apiClient.get<PagedResponse<PrinterOption>>(API.printers.list, {
        params: { client_id: form.client_id, limit: 200 },
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
        frequency_maintenance: form.frequency_maintenance || null,
      }

      let policyId: string
      if (isEdit) {
        await apiClient.put(API.policies.detail(policy!.id), payload)
        policyId = policy!.id

        // Sync printers: remove deselected, add newly selected
        const originalIds = new Set(policy!.printers.map((p) => p.id))
        const newIds = new Set(selectedPrinters)
        const toRemove = [...originalIds].filter((id) => !newIds.has(id))
        const toAdd = [...newIds].filter((id) => !originalIds.has(id))
        await Promise.all(
          toRemove.map((id) => apiClient.delete(API.policies.printerDetail(policyId, id))),
        )
        if (toAdd.length > 0) {
          await apiClient.post(API.policies.printers(policyId), { printer_ids: toAdd })
        }
      } else {
        const res = await apiClient.post<PolicyDetail>(API.policies.list, payload)
        policyId = res.data.id
        if (selectedPrinters.length > 0) {
          await apiClient.post(API.policies.printers(policyId), { printer_ids: selectedPrinters })
        }
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['policies'] })
      onClose()
    },
    onError: (err: unknown) => {
      const axiosErr = err as { response?: { status?: number; data?: { detail?: unknown } } }
      console.error('[PolicyModal] save error:', axiosErr?.response?.status, axiosErr?.response?.data)
      const detail = axiosErr?.response?.data?.detail
      let msg: string
      if (typeof detail === 'string') {
        msg = detail
      } else if (Array.isArray(detail) && detail.length > 0) {
        // Pydantic v2 validation error — array of {loc, msg, type}
        msg = detail.map((d: { loc?: string[]; msg?: string }) =>
          d.loc ? `${d.loc.join('.')}: ${d.msg}` : (d.msg ?? JSON.stringify(d))
        ).join(' | ')
      } else {
        msg = `Error al guardar la póliza. (HTTP ${axiosErr?.response?.status ?? '?'})`
      }
      setError(msg)
    },
  })

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError(null)
    if (!form.client_id || !form.folio || !form.start_date || !form.end_date || !form.coverage_type || !form.frequency_maintenance) {
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
                    placeholder="POL-2026-001"
                    className={inputCls}
                  />
                </div>
                {/* Coverage type */}
                <div>
                  <label className={labelCls}>Tipo de cobertura *</label>
                  <select
                    value={form.coverage_type}
                    onChange={(e) => setField('coverage_type', e.target.value)}
                    className={inputCls}
                  >
                    <option value="">Seleccionar…</option>
                    {COVERAGE_OPTIONS.map((o) => <option key={o} value={o}>{o}</option>)}
                  </select>
                </div>
              </div>

              {/* Frequency */}
              <div>
                <label className={labelCls}>Frecuencia de mantenimiento preventivo *</label>
                <select
                  value={form.frequency_maintenance}
                  onChange={(e) => setField('frequency_maintenance', e.target.value)}
                  className={inputCls}
                >
                  <option value="">Seleccionar frecuencia…</option>
                  {FREQUENCY_OPTIONS.map((o) => <option key={o} value={o}>{o}</option>)}
                </select>
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

              {/* Printers section */}
              <div>
                <div className="flex items-center justify-between mb-2">
                  <label className={labelCls + ' mb-0'}>
                    Impresoras en contrato
                    {selectedPrinters.length > 0 && (
                      <span className="ml-1.5 text-primary font-sans">({selectedPrinters.length})</span>
                    )}
                  </label>
                  {form.client_id && (
                    <button
                      type="button"
                      onClick={() => { setShowPrinterPicker((v) => !v); setPrinterSearch('') }}
                      className="flex items-center gap-1 text-xs font-semibold text-primary hover:text-primary-dark transition-colors font-sans"
                    >
                      <Plus size={12} />
                      Agregar equipos
                    </button>
                  )}
                </div>

                {/* Selected printers list */}
                {selectedPrinters.length === 0 ? (
                  <p className="text-xs text-gray-400 font-sans py-1.5">
                    {form.client_id
                      ? 'Sin equipos en contrato. Usa "Agregar equipos" para asignar.'
                      : 'Selecciona un cliente para agregar impresoras.'}
                  </p>
                ) : (
                  <div className="border border-border rounded-lg divide-y divide-gray-50 mb-2">
                    {selectedPrinters.map((id) => {
                      const p = printersData?.find((x) => x.id === id)
                      return (
                        <div key={id} className="flex items-center justify-between px-3 py-2 bg-white first:rounded-t-lg last:rounded-b-lg">
                          <div className="flex items-center gap-2 min-w-0">
                            <Printer size={13} className="text-primary shrink-0" />
                            <span className="font-mono text-xs text-primary font-semibold shrink-0">{p?.code ?? '—'}</span>
                            <span className="text-xs text-gray-600 font-sans truncate">{p?.serial_number ?? id.slice(0, 8)}</span>
                          </div>
                          <button
                            type="button"
                            onClick={() => togglePrinter(id)}
                            className="p-1 rounded text-gray-400 hover:text-red-500 hover:bg-red-50 transition-colors ml-2 shrink-0"
                            title="Quitar"
                          >
                            <X size={12} />
                          </button>
                        </div>
                      )
                    })}
                  </div>
                )}

                {/* Printer picker panel */}
                {showPrinterPicker && form.client_id && (
                  <div className="border border-border rounded-lg bg-gray-50 p-3">
                    <div className="relative mb-2">
                      <Search size={13} className="absolute left-2.5 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
                      <input
                        type="text"
                        placeholder="Buscar por serie o código…"
                        value={printerSearch}
                        onChange={(e) => setPrinterSearch(e.target.value)}
                        className="w-full pl-7 pr-2.5 py-1.5 text-xs font-sans border border-border rounded-lg focus:outline-none focus:ring-1 focus:ring-primary/30 focus:border-primary transition-colors bg-white"
                        autoFocus
                      />
                    </div>
                    {!printersData ? (
                      <div className="h-8 bg-gray-100 rounded animate-pulse" />
                    ) : (() => {
                        const available = printersData.filter(
                          (p) =>
                            !selectedPrinters.includes(p.id) &&
                            (printerSearch === '' ||
                              p.serial_number.toLowerCase().includes(printerSearch.toLowerCase()) ||
                              (p.code ?? '').toLowerCase().includes(printerSearch.toLowerCase())),
                        )
                        return available.length === 0 ? (
                          <p className="text-xs text-gray-400 font-sans py-1">
                            {printersData.filter((p) => !selectedPrinters.includes(p.id)).length === 0
                              ? 'Todas las impresoras del cliente ya están agregadas.'
                              : 'Sin resultados.'}
                          </p>
                        ) : (
                          <div className="max-h-36 overflow-y-auto divide-y divide-gray-100 rounded">
                            {available.map((p) => (
                              <button
                                key={p.id}
                                type="button"
                                onClick={() => togglePrinter(p.id)}
                                className="w-full flex items-center gap-2 px-2 py-2 hover:bg-white transition-colors text-left rounded"
                              >
                                <Plus size={11} className="text-primary shrink-0" />
                                <span className="font-mono text-xs text-primary font-semibold shrink-0">{p.code ?? '—'}</span>
                                <span className="text-xs text-gray-600 font-sans truncate">{p.serial_number}</span>
                              </button>
                            ))}
                          </div>
                        )
                      })()}
                  </div>
                )}
              </div>

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
// Delivery Detail Modal
// ---------------------------------------------------------------------------

function DeliveryDetailModal({ deliveryId, onClose }: { deliveryId: string; onClose: () => void }) {
  const { data, isLoading } = useQuery({
    queryKey: ['deliveryDetail', deliveryId],
    queryFn: async () => {
      const res = await apiClient.get<PolicyDeliveryDetail>(
        API.policies.deliveryDetail(deliveryId)
      )
      return res.data
    },
    staleTime: 30_000,
  })

  const statusLabel = (status: string) => {
    if (status === 'signed' || status === 'Signed') return { text: 'Firmado', cls: 'bg-blue-50 text-blue-700 border border-blue-200' }
    return { text: 'Pendiente', cls: 'bg-yellow-50 text-yellow-700 border border-yellow-200' }
  }

  return (
    <>
      <div className="fixed inset-0 bg-black/50 z-50" onClick={onClose} />
      <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div className="bg-white rounded-xl shadow-2xl w-full max-w-2xl flex flex-col max-h-[85vh]">
          <div className="flex items-center justify-between px-6 py-4 border-b border-border shrink-0">
            <h2 className="text-lg font-bold text-gray-900 font-sans">
              Detalle de entrega
            </h2>
            <button onClick={onClose} className="text-gray-400 hover:text-gray-600 transition-colors">
              <X size={20} />
            </button>
          </div>

          <div className="overflow-y-auto flex-1 px-6 py-4">
            {isLoading ? (
              <div className="flex justify-center py-8">
                <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" />
              </div>
            ) : !data ? (
              <p className="text-gray-400 text-sm font-sans text-center py-8">No se encontró la entrega.</p>
            ) : (
              <div className="space-y-4">
                {/* Header info */}
                <div className="bg-gray-50 rounded-lg p-4 space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-sm font-bold text-gray-900 font-sans">Póliza: {data.policy_folio ?? '—'}</span>
                    <span className="inline-flex items-center gap-1 text-xs font-bold text-green-700 bg-green-50 border border-green-200 rounded-full px-2 py-1">
                      {data.report_count} equipo{data.report_count !== 1 ? 's' : ''}
                    </span>
                  </div>
                  <p className="text-xs text-gray-500 font-sans">
                    Fecha: {new Date(data.delivery_date).toLocaleDateString('es-MX', { day: '2-digit', month: 'short', year: 'numeric' })}
                  </p>
                  <p className="text-xs text-gray-500 font-sans">
                    Firmó: {data.signature_name} · {data.signature_role}
                  </p>
                  {data.tech_name && (
                    <p className="text-xs text-gray-500 font-sans">Técnico: {data.tech_name}</p>
                  )}
                </div>

                {/* Reports table */}
                <div>
                  <p className="text-xs font-bold text-gray-500 uppercase tracking-wide font-sans mb-2">Equipos</p>
                  <div className="divide-y divide-gray-100 border border-border rounded-lg overflow-hidden">
                    {data.reports.map((r) => {
                      const s = statusLabel(r.status)
                      return (
                        <div key={r.report_id} className="flex items-center justify-between px-4 py-3 bg-white hover:bg-gray-50">
                          <div>
                            <p className="text-sm font-sans font-semibold text-gray-800">{r.model_name ?? '—'}</p>
                            <p className="text-xs text-gray-400 font-sans">
                              S/N: {r.serial_number ?? '—'} · {r.service_type}
                              {r.service_date && ` · ${new Date(r.service_date).toLocaleDateString('es-MX', { day: '2-digit', month: 'short' })}`}
                            </p>
                          </div>
                          <span className={`text-xs font-bold font-sans px-2 py-1 rounded-full ${s.cls}`}>{s.text}</span>
                        </div>
                      )
                    })}
                  </div>
                </div>
              </div>
            )}
          </div>

          <div className="px-6 py-4 border-t border-border bg-gray-50 flex justify-end shrink-0">
            <button
              onClick={onClose}
              className="px-4 py-2 text-sm font-semibold text-gray-600 font-sans rounded-lg hover:bg-gray-100 transition-colors"
            >
              Cerrar
            </button>
          </div>
        </div>
      </div>
    </>
  )
}

// ---------------------------------------------------------------------------
// Assignment panel (modal)
// ---------------------------------------------------------------------------

function AssignmentPanel({ policy, onClose }: { policy: PolicyDetail; onClose: () => void }) {
  const qc = useQueryClient()
  const [detailDeliveryId, setDetailDeliveryId] = useState<string | null>(null)

  const { data: assignmentsData, isLoading: loadingAssignments } = useQuery({
    queryKey: ['assignments', policy.id],
    queryFn: async () => {
      const res = await apiClient.get<{ total: number; items: PolicyPrinterAssignmentItem[] }>(
        API.policies.assignments(policy.id)
      )
      return res.data.items
    },
  })

  const { data: techniciansData } = useQuery({
    queryKey: ['technicians-for-assignment'],
    queryFn: async () => {
      const res = await apiClient.get<{ total: number; items: TechnicianOption[] }>(
        API.technicians.list, { params: { limit: 200 } }
      )
      return res.data.items.filter((t) => t.role === 'technician')
    },
    staleTime: 60_000,
  })

  const { data: deliveriesData } = useQuery({
    queryKey: ['deliveries', policy.id],
    queryFn: async () => {
      const res = await apiClient.get<{ total: number; items: PolicyDeliveryItem[] }>(
        API.policies.deliveries(policy.id)
      )
      return res.data.items
    },
  })

  const { data: visitsData, isLoading: loadingVisits, refetch: refetchVisits } = useQuery({
    queryKey: ['visits', policy.id],
    queryFn: async () => {
      const res = await apiClient.get<PolicyVisitItem[]>(API.policies.visits(policy.id))
      return res.data
    },
  })

  const generateVisitsMutation = useMutation({
    mutationFn: async () => {
      const res = await apiClient.post<PolicyVisitItem[]>(API.policies.generateVisits(policy.id), {})
      return res.data
    },
    onSuccess: () => refetchVisits(),
  })

  const activateVisitMutation = useMutation({
    mutationFn: async (visitId: string) => {
      await apiClient.patch(API.policies.updateVisit(policy.id, visitId), { status: 'in_progress' })
    },
    onSuccess: () => refetchVisits(),
  })

  const deleteVisitMutation = useMutation({
    mutationFn: async (visitId: string) => {
      await apiClient.delete(API.policies.deleteVisit(policy.id, visitId))
    },
    onSuccess: () => refetchVisits(),
  })

  const regenerateVisitsMutation = useMutation({
    mutationFn: async () => {
      const delRes = await apiClient.delete<{ deleted: number }>(API.policies.deleteAllVisits(policy.id))
      console.log('[Regenerar] eliminadas:', delRes.data.deleted, 'visitas')
      const res = await apiClient.post<PolicyVisitItem[]>(API.policies.generateVisits(policy.id), {})
      return res.data
    },
    onSuccess: () => refetchVisits(),
  })

  const hasInProgressVisit = visitsData?.some((v) => v.status === 'in_progress') ?? false
  const canRegenerate = (visitsData?.length ?? 0) > 0 && visitsData!.every((v) => v.status !== 'completed')

  const assignMutation = useMutation({
    mutationFn: async ({ printer_id, technician_id }: { printer_id: string; technician_id: string }) => {
      await apiClient.post(API.policies.assignments(policy.id), { printer_id, technician_id })
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['assignments', policy.id] }),
  })

  const removeMutation = useMutation({
    mutationFn: async (printer_id: string) => {
      await apiClient.delete(API.policies.assignmentDelete(policy.id, printer_id))
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['assignments', policy.id] }),
  })

  function getAssignedTech(printerId: string) {
    return assignmentsData?.find((a) => a.printer_id === printerId) ?? null
  }

  const labelCls = 'block text-xs font-semibold text-gray-500 font-sans mb-1'
  const selectCls = 'w-full text-sm font-sans border border-border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition-colors'

  return (
    <>
      <div className="fixed inset-0 bg-black/40 z-40" onClick={onClose} />
      <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div className="bg-white rounded-xl shadow-2xl w-full max-w-2xl max-h-[90vh] flex flex-col">
          {/* Header */}
          <div className="flex items-center justify-between px-6 py-4 border-b border-border shrink-0">
            <div className="flex items-center gap-2">
              <Users size={16} className="text-primary" />
              <h3 className="font-semibold text-[#1A1A2E] font-heading">
                Asignación de técnicos — {policy.folio}
              </h3>
            </div>
            <button onClick={onClose} className="p-1.5 rounded-lg text-gray-400 hover:text-gray-700 hover:bg-gray-100 transition-colors">
              <X size={18} />
            </button>
          </div>

          <div className="flex-1 overflow-y-auto px-6 py-5 space-y-6">
            {/* Assignments per printer */}
            <div>
              <p className={labelCls}>Asignar técnico por impresora</p>
              {loadingAssignments ? (
                <div className="h-10 bg-gray-50 rounded-lg animate-pulse" />
              ) : policy.printers.length === 0 ? (
                <p className="text-sm text-gray-400 font-sans">Esta póliza no tiene impresoras asignadas.</p>
              ) : (
                <div className="space-y-3">
                  {policy.printers.map((printer) => {
                    const current = getAssignedTech(printer.id)
                    return (
                      <div key={printer.id} className="flex items-center gap-3 p-3 border border-border rounded-lg bg-gray-50">
                        <div className="min-w-0 flex-1">
                          <p className="font-mono text-xs text-primary font-semibold">{printer.code ?? printer.id.slice(0, 8)}</p>
                          <p className="text-sm text-gray-700 font-sans truncate">{printer.serial_number}</p>
                          {printer.plant_name && (
                            <p className="text-xs text-gray-400 font-sans">{printer.plant_name} / {printer.area_name}</p>
                          )}
                        </div>
                        <div className="w-52 shrink-0">
                          <select
                            value={current?.technician_id ?? ''}
                            onChange={(e) => {
                              if (e.target.value) {
                                assignMutation.mutate({ printer_id: printer.id, technician_id: e.target.value })
                              } else if (current) {
                                removeMutation.mutate(printer.id)
                              }
                            }}
                            className={selectCls}
                            disabled={assignMutation.isPending || removeMutation.isPending}
                          >
                            <option value="">Sin asignar</option>
                            {techniciansData?.map((t) => (
                              <option key={t.id} value={t.id}>
                                {t.code ? `[${t.code}] ` : ''}{t.name}
                              </option>
                            ))}
                          </select>
                        </div>
                        {current && (
                          <button
                            onClick={() => removeMutation.mutate(printer.id)}
                            disabled={removeMutation.isPending}
                            className="p-1.5 rounded-lg text-gray-400 hover:text-red-500 hover:bg-red-50 transition-colors"
                            title="Quitar asignación"
                          >
                            <X size={14} />
                          </button>
                        )}
                      </div>
                    )
                  })}
                </div>
              )}
            </div>

            {/* Visits section */}
            <div>
              <div className="flex items-center justify-between mb-2">
                <div className="flex items-center gap-2">
                  <CalendarCheck size={14} className="text-gray-400" />
                  <p className={`${labelCls} mb-0`}>
                    Visitas ({visitsData?.length ?? 0})
                  </p>
                </div>
                {(!visitsData || visitsData.length === 0) ? (
                  <button
                    onClick={() => generateVisitsMutation.mutate()}
                    disabled={generateVisitsMutation.isPending || loadingVisits}
                    className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold font-sans rounded-lg bg-primary text-white hover:bg-primary-dark disabled:opacity-50 transition-colors"
                  >
                    <CalendarCheck size={12} />
                    {generateVisitsMutation.isPending ? 'Generando…' : 'Generar visitas'}
                  </button>
                ) : canRegenerate ? (
                  <button
                    onClick={() => regenerateVisitsMutation.mutate()}
                    disabled={regenerateVisitsMutation.isPending}
                    className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold font-sans rounded-lg bg-amber-500 text-white hover:bg-amber-600 disabled:opacity-50 transition-colors"
                    title="Elimina todas las visitas programadas y las regenera"
                  >
                    <CalendarCheck size={12} />
                    {regenerateVisitsMutation.isPending ? 'Regenerando…' : 'Regenerar'}
                  </button>
                ) : null}
              </div>

              {loadingVisits ? (
                <div className="h-10 bg-gray-50 rounded-lg animate-pulse" />
              ) : !visitsData || visitsData.length === 0 ? (
                <p className="text-sm text-gray-400 font-sans">
                  No hay visitas. Usa "Generar visitas" para crear el calendario automáticamente según la frecuencia de mantenimiento.
                </p>
              ) : (
                <div className="divide-y divide-gray-100 border border-border rounded-lg overflow-hidden">
                  {visitsData.map((v) => {
                    const isActive = v.status === 'in_progress'
                    const isCompleted = v.status === 'completed'
                    const canActivate = v.status === 'scheduled' && !hasInProgressVisit

                    const statusBg = isActive
                      ? 'bg-blue-50'
                      : isCompleted
                      ? 'bg-green-50'
                      : 'bg-white'
                    const statusLabel = isActive
                      ? 'En curso'
                      : isCompleted
                      ? 'Completada'
                      : 'Programada'
                    const statusColor = isActive
                      ? 'text-blue-600 border-blue-200 bg-blue-50'
                      : isCompleted
                      ? 'text-green-700 border-green-200 bg-green-50'
                      : 'text-gray-500 border-gray-200 bg-gray-50'

                    return (
                      <div
                        key={v.id}
                        className={`flex items-center justify-between px-4 py-3 ${statusBg} hover:bg-gray-50 transition-colors gap-3`}
                      >
                        <div className="min-w-0 flex-1">
                          <p className="text-sm font-sans font-semibold text-gray-700">
                            Visita {v.visit_number}/{visitsData.length}
                            {v.scheduled_date && (
                              <span className="ml-2 text-xs text-gray-400 font-normal">
                                {new Date(v.scheduled_date).toLocaleDateString('es-MX', { day: '2-digit', month: 'short', year: 'numeric' })}
                              </span>
                            )}
                          </p>
                          {isActive && (
                            <p className="text-xs text-blue-600 font-sans font-medium">
                              {v.attended_count}/{v.total_printers} equipos atendidos
                            </p>
                          )}
                        </div>

                        <div className="flex items-center gap-2 shrink-0">
                          {isActive && v.total_printers > 0 && (
                            <span className="text-xs font-bold font-sans text-blue-700 bg-blue-100 border border-blue-200 rounded-full px-2 py-0.5">
                              {v.attended_count}/{v.total_printers} equipos
                            </span>
                          )}
                          <span className={`inline-flex items-center px-2 py-0.5 rounded-full border text-xs font-medium font-sans ${statusColor}`}>
                            {statusLabel}
                          </span>
                          {canActivate && (
                            <button
                              onClick={() => activateVisitMutation.mutate(v.id)}
                              disabled={activateVisitMutation.isPending}
                              className="flex items-center gap-1 px-2 py-1 text-xs font-semibold font-sans rounded-lg bg-primary text-white hover:bg-primary-dark disabled:opacity-50 transition-colors"
                              title="Activar esta visita"
                            >
                              <Play size={10} />
                              Activar
                            </button>
                          )}
                          <button
                            onClick={() => deleteVisitMutation.mutate(v.id)}
                            disabled={deleteVisitMutation.isPending}
                            className="p-1 rounded-lg text-gray-400 hover:text-red-500 hover:bg-red-50 transition-colors"
                            title="Eliminar visita"
                          >
                            <X size={14} />
                          </button>
                        </div>
                      </div>
                    )
                  })}
                </div>
              )}
            </div>

            {/* Delivery history */}
            <div>
              <div className="flex items-center gap-2 mb-2">
                <ClipboardList size={14} className="text-gray-400" />
                <p className={`${labelCls} mb-0`}>Historial de entregas</p>
              </div>
              {!deliveriesData || deliveriesData.length === 0 ? (
                <p className="text-sm text-gray-400 font-sans">Sin entregas registradas.</p>
              ) : (
                <div className="divide-y divide-gray-100 border border-border rounded-lg overflow-hidden">
                  {deliveriesData.map((d) => (
                    <div key={d.id} className="flex items-center justify-between px-4 py-3 bg-white hover:bg-gray-50 transition-colors">
                      <div>
                        <p className="text-sm font-sans text-gray-700">
                          {new Date(d.delivery_date).toLocaleDateString('es-MX', { day: '2-digit', month: 'short', year: 'numeric' })}
                        </p>
                        <p className="text-xs text-gray-400 font-sans">{d.signature_name} · {d.signature_role}</p>
                      </div>
                      <div className="flex items-center gap-2">
                        <span className="inline-flex items-center justify-center rounded-full bg-primary/10 text-primary text-xs font-bold font-sans px-2 py-1">
                          {d.report_count} equipo{d.report_count !== 1 ? 's' : ''}
                        </span>
                        <button
                          onClick={() => setDetailDeliveryId(d.id)}
                          className="text-xs text-primary font-semibold font-sans hover:underline"
                        >
                          Ver detalle
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>

          <div className="px-6 py-4 border-t border-border bg-gray-50 flex justify-end shrink-0">
            <button
              onClick={onClose}
              className="px-4 py-2 text-sm font-semibold text-gray-600 font-sans rounded-lg hover:bg-gray-100 transition-colors"
            >
              Cerrar
            </button>
          </div>
        </div>
      </div>
      {detailDeliveryId && (
        <DeliveryDetailModal
          deliveryId={detailDeliveryId}
          onClose={() => setDetailDeliveryId(null)}
        />
      )}
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
  const [assignmentPolicy, setAssignmentPolicy] = useState<PolicyDetail | null>(null)

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
                          onClick={async () => {
                            const res = await apiClient.get<PolicyDetail>(API.policies.detail(row.id))
                            setAssignmentPolicy(res.data)
                          }}
                          className="p-1.5 rounded-lg text-gray-400 hover:text-primary hover:bg-primary/10 transition-colors"
                          title="Asignaciones y entregas"
                        >
                          <Users size={14} />
                        </button>
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
      {assignmentPolicy && <AssignmentPanel policy={assignmentPolicy} onClose={() => setAssignmentPolicy(null)} />}
    </div>
  )
}
