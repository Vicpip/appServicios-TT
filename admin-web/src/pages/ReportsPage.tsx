import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import {
  ChevronLeft,
  ChevronRight,
  X,
  CheckCircle2,
  XCircle,
  AlertCircle,
  Clock,
  FileText,
  Filter,
  RotateCcw,
  Camera,
  ExternalLink,
} from 'lucide-react'
import apiClient from '@/api/client'
import { API } from '@/api/endpoints'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface ReportListItem {
  id: string
  code: string | null
  service_type: string
  status: string
  service_date: string
  sync_date: string | null
  printer_serial: string | null
  client_name: string | null
  tech_name: string | null
}

interface ReportDetail extends ReportListItem {
  printer_id: string
  tech_id: string
  linear_inches_counter: number
  darkness_level: number | null
  technical_checkboxes: string
  notes: string | null
  signature_name: string | null
  signature_role: string | null
  signature_image_path: string | null
  photo_paths: string
  photo_count: number
  internal_notes: string | null
  created_at: string
  printer_code: string | null
  tech_code: string | null
}

interface ReportFiles {
  photos: string[]
  signature: string | null
  pdf: string | null
}

interface PagedResponse<T> {
  total: number
  offset: number
  limit: number
  items: T[]
}

interface SelectOption { id: string; name: string }

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const PAGE_SIZE = 15

/** Prefix a server-relative path (e.g. /uploads/...) with the API base URL. */
const API_BASE = (import.meta.env.VITE_API_URL as string ?? '').replace(/\/$/, '')
function fileUrl(path: string): string {
  return `${API_BASE}${path}`
}

function fmtDate(iso: string) {
  return new Date(iso).toLocaleDateString('es-MX', {
    day: '2-digit', month: 'short', year: 'numeric',
  })
}

function fmtDatetime(iso: string) {
  return new Date(iso).toLocaleDateString('es-MX', {
    day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  })
}

function parseJson<T>(raw: string | null | undefined, fallback: T): T {
  if (!raw) return fallback
  try { return JSON.parse(raw) as T } catch { return fallback }
}

// ---------------------------------------------------------------------------
// Status badge
// ---------------------------------------------------------------------------

const STATUS: Record<string, { label: string; classes: string; icon: React.ReactNode }> = {
  Draft:                { label: 'Borrador',          classes: 'bg-gray-100 text-gray-600 border-gray-200',          icon: <Clock size={11} /> },
  Signed:               { label: 'Firmado',           classes: 'bg-blue-50 text-blue-700 border-blue-200',           icon: <FileText size={11} /> },
  signed:               { label: 'Firmado',           classes: 'bg-blue-50 text-blue-700 border-blue-200',           icon: <FileText size={11} /> },
  pending_delivery:     { label: 'Pendiente entrega', classes: 'bg-yellow-50 text-yellow-700 border-yellow-200',     icon: <Clock size={11} /> },
  Synced:               { label: 'Sincronizado',      classes: 'bg-emerald-50 text-emerald-700 border-emerald-200',  icon: <CheckCircle2 size={11} /> },
  'Reviewed-Approved':  { label: 'Aprobado',          classes: 'bg-green-50 text-green-700 border-green-200',        icon: <CheckCircle2 size={11} /> },
  'Reviewed-Rejected':  { label: 'Rechazado',         classes: 'bg-red-50 text-red-600 border-red-200',              icon: <XCircle size={11} /> },
}

function StatusBadge({ status }: { status: string }) {
  const cfg = STATUS[status] ?? { label: status, classes: 'bg-gray-100 text-gray-600 border-gray-200', icon: <AlertCircle size={11} /> }
  return (
    <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full border text-xs font-medium font-sans ${cfg.classes}`}>
      {cfg.icon}{cfg.label}
    </span>
  )
}

// ---------------------------------------------------------------------------
// Detail modal
// ---------------------------------------------------------------------------

function ChecklistRow({ label, value }: { label: string; value: boolean }) {
  return (
    <div className="flex items-center justify-between py-1.5 border-b border-gray-50 last:border-0">
      <span className="text-sm text-gray-600 font-sans">{label}</span>
      {value
        ? <span className="inline-flex items-center gap-1 text-xs font-medium text-emerald-600"><CheckCircle2 size={13} />Sí</span>
        : <span className="inline-flex items-center gap-1 text-xs font-medium text-gray-400"><XCircle size={13} />No</span>
      }
    </div>
  )
}

function SectionTitle({ children }: { children: React.ReactNode }) {
  return (
    <h4 className="text-xs font-semibold text-gray-400 uppercase tracking-wider font-sans mb-2 mt-5 first:mt-0">
      {children}
    </h4>
  )
}

function InfoRow({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="flex justify-between py-1.5 border-b border-gray-50 last:border-0 gap-4">
      <span className="text-sm text-gray-400 font-sans shrink-0">{label}</span>
      <span className="text-sm text-gray-700 font-sans text-right">{value ?? '—'}</span>
    </div>
  )
}

interface DetailModalProps {
  reportId: string
  onClose: () => void
}

function DetailModal({ reportId, onClose }: DetailModalProps) {
  const [lightboxIdx, setLightboxIdx] = useState<number | null>(null)

  const { data: report, isLoading } = useQuery({
    queryKey: ['report', reportId],
    queryFn: async () => {
      const res = await apiClient.get<ReportDetail>(API.reports.detail(reportId))
      return res.data
    },
  })

  const { data: files } = useQuery({
    queryKey: ['report-files', reportId],
    queryFn: async () => {
      const res = await apiClient.get<ReportFiles>(API.reports.files(reportId))
      return res.data
    },
    retry: false,
  })

  // technical_checkboxes is raw JSON: { "Mantenimiento general": true, ... }
  // Object.entries renders each key as-is, so real Flutter key names display correctly.
  const checkboxes = parseJson<Record<string, boolean>>(report?.technical_checkboxes, {})
  const photoCount = report?.photo_count ?? parseJson<string[]>(report?.photo_paths, []).length
  const photos = files?.photos ?? []

  return (
    <>
      <div className="fixed inset-0 bg-black/50 z-40" onClick={onClose} />
      <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div className="bg-white rounded-xl shadow-2xl w-full max-w-2xl max-h-[90vh] flex flex-col">

          {/* Header */}
          <div className="flex items-center justify-between px-6 py-4 border-b border-border shrink-0">
            <div className="flex items-center gap-2.5">
              <FileText size={16} className="text-primary" />
              <span className="font-semibold text-[#1A1A2E] font-heading">
                {report?.code ?? 'Reporte'}
              </span>
              {report && <StatusBadge status={report.status} />}
            </div>
            <div className="flex items-center gap-2">
              {files?.pdf && (
                <a
                  href={fileUrl(files.pdf)}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold font-sans text-primary border border-primary/30 rounded-lg hover:bg-primary/5 transition-colors"
                >
                  <ExternalLink size={12} />
                  Ver PDF
                </a>
              )}
              <button
                onClick={onClose}
                className="p-1.5 rounded-lg text-gray-400 hover:text-gray-700 hover:bg-gray-100 transition-colors"
              >
                <X size={18} />
              </button>
            </div>
          </div>

          {/* Body */}
          <div className="flex-1 overflow-y-auto px-6 py-5">
            {isLoading ? (
              <div className="space-y-3 animate-pulse">
                {Array.from({ length: 10 }).map((_, i) => (
                  <div key={i} className="h-4 bg-gray-100 rounded" style={{ width: `${60 + (i % 3) * 15}%` }} />
                ))}
              </div>
            ) : report ? (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-x-8">

                {/* Left column */}
                <div>
                  <SectionTitle>Información general</SectionTitle>
                  <InfoRow label="Cliente" value={report.client_name} />
                  <InfoRow label="Impresora" value={report.printer_serial} />
                  <InfoRow label="Técnico" value={report.tech_name ?? report.tech_code} />
                  <InfoRow label="Fecha servicio" value={fmtDate(report.service_date)} />
                  <InfoRow label="Tipo de servicio" value={report.service_type} />
                  <InfoRow label="Sincronizado" value={report.sync_date ? fmtDatetime(report.sync_date) : 'No'} />

                  <SectionTitle>Datos técnicos</SectionTitle>
                  <InfoRow label="Contador" value={report.linear_inches_counter ? `${report.linear_inches_counter} in` : null} />
                  <InfoRow label="Oscuridad" value={report.darkness_level} />
                  <InfoRow
                    label="Fotos adjuntas"
                    value={photoCount > 0 ? `${photoCount} foto${photoCount !== 1 ? 's' : ''}` : 'Sin fotos'}
                  />

                  {/* Firma del cliente */}
                  {(report.signature_name || report.signature_role || files?.signature) && (
                    <>
                      <SectionTitle>Firma del cliente</SectionTitle>
                      <div className="bg-gray-50 rounded-lg px-4 py-3 space-y-2">
                        <div className="flex items-center gap-3">
                          <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                            <span className="text-primary font-bold text-xs">
                              {(report.signature_name ?? '?')[0]?.toUpperCase()}
                            </span>
                          </div>
                          <div>
                            <p className="text-sm font-semibold text-gray-700 font-sans">{report.signature_name ?? '—'}</p>
                            <p className="text-xs text-gray-400 font-sans">{report.signature_role ?? '—'}</p>
                          </div>
                        </div>
                        {files?.signature && (
                          <img
                            src={fileUrl(files.signature)}
                            alt="Firma del cliente"
                            className="w-full max-h-28 object-contain bg-white border border-gray-100 rounded-lg p-2"
                          />
                        )}
                      </div>
                    </>
                  )}

                  {report.notes && (
                    <>
                      <SectionTitle>Observaciones</SectionTitle>
                      <p className="text-sm text-gray-600 font-sans bg-gray-50 rounded-lg p-3 leading-relaxed">
                        {report.notes}
                      </p>
                    </>
                  )}

                  {report.internal_notes && (
                    <>
                      <SectionTitle>Notas internas</SectionTitle>
                      <p className="text-sm text-gray-600 font-sans bg-amber-50 border border-amber-100 rounded-lg p-3 leading-relaxed">
                        {report.internal_notes}
                      </p>
                    </>
                  )}
                </div>

                {/* Right column: checklist + photos */}
                <div>
                  {Object.keys(checkboxes).length > 0 && (
                    <>
                      <SectionTitle>Checklist técnico</SectionTitle>
                      {Object.entries(checkboxes).map(([key, val]) => (
                        <ChecklistRow key={key} label={key} value={val} />
                      ))}
                    </>
                  )}

                  {/* Evidencia fotográfica */}
                  {photos.length > 0 && (
                    <>
                      <SectionTitle>
                        <span className="inline-flex items-center gap-1.5">
                          <Camera size={11} />
                          Evidencia fotográfica
                        </span>
                      </SectionTitle>
                      <div className="grid grid-cols-3 gap-2">
                        {photos.map((path, idx) => (
                          <button
                            key={idx}
                            onClick={() => setLightboxIdx(idx)}
                            className="aspect-square rounded-lg overflow-hidden bg-gray-100 hover:opacity-80 transition-opacity focus:outline-none focus:ring-2 focus:ring-primary/40"
                          >
                            <img
                              src={fileUrl(path)}
                              alt={`Foto ${idx + 1}`}
                              className="w-full h-full object-cover"
                            />
                          </button>
                        ))}
                      </div>
                    </>
                  )}
                </div>

              </div>
            ) : (
              <p className="text-sm text-gray-400 font-sans">No se pudo cargar el reporte.</p>
            )}
          </div>

        </div>
      </div>

      {/* Lightbox */}
      {lightboxIdx !== null && photos.length > 0 && (() => {
        const idx = lightboxIdx
        return (
        <>
          <div className="fixed inset-0 bg-black/90 z-[60]" onClick={() => setLightboxIdx(null)} />
          <div className="fixed inset-0 z-[70] flex items-center justify-center p-4 pointer-events-none">
            <img
              src={fileUrl(photos[idx] ?? '')}
              alt={`Foto ${lightboxIdx + 1} de ${photos.length}`}
              className="max-w-full max-h-full object-contain rounded-lg pointer-events-none select-none"
            />
          </div>
          {/* Controls */}
          <button
            onClick={() => setLightboxIdx(null)}
            className="fixed top-4 right-4 z-[70] p-2 rounded-full bg-black/50 text-white hover:bg-black/70 transition-colors"
          >
            <X size={20} />
          </button>
          {photos.length > 1 && (
            <>
              <button
                onClick={() => setLightboxIdx((i) => ((i! - 1 + photos.length) % photos.length))}
                className="fixed left-4 top-1/2 -translate-y-1/2 z-[70] p-2 rounded-full bg-black/50 text-white hover:bg-black/70 transition-colors"
              >
                <ChevronLeft size={24} />
              </button>
              <button
                onClick={() => setLightboxIdx((i) => ((i! + 1) % photos.length))}
                className="fixed right-4 top-1/2 -translate-y-1/2 z-[70] p-2 rounded-full bg-black/50 text-white hover:bg-black/70 transition-colors"
              >
                <ChevronRight size={24} />
              </button>
              <div className="fixed bottom-6 left-1/2 -translate-x-1/2 z-[70] text-white/70 text-sm font-sans">
                {idx + 1} / {photos.length}
              </div>
            </>
          )}
        </>
        )
      })()}
    </>
  )
}

// ---------------------------------------------------------------------------
// Filters bar
// ---------------------------------------------------------------------------

interface Filters {
  client_id: string
  tech_id: string
  status: string
  date_from: string
  date_to: string
}

const EMPTY_FILTERS: Filters = { client_id: '', tech_id: '', status: '', date_from: '', date_to: '' }

const STATUS_OPTIONS = ['Draft', 'Signed', 'Synced', 'Reviewed-Approved', 'Reviewed-Rejected']

function FiltersBar({
  filters,
  onChange,
  onReset,
}: {
  filters: Filters
  onChange: (f: Partial<Filters>) => void
  onReset: () => void
}) {
  const { data: clientsData } = useQuery({
    queryKey: ['filter-clients'],
    queryFn: async () => {
      const res = await apiClient.get<PagedResponse<SelectOption & { rfc?: string }>>(API.clients.list, { params: { limit: 200 } })
      return res.data.items
    },
    staleTime: 60_000,
  })

  const { data: techsData } = useQuery({
    queryKey: ['filter-techs'],
    queryFn: async () => {
      const res = await apiClient.get<PagedResponse<SelectOption & { email?: string }>>(API.technicians.list, { params: { limit: 200 } })
      return res.data.items
    },
    staleTime: 60_000,
  })

  const hasFilters = Object.values(filters).some(Boolean)

  const selectCls = 'text-sm font-sans border border-border rounded-lg px-3 py-2 bg-white text-gray-700 focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition-colors'

  return (
    <div className="bg-white rounded-xl border border-border p-4 shadow-sm">
      <div className="flex items-center gap-2 mb-3">
        <Filter size={14} className="text-primary" />
        <span className="text-sm font-semibold text-gray-600 font-heading">Filtros</span>
        {hasFilters && (
          <button onClick={onReset} className="ml-auto flex items-center gap-1 text-xs text-gray-400 hover:text-primary font-sans transition-colors">
            <RotateCcw size={11} />Limpiar
          </button>
        )}
      </div>
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5 gap-3">
        <select value={filters.client_id} onChange={(e) => onChange({ client_id: e.target.value })} className={selectCls}>
          <option value="">Todos los clientes</option>
          {clientsData?.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
        </select>

        <select value={filters.tech_id} onChange={(e) => onChange({ tech_id: e.target.value })} className={selectCls}>
          <option value="">Todos los técnicos</option>
          {techsData?.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}
        </select>

        <select value={filters.status} onChange={(e) => onChange({ status: e.target.value })} className={selectCls}>
          <option value="">Todos los estados</option>
          {STATUS_OPTIONS.map((s) => <option key={s} value={s}>{STATUS[s]?.label ?? s}</option>)}
        </select>

        <div className="flex flex-col gap-0.5">
          <label className="text-[10px] text-gray-400 font-sans uppercase tracking-wide pl-0.5">Desde</label>
          <input type="date" value={filters.date_from} onChange={(e) => onChange({ date_from: e.target.value })} className={selectCls} />
        </div>

        <div className="flex flex-col gap-0.5">
          <label className="text-[10px] text-gray-400 font-sans uppercase tracking-wide pl-0.5">Hasta</label>
          <input type="date" value={filters.date_to} onChange={(e) => onChange({ date_to: e.target.value })} className={selectCls} />
        </div>
      </div>
    </div>
  )
}

// ---------------------------------------------------------------------------
// Main page
// ---------------------------------------------------------------------------

export default function ReportsPage() {
  const [filters, setFilters] = useState<Filters>(EMPTY_FILTERS)
  const [page, setPage] = useState(0)
  const [selectedId, setSelectedId] = useState<string | null>(null)

  function updateFilter(partial: Partial<Filters>) {
    setFilters((prev) => ({ ...prev, ...partial }))
    setPage(0)
  }

  function resetFilters() {
    setFilters(EMPTY_FILTERS)
    setPage(0)
  }

  const queryParams = {
    limit: PAGE_SIZE,
    offset: page * PAGE_SIZE,
    ...(filters.client_id && { client_id: filters.client_id }),
    ...(filters.tech_id && { tech_id: filters.tech_id }),
    ...(filters.status && { status: filters.status }),
    ...(filters.date_from && { date_from: new Date(filters.date_from).toISOString() }),
    ...(filters.date_to && { date_to: new Date(filters.date_to + 'T23:59:59').toISOString() }),
  }

  const { data, isLoading, isFetching } = useQuery({
    queryKey: ['reports', queryParams],
    queryFn: async () => {
      const res = await apiClient.get<PagedResponse<ReportListItem>>(API.reports.list, { params: queryParams })
      return res.data
    },
    placeholderData: (prev) => prev,
  })

  const total = data?.total ?? 0
  const items = data?.items ?? []
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE))

  return (
    <div className="space-y-4">
      {/* Title */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-bold text-[#1A1A2E] font-heading">Reportes de servicio</h2>
          <p className="text-sm text-gray-400 font-sans mt-0.5">
            {isFetching ? 'Actualizando…' : `${total} reporte${total !== 1 ? 's' : ''} encontrado${total !== 1 ? 's' : ''}`}
          </p>
        </div>
      </div>

      <FiltersBar filters={filters} onChange={updateFilter} onReset={resetFilters} />

      {/* Table */}
      <div className="bg-white rounded-xl border border-border shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-gray-50 border-b border-border text-left">
                {['Código', 'Impresora', 'Cliente', 'Técnico', 'Fecha', 'Tipo', 'Estado'].map((h) => (
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
                    {Array.from({ length: 7 }).map((_, j) => (
                      <td key={j} className="px-4 py-3.5">
                        <div className="h-4 bg-gray-100 rounded" style={{ width: `${50 + ((i + j) % 3) * 20}%` }} />
                      </td>
                    ))}
                  </tr>
                ))
              ) : items.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-4 py-12 text-center text-sm text-gray-400 font-sans">
                    No se encontraron reportes con los filtros aplicados.
                  </td>
                </tr>
              ) : (
                items.map((row) => (
                  <tr
                    key={row.id}
                    onClick={() => setSelectedId(row.id)}
                    className={`cursor-pointer transition-colors hover:bg-primary/[0.03] ${selectedId === row.id ? 'bg-primary/[0.05]' : ''}`}
                  >
                    <td className="px-4 py-3.5 font-mono text-xs text-primary font-semibold whitespace-nowrap">
                      {row.code ?? row.id.slice(0, 8)}
                    </td>
                    <td className="px-4 py-3.5 text-gray-700 font-sans whitespace-nowrap">
                      {row.printer_serial ?? '—'}
                    </td>
                    <td className="px-4 py-3.5 text-gray-600 font-sans max-w-[160px] truncate">
                      {row.client_name ?? '—'}
                    </td>
                    <td className="px-4 py-3.5 text-gray-600 font-sans whitespace-nowrap">
                      {row.tech_name ?? '—'}
                    </td>
                    <td className="px-4 py-3.5 text-gray-500 font-sans whitespace-nowrap">
                      {fmtDate(row.service_date)}
                    </td>
                    <td className="px-4 py-3.5 text-gray-600 font-sans whitespace-nowrap">
                      {row.service_type}
                    </td>
                    <td className="px-4 py-3.5">
                      <StatusBadge status={row.status} />
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

      {/* Detail modal */}
      {selectedId && <DetailModal reportId={selectedId} onClose={() => setSelectedId(null)} />}
    </div>
  )
}
