import { useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import {
  ArrowLeft, ShieldCheck, ClipboardList, Info,
  ChevronDown, ChevronRight, FileText, FileDown, AlertTriangle,
} from 'lucide-react'
import apiClient from '@/api/axios'
import ReporteModal from '@/components/ReporteModal'

const API_BASE = (import.meta.env.VITE_API_URL ?? '').replace(/\/$/, '')

function fmtDate(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString('es-MX', { day: '2-digit', month: 'short', year: 'numeric' })
}

const STATUS_STYLES = {
  Active:   { label: 'Activa',      classes: 'bg-green-50 text-green-700 border-green-200' },
  Activa:   { label: 'Activa',      classes: 'bg-green-50 text-green-700 border-green-200' },
  active:   { label: 'Activa',      classes: 'bg-green-50 text-green-700 border-green-200' },
  Expiring: { label: 'Por vencer',  classes: 'bg-amber-50 text-amber-700 border-amber-200' },
  Expired:  { label: 'Vencida',     classes: 'bg-red-50 text-red-600 border-red-200' },
  Vencida:  { label: 'Vencida',     classes: 'bg-red-50 text-red-600 border-red-200' },
}

const SERVICE_TYPE_COLORS = {
  'Preventivo':  'bg-green-50 text-green-700 border-green-200',
  'Correctivo':  'bg-red-50 text-red-600 border-red-200',
  'Diagnóstico': 'bg-amber-50 text-amber-700 border-amber-200',
}

function StatusBadgePol({ status }) {
  const cfg = STATUS_STYLES[status] ?? { label: status, classes: 'bg-gray-100 text-gray-500 border-gray-200' }
  return (
    <span className={`inline-flex items-center px-2.5 py-1 rounded-full border text-xs font-semibold font-sans ${cfg.classes}`}>
      {cfg.label}
    </span>
  )
}

function ServiceTypeBadge({ type }) {
  const cls = SERVICE_TYPE_COLORS[type] ?? 'bg-gray-100 text-gray-500 border-gray-200'
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full border text-xs font-medium font-sans ${cls}`}>
      {type}
    </span>
  )
}

function StatCard({ label, value }) {
  return (
    <div className="bg-white border border-border rounded-xl p-4 shadow-sm">
      <p className="text-xs text-gray-400 font-sans mb-0.5">{label}</p>
      <p className="text-sm font-semibold text-[#1A1A2E] font-sans">{value}</p>
    </div>
  )
}

function InfoRow({ label, value }) {
  return (
    <div>
      <p className="text-xs font-semibold text-gray-500 font-sans mb-0.5">{label}</p>
      <p className="text-sm text-gray-800 font-sans">{value || '—'}</p>
    </div>
  )
}

const TABS = [
  { label: 'Resumen',     icon: ClipboardList },
  { label: 'Información', icon: Info },
]

export default function PolizaDetalle() {
  const { id } = useParams()
  const navigate = useNavigate()
  const [activeTab, setActiveTab] = useState(0)
  const [expandedDeliveryId, setExpandedDeliveryId] = useState(null)
  const [selectedReportId, setSelectedReportId] = useState(null)

  const { data: policy, isLoading } = useQuery({
    queryKey: ['portal', 'policy', id],
    queryFn: async () => {
      const res = await apiClient.get(`/api/portal/policies/${id}`)
      return res.data
    },
    staleTime: 30_000,
    enabled: !!id,
  })

  const { data: expandedDelivery, isLoading: loadingDelivery } = useQuery({
    queryKey: ['portal', 'delivery', expandedDeliveryId],
    queryFn: async () => {
      const res = await apiClient.get(`/api/portal/policies/${id}/deliveries/${expandedDeliveryId}`)
      return res.data
    },
    enabled: !!expandedDeliveryId,
    staleTime: 30_000,
  })

  if (isLoading) {
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
          onClick={() => navigate('/polizas')}
          className="text-primary font-semibold font-sans text-sm hover:underline"
        >
          Volver a pólizas
        </button>
      </div>
    )
  }

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex items-start gap-3 flex-wrap">
        <button
          onClick={() => navigate('/polizas')}
          className="p-2 rounded-lg border border-border text-gray-400 hover:text-primary hover:border-primary hover:bg-primary/5 transition-colors shrink-0 mt-0.5"
        >
          <ArrowLeft size={16} />
        </button>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 flex-wrap">
            <h2 className="text-xl font-bold text-[#1A1A2E] font-heading">{policy.folio}</h2>
            <StatusBadgePol status={policy.status} />
          </div>
          <p className="text-sm text-gray-400 font-sans mt-0.5">{policy.client_name}</p>
        </div>
      </div>

      {/* Tabs */}
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

      {/* Tab 0 — Resumen */}
      {activeTab === 0 && (
        <div className="space-y-4">
          {/* KPI cards */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
            <StatCard label="Cobertura"    value={policy.coverage_type} />
            <StatCard label="Impresoras"   value={String(policy.printer_count)} />
            <StatCard label="Inicio"       value={fmtDate(policy.start_date)} />
            <StatCard label="Vencimiento"  value={fmtDate(policy.end_date)} />
          </div>

          {/* Historial de entregas */}
          <div className="bg-white rounded-xl border border-border shadow-sm overflow-hidden">
            <div className="flex items-center gap-2 px-5 py-4 border-b border-border">
              <ClipboardList size={15} className="text-gray-400" />
              <h3 className="text-sm font-semibold text-[#1A1A2E] font-heading">
                Historial de entregas ({policy.deliveries?.length ?? 0})
              </h3>
            </div>

            {!policy.deliveries || policy.deliveries.length === 0 ? (
              <div className="px-5 py-8 text-center">
                <ClipboardList size={28} className="mx-auto mb-2 text-gray-200" />
                <p className="text-sm text-gray-400 font-sans">Sin entregas registradas.</p>
              </div>
            ) : (
              <div className="divide-y divide-gray-100">
                {policy.deliveries.map((d) => {
                  const isExpanded = expandedDeliveryId === d.id
                  const detail = expandedDelivery?.id === d.id ? expandedDelivery : null

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
                            {d.tech_name && (
                              <p className="text-xs text-gray-400 font-sans mt-0.5">
                                Técnico: {d.tech_name}
                              </p>
                            )}
                          </div>
                          <div className="flex items-center gap-2.5 shrink-0">
                            <span className="inline-flex items-center justify-center rounded-full bg-primary/10 text-primary text-xs font-bold font-sans px-2.5 py-0.5">
                              {d.report_count} equipo{d.report_count !== 1 ? 's' : ''}
                            </span>
                            {isExpanded
                              ? <ChevronDown size={14} className="text-gray-400" />
                              : <ChevronRight size={14} className="text-gray-400" />}
                          </div>
                        </button>
                        <button
                          onClick={() => window.open(`${API_BASE}/uploads/deliveries/delivery_${d.id}_resumen.pdf`, '_blank')}
                          className="flex items-center gap-1.5 px-4 py-4 text-xs font-semibold text-primary hover:bg-primary/5 transition-colors shrink-0 font-sans border-l border-gray-100"
                          title="Descargar PDF de entrega"
                        >
                          <FileDown size={14} />
                          <span className="hidden sm:inline">Descargar PDF</span>
                        </button>
                      </div>

                      {/* Expanded body */}
                      {isExpanded && (
                        <div className="bg-gray-50/60 border-t border-gray-100 px-5 py-4 space-y-3">
                          {detail ? (
                            <div className="space-y-1.5">
                              {detail.reports.map((r) => (
                                <div
                                  key={r.report_id}
                                  className="flex items-center gap-3 py-2.5 px-3 bg-white rounded-lg border border-gray-100 hover:border-primary/20 transition-colors"
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
                                        className="flex items-center gap-1.5 px-2.5 py-1.5 text-xs font-semibold text-primary font-sans rounded-lg border border-primary/30 hover:bg-primary/5 transition-colors"
                                      >
                                        <FileText size={12} />
                                        Ver reporte
                                      </button>
                                    ) : null}
                                  </div>
                                </div>
                              ))}
                            </div>
                          ) : loadingDelivery ? (
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

      {/* Tab 1 — Información */}
      {activeTab === 1 && (
        <div className="space-y-4">
          <div className="bg-white rounded-xl border border-border shadow-sm p-5 space-y-4">
            <h3 className="text-sm font-semibold text-[#1A1A2E] font-heading border-b border-border pb-3">
              Detalles de la póliza
            </h3>
            <div className="grid grid-cols-2 gap-4">
              <InfoRow label="Folio"        value={policy.folio} />
              <InfoRow label="Cobertura"    value={policy.coverage_type} />
              <InfoRow label="Frecuencia"   value={policy.frequency_maintenance} />
              <InfoRow label="Impresoras"   value={String(policy.printer_count)} />
              <InfoRow label="Inicio"       value={fmtDate(policy.start_date)} />
              <InfoRow label="Vencimiento"  value={fmtDate(policy.end_date)} />
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

      {/* Report modal */}
      {selectedReportId && (
        <ReporteModal reportId={selectedReportId} onClose={() => setSelectedReportId(null)} />
      )}
    </div>
  )
}
