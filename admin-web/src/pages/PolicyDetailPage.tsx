import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  ArrowLeft, ShieldCheck, Pencil, Users, CalendarCheck, Info, ClipboardList,
  Play, X, ChevronDown, ChevronRight, FileText, FileDown, AlertTriangle,
} from 'lucide-react'
import apiClient from '@/api/client'
import { API } from '@/api/endpoints'
import { PolicyModal, PolicyDetail } from './PoliciesPage'
import { DetailModal } from './ReportsPage'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

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
  status: string
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

interface PagedResponse<T> {
  total: number
  offset: number
  limit: number
  items: T[]
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function fmtDate(iso: string) {
  return new Date(iso).toLocaleDateString('es-MX', { day: '2-digit', month: 'short', year: 'numeric' })
}

const STATUS_STYLES: Record<string, { label: string; classes: string }> = {
  Active:   { label: 'Activa',     classes: 'bg-green-50 text-green-700 border-green-200' },
  Expiring: { label: 'Por vencer', classes: 'bg-amber-50 text-amber-700 border-amber-200' },
  Expired:  { label: 'Vencida',   classes: 'bg-red-50 text-red-600 border-red-200' },
}

const SERVICE_TYPE_COLORS: Record<string, string> = {
  'Preventivo':  'bg-green-50 text-green-700 border-green-200',
  'Correctivo':  'bg-red-50 text-red-600 border-red-200',
  'Diagnóstico': 'bg-amber-50 text-amber-700 border-amber-200',
}

function StatusBadge({ status }: { status: string }) {
  const cfg = STATUS_STYLES[status] ?? { label: status, classes: 'bg-gray-100 text-gray-500 border-gray-200' }
  return (
    <span className={`inline-flex items-center px-2.5 py-1 rounded-full border text-xs font-semibold font-sans ${cfg.classes}`}>
      {cfg.label}
    </span>
  )
}

function ServiceTypeBadge({ type }: { type: string }) {
  const cls = SERVICE_TYPE_COLORS[type] ?? 'bg-gray-100 text-gray-500 border-gray-200'
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full border text-xs font-medium font-sans ${cls}`}>
      {type}
    </span>
  )
}

function StatCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="bg-white border border-border rounded-xl p-4 shadow-sm">
      <p className="text-xs text-gray-400 font-sans mb-0.5">{label}</p>
      <p className="text-sm font-semibold text-[#1A1A2E] font-sans">{value}</p>
    </div>
  )
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="text-xs font-semibold text-gray-500 font-sans mb-0.5">{label}</p>
      <p className="text-sm text-gray-800 font-sans">{value}</p>
    </div>
  )
}

const TABS = [
  { label: 'Resumen',    icon: ClipboardList },
  { label: 'Asignación', icon: Users },
  { label: 'Información', icon: Info },
]

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

export default function PolicyDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const qc = useQueryClient()
  const [activeTab, setActiveTab] = useState(0)
  const [editOpen, setEditOpen] = useState(false)
  const [selectedReportId, setSelectedReportId] = useState<string | null>(null)
  const [expandedDeliveryId, setExpandedDeliveryId] = useState<string | null>(null)
  const [hasAutoExpanded, setHasAutoExpanded] = useState(false)

  // Policy detail
  const { data: policy, isLoading: loadingPolicy } = useQuery<PolicyDetail>({
    queryKey: ['policy-detail', id],
    queryFn: async () => {
      const res = await apiClient.get(API.policies.detail(id!))
      return res.data
    },
    enabled: !!id,
    staleTime: 30_000,
  })

  // Assignments
  const { data: assignmentsData, isLoading: loadingAssignments } = useQuery<PolicyPrinterAssignmentItem[]>({
    queryKey: ['assignments', id],
    queryFn: async () => {
      const res = await apiClient.get<{ total: number; items: PolicyPrinterAssignmentItem[] }>(
        API.policies.assignments(id!),
      )
      return res.data.items
    },
    enabled: !!id,
  })

  // Technicians (used for assignment + tech name lookup in delivery headers)
  const { data: techniciansData } = useQuery<TechnicianOption[]>({
    queryKey: ['technicians-for-assignment'],
    queryFn: async () => {
      const res = await apiClient.get<PagedResponse<TechnicianOption>>(
        API.technicians.list, { params: { limit: 200 } },
      )
      return res.data.items.filter((t) => t.role === 'technician')
    },
    staleTime: 60_000,
  })

  // Deliveries
  const { data: deliveriesData } = useQuery<PolicyDeliveryItem[]>({
    queryKey: ['deliveries', id],
    queryFn: async () => {
      const res = await apiClient.get<{ total: number; items: PolicyDeliveryItem[] }>(
        API.policies.deliveries(id!),
      )
      return res.data.items
    },
    enabled: !!id,
  })

  // Auto-expand first delivery on load
  useEffect(() => {
    if (!hasAutoExpanded && deliveriesData?.length) {
      setExpandedDeliveryId(deliveriesData[0]!.id)
      setHasAutoExpanded(true)
    }
  }, [deliveriesData, hasAutoExpanded])

  // Expanded delivery detail
  const { data: expandedDelivery, isLoading: loadingExpanded } = useQuery<PolicyDeliveryDetail>({
    queryKey: ['deliveryDetail', expandedDeliveryId],
    queryFn: async () => {
      const res = await apiClient.get<PolicyDeliveryDetail>(
        API.policies.deliveryDetail(expandedDeliveryId!),
      )
      return res.data
    },
    enabled: !!expandedDeliveryId,
    staleTime: 30_000,
  })

  // Visits
  const { data: visitsData, isLoading: loadingVisits, refetch: refetchVisits } = useQuery<PolicyVisitItem[]>({
    queryKey: ['visits', id],
    queryFn: async () => {
      const res = await apiClient.get<PolicyVisitItem[]>(API.policies.visits(id!))
      return res.data
    },
    enabled: !!id,
  })

  const generateVisitsMutation = useMutation({
    mutationFn: async () => {
      const res = await apiClient.post<PolicyVisitItem[]>(API.policies.generateVisits(id!), {})
      return res.data
    },
    onSuccess: () => refetchVisits(),
  })

  const activateVisitMutation = useMutation({
    mutationFn: async (visitId: string) => {
      await apiClient.patch(API.policies.updateVisit(id!, visitId), { status: 'in_progress' })
    },
    onSuccess: () => refetchVisits(),
  })

  const deleteVisitMutation = useMutation({
    mutationFn: async (visitId: string) => {
      await apiClient.delete(API.policies.deleteVisit(id!, visitId))
    },
    onSuccess: () => refetchVisits(),
  })

  const regenerateVisitsMutation = useMutation({
    mutationFn: async () => {
      await apiClient.delete(API.policies.deleteAllVisits(id!))
      const res = await apiClient.post<PolicyVisitItem[]>(API.policies.generateVisits(id!), {})
      return res.data
    },
    onSuccess: () => refetchVisits(),
  })

  const assignMutation = useMutation({
    mutationFn: async ({ printer_id, technician_id }: { printer_id: string; technician_id: string }) => {
      await apiClient.post(API.policies.assignments(id!), { printer_id, technician_id })
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['assignments', id] }),
  })

  const removeMutation = useMutation({
    mutationFn: async (printer_id: string) => {
      await apiClient.delete(API.policies.assignmentDelete(id!, printer_id))
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['assignments', id] }),
  })

  function getAssignedTech(printerId: string) {
    return assignmentsData?.find((a) => a.printer_id === printerId) ?? null
  }

  function getTechName(techId: string): string | null {
    return techniciansData?.find((t) => t.id === techId)?.name ?? null
  }

  const hasInProgressVisit = visitsData?.some((v) => v.status === 'in_progress') ?? false
  const canRegenerate =
    (visitsData?.length ?? 0) > 0 &&
    (visitsData?.every((v) => v.status !== 'completed') ?? false)

  const selectCls =
    'w-full text-sm font-sans border border-border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition-colors'

  if (loadingPolicy) {
    return (
      <div className="space-y-4">
        <div className="h-12 bg-gray-100 rounded-xl animate-pulse" />
        <div className="h-10 bg-gray-100 rounded-xl animate-pulse" />
        <div className="h-48 bg-gray-100 rounded-xl animate-pulse" />
      </div>
    )
  }

  if (!policy) {
    return (
      <div className="flex flex-col items-center justify-center py-16 gap-4">
        <AlertTriangle size={32} className="text-gray-300" />
        <p className="text-gray-400 font-sans">Póliza no encontrada.</p>
        <button
          onClick={() => navigate('/policies')}
          className="text-primary font-semibold font-sans text-sm hover:underline"
        >
          Volver a pólizas
        </button>
      </div>
    )
  }

  return (
    <div className="space-y-4">
      {/* ── Header ── */}
      <div className="flex items-start gap-3 flex-wrap">
        <button
          onClick={() => navigate('/policies')}
          className="p-2 rounded-lg border border-border text-gray-400 hover:text-primary hover:border-primary hover:bg-primary/5 transition-colors shrink-0 mt-0.5"
        >
          <ArrowLeft size={16} />
        </button>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 flex-wrap">
            <h2 className="text-xl font-bold text-[#1A1A2E] font-heading">{policy.folio}</h2>
            <StatusBadge status={policy.status} />
          </div>
          <p className="text-sm text-gray-400 font-sans mt-0.5">{policy.client_name}</p>
        </div>
        <button
          onClick={() => setEditOpen(true)}
          className="flex items-center gap-2 px-3 py-2 text-sm font-semibold text-gray-600 font-sans border border-border rounded-lg hover:text-primary hover:border-primary hover:bg-primary/5 transition-colors shrink-0"
        >
          <Pencil size={14} />
          Editar
        </button>
      </div>

      {/* ── Tabs ── */}
      <div className="flex gap-1 border-b border-border">
        {TABS.map((tab, i) => {
          const Icon = tab.icon
          return (
            <button
              key={tab.label}
              onClick={() => setActiveTab(i)}
              className={`flex items-center gap-1.5 px-4 py-2.5 text-sm font-semibold font-sans border-b-2 transition-colors ${
                activeTab === i
                  ? 'text-primary border-primary'
                  : 'text-gray-500 border-transparent hover:text-gray-700 hover:border-gray-200'
              }`}
            >
              <Icon size={14} />
              {tab.label}
            </button>
          )
        })}
      </div>

      {/* ── Tab 0: Resumen ── */}
      {activeTab === 0 && (
        <div className="space-y-4">
          {/* Metric cards */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
            <StatCard label="Cobertura"    value={policy.coverage_type} />
            <StatCard label="Impresoras"   value={String(policy.printer_count)} />
            <StatCard label="Inicio"       value={fmtDate(policy.start_date)} />
            <StatCard label="Vencimiento"  value={fmtDate(policy.end_date)} />
          </div>

          {/* Delivery history */}
          <div className="bg-white rounded-xl border border-border shadow-sm overflow-hidden">
            <div className="flex items-center gap-2 px-5 py-4 border-b border-border">
              <ClipboardList size={15} className="text-gray-400" />
              <h3 className="text-sm font-semibold text-[#1A1A2E] font-heading">
                Historial de entregas ({deliveriesData?.length ?? 0})
              </h3>
            </div>

            {!deliveriesData || deliveriesData.length === 0 ? (
              <div className="px-5 py-8 text-center">
                <ClipboardList size={28} className="mx-auto mb-2 text-gray-200" />
                <p className="text-sm text-gray-400 font-sans">Sin entregas registradas.</p>
              </div>
            ) : (
              <div className="divide-y divide-gray-100">
                {deliveriesData.map((d) => {
                  const isExpanded = expandedDeliveryId === d.id
                  const detail = expandedDelivery?.id === d.id ? expandedDelivery : null
                  const techName = getTechName(d.tech_id)

                  // Service type counts from detail
                  const serviceTypeCounts = detail
                    ? detail.reports.reduce<Record<string, number>>((acc, r) => {
                        acc[r.service_type] = (acc[r.service_type] ?? 0) + 1
                        return acc
                      }, {})
                    : {}

                  return (
                    <div key={d.id}>
                      {/* Delivery header row */}
                      <div className="flex items-center hover:bg-gray-50/80 transition-colors">
                        <button
                          onClick={() => setExpandedDeliveryId(isExpanded ? null : d.id)}
                          className="flex-1 flex items-center gap-3 px-5 py-4 text-left"
                        >
                          <div className="min-w-0 flex-1">
                            <p className="text-sm font-semibold text-gray-800 font-sans">
                              {fmtDate(d.delivery_date)}
                            </p>
                            <p className="text-xs text-gray-500 font-sans mt-0.5">
                              Firmado por: {d.signature_name} · {d.signature_role}
                            </p>
                            {techName && (
                              <p className="text-xs text-gray-400 font-sans mt-0.5">
                                Técnico: {techName}
                              </p>
                            )}
                          </div>
                          <div className="flex items-center gap-2.5 shrink-0">
                            <span className="inline-flex items-center justify-center rounded-full bg-[#1A4FD6]/10 text-[#1A4FD6] text-xs font-bold font-sans px-2.5 py-0.5">
                              {d.report_count} equipo{d.report_count !== 1 ? 's' : ''}
                            </span>
                            {isExpanded
                              ? <ChevronDown size={14} className="text-gray-400" />
                              : <ChevronRight size={14} className="text-gray-400" />}
                          </div>
                        </button>
                        <button
                          onClick={() => {
                            const base = (import.meta.env.VITE_API_URL as string ?? '').replace('/api', '').replace(/\/$/, '') || 'http://localhost:8000'
                            window.open(`${base}/uploads/deliveries/delivery_${d.id}_resumen.pdf`, '_blank')
                          }}
                          className="flex items-center gap-1.5 px-4 py-4 text-xs font-semibold text-[#1A4FD6] hover:bg-[#1A4FD6]/5 transition-colors shrink-0 font-sans border-l border-gray-100"
                          title="Descargar PDF de entrega"
                        >
                          <FileDown size={14} />
                          <span className="hidden sm:inline">Descargar PDF</span>
                        </button>
                      </div>

                      {/* Expanded body */}
                      {isExpanded && (
                        <div className="bg-gray-50/60 border-t border-gray-100 px-5 py-4 space-y-4">
                          {detail ? (
                            <>
                              {/* Tech name (from detail, in case not in techniciansData) */}
                              {detail.tech_name && !techName && (
                                <p className="text-xs text-gray-500 font-sans">
                                  <span className="font-semibold text-gray-400 uppercase tracking-wide mr-1.5">Técnico</span>
                                  {detail.tech_name}
                                </p>
                              )}

                              {/* Section A: executive summary */}
                              {detail.reports.length > 0 && (
                                <div className="space-y-2">
                                  <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide font-sans">
                                    Resumen de servicios
                                  </p>
                                  <div className="flex flex-wrap gap-2">
                                    <span className="inline-flex items-center px-2.5 py-1 rounded-full bg-gray-100 text-gray-600 text-xs font-sans font-medium border border-gray-200">
                                      {detail.report_count} equipo{detail.report_count !== 1 ? 's' : ''} atendido{detail.report_count !== 1 ? 's' : ''}
                                    </span>
                                    {Object.entries(serviceTypeCounts).map(([type, count]) => (
                                      <span
                                        key={type}
                                        className={`inline-flex items-center px-2.5 py-1 rounded-full border text-xs font-sans font-medium ${SERVICE_TYPE_COLORS[type] ?? 'bg-gray-100 text-gray-500 border-gray-200'}`}
                                      >
                                        {type} x{count}
                                      </span>
                                    ))}
                                  </div>
                                </div>
                              )}

                              {/* Section B: equipment list */}
                              <div className="space-y-2">
                                <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide font-sans">
                                  Equipos
                                </p>
                                <div className="space-y-1.5">
                                  {detail.reports.map((r) => (
                                    <div
                                      key={r.report_id}
                                      className="flex items-center gap-3 py-2.5 px-3 bg-white rounded-lg border border-gray-100 hover:border-[#1A4FD6]/20 transition-colors"
                                    >
                                      <div className="min-w-0 flex-1">
                                        <p className="text-sm font-sans font-semibold text-gray-800">
                                          {r.model_name ?? '—'}
                                        </p>
                                        <p className="text-xs text-gray-400 font-sans">
                                          S/N: {r.serial_number ?? '—'}
                                          {r.service_date && ` · ${fmtDate(r.service_date)}`}
                                        </p>
                                      </div>
                                      <div className="flex items-center gap-2 shrink-0">
                                        <ServiceTypeBadge type={r.service_type} />
                                        {r.report_id ? (
                                          <button
                                            onClick={() => setSelectedReportId(r.report_id)}
                                            className="flex items-center gap-1.5 px-2.5 py-1.5 text-xs font-semibold text-[#1A4FD6] font-sans rounded-lg border border-[#1A4FD6]/30 hover:bg-[#1A4FD6]/5 transition-colors"
                                          >
                                            <FileText size={12} />
                                            Ver reporte
                                          </button>
                                        ) : (
                                          <span className="inline-flex items-center px-2.5 py-1 rounded-full bg-gray-100 text-gray-400 text-xs font-sans border border-gray-200">
                                            Sin reporte
                                          </span>
                                        )}
                                      </div>
                                    </div>
                                  ))}
                                </div>
                              </div>
                            </>
                          ) : loadingExpanded ? (
                            <div className="space-y-2">
                              {[1, 2, 3].map((i) => (
                                <div key={i} className="h-12 bg-gray-100 rounded-lg animate-pulse" />
                              ))}
                            </div>
                          ) : null}
                        </div>
                      )}
                    </div>
                  )
                })}
              </div>
            )}
          </div>
        </div>
      )}

      {/* ── Tab 1: Asignación ── */}
      {activeTab === 1 && (
        <div className="space-y-5">
          {/* Assignments per printer */}
          <div className="bg-white rounded-xl border border-border shadow-sm overflow-hidden">
            <div className="flex items-center gap-2 px-5 py-4 border-b border-border">
              <Users size={15} className="text-gray-400" />
              <h3 className="text-sm font-semibold text-[#1A1A2E] font-heading">
                Asignar técnico por impresora
              </h3>
            </div>
            <div className="px-5 py-4">
              {loadingAssignments ? (
                <div className="h-10 bg-gray-50 rounded-lg animate-pulse" />
              ) : !policy.printers || policy.printers.length === 0 ? (
                <p className="text-sm text-gray-400 font-sans">
                  Esta póliza no tiene impresoras asignadas.
                </p>
              ) : (
                <div className="space-y-3">
                  {policy.printers.map((printer) => {
                    const current = getAssignedTech(printer.id)
                    return (
                      <div
                        key={printer.id}
                        className="flex items-center gap-3 p-3 border border-border rounded-lg bg-gray-50"
                      >
                        <div className="min-w-0 flex-1">
                          <p className="font-mono text-xs text-primary font-semibold">
                            {printer.code ?? printer.id.slice(0, 8)}
                          </p>
                          <p className="text-sm text-gray-700 font-sans truncate">
                            {printer.serial_number}
                          </p>
                          {printer.plant_name && (
                            <p className="text-xs text-gray-400 font-sans">
                              {printer.plant_name}
                              {printer.area_name ? ` / ${printer.area_name}` : ''}
                            </p>
                          )}
                        </div>
                        <div className="w-52 shrink-0">
                          <select
                            value={current?.technician_id ?? ''}
                            onChange={(e) => {
                              if (e.target.value) {
                                assignMutation.mutate({
                                  printer_id: printer.id,
                                  technician_id: e.target.value,
                                })
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
          </div>

          {/* Visits */}
          <div className="bg-white rounded-xl border border-border shadow-sm overflow-hidden">
            <div className="flex items-center justify-between px-5 py-4 border-b border-border">
              <div className="flex items-center gap-2">
                <CalendarCheck size={15} className="text-gray-400" />
                <h3 className="text-sm font-semibold text-[#1A1A2E] font-heading">
                  Visitas ({visitsData?.length ?? 0})
                </h3>
              </div>
              {!visitsData || visitsData.length === 0 ? (
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
            <div className="px-5 py-4">
              {loadingVisits ? (
                <div className="h-10 bg-gray-50 rounded-lg animate-pulse" />
              ) : !visitsData || visitsData.length === 0 ? (
                <p className="text-sm text-gray-400 font-sans">
                  No hay visitas. Usa "Generar visitas" para crear el calendario automáticamente.
                </p>
              ) : (
                <div className="divide-y divide-gray-100 border border-border rounded-lg overflow-hidden">
                  {visitsData.map((v) => {
                    const isActive    = v.status === 'in_progress'
                    const isCompleted = v.status === 'completed'
                    const canActivate = v.status === 'scheduled' && !hasInProgressVisit

                    const statusBg    = isActive ? 'bg-blue-50' : isCompleted ? 'bg-green-50' : 'bg-white'
                    const statusLabel = isActive ? 'En curso' : isCompleted ? 'Completada' : 'Programada'
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
                                {fmtDate(v.scheduled_date)}
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
          </div>
        </div>
      )}

      {/* ── Tab 2: Información ── */}
      {activeTab === 2 && (
        <div className="space-y-4">
          <div className="bg-white rounded-xl border border-border shadow-sm p-5 space-y-4">
            <h3 className="text-sm font-semibold text-[#1A1A2E] font-heading border-b border-border pb-3">
              Detalles de la póliza
            </h3>
            <div className="grid grid-cols-2 gap-4">
              <InfoRow label="Folio"      value={policy.folio} />
              <InfoRow label="Código"     value={policy.code ?? '—'} />
              <InfoRow label="Cliente"    value={policy.client_name} />
              <InfoRow label="Cobertura"  value={policy.coverage_type} />
              <InfoRow label="Frecuencia" value={policy.frequency_maintenance ?? '—'} />
              <InfoRow label="Impresoras" value={String(policy.printer_count)} />
              <InfoRow label="Inicio"     value={fmtDate(policy.start_date)} />
              <InfoRow label="Vencimiento" value={fmtDate(policy.end_date)} />
            </div>
            {policy.sla_notes && (
              <div>
                <p className="text-xs font-semibold text-gray-500 font-sans mb-1">Notas SLA</p>
                <p className="text-sm text-gray-700 font-sans bg-gray-50 rounded-lg p-3 whitespace-pre-wrap">
                  {policy.sla_notes}
                </p>
              </div>
            )}
          </div>

          {policy.printers && policy.printers.length > 0 && (
            <div className="bg-white rounded-xl border border-border shadow-sm overflow-hidden">
              <div className="flex items-center gap-2 px-5 py-4 border-b border-border">
                <ShieldCheck size={15} className="text-gray-400" />
                <h3 className="text-sm font-semibold text-[#1A1A2E] font-heading">
                  Impresoras en contrato ({policy.printers.length})
                </h3>
              </div>
              <div className="divide-y divide-gray-50">
                {policy.printers.map((p) => (
                  <div key={p.id} className="flex items-center gap-3 px-5 py-3">
                    <span className="font-mono text-xs text-primary font-semibold w-16 shrink-0">
                      {p.code ?? '—'}
                    </span>
                    <span className="text-sm text-gray-700 font-sans flex-1">
                      {p.serial_number}
                    </span>
                    {p.plant_name && (
                      <span className="text-xs text-gray-400 font-sans">
                        {p.plant_name}{p.area_name ? ` / ${p.area_name}` : ''}
                      </span>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {/* ── Modals ── */}
      {editOpen && (
        <PolicyModal
          policy={policy}
          onClose={() => {
            setEditOpen(false)
            qc.invalidateQueries({ queryKey: ['policy-detail', id] })
          }}
        />
      )}
      {selectedReportId && (
        <DetailModal
          reportId={selectedReportId}
          onClose={() => setSelectedReportId(null)}
        />
      )}
    </div>
  )
}
