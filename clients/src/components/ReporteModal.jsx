import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import {
  X, FileText, CheckCircle2, XCircle, Camera,
  ExternalLink, ChevronLeft, ChevronRight,
} from 'lucide-react'
import apiClient from '@/api/axios'
import StatusBadge from '@/components/StatusBadge'

const API_BASE = (import.meta.env.VITE_API_URL ?? '').replace(/\/$/, '')

function fileUrl(path) {
  return `${API_BASE}${path}`
}

function fmtDate(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString('es-MX', { day: '2-digit', month: 'short', year: 'numeric' })
}

function fmtDatetime(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString('es-MX', {
    day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  })
}

function parseJson(raw, fallback) {
  if (!raw) return fallback
  try { return JSON.parse(raw) } catch { return fallback }
}

function SectionTitle({ children }) {
  return (
    <h4 className="text-xs font-semibold text-gray-400 uppercase tracking-wider font-sans mb-2 mt-5 first:mt-0">
      {children}
    </h4>
  )
}

function InfoRow({ label, value }) {
  return (
    <div className="flex justify-between py-1.5 border-b border-gray-50 last:border-0 gap-4">
      <span className="text-sm text-gray-400 font-sans shrink-0">{label}</span>
      <span className="text-sm text-gray-700 font-sans text-right">{value ?? '—'}</span>
    </div>
  )
}

function ChecklistRow({ label, value }) {
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

export default function ReporteModal({ reportId, onClose }) {
  const [lightboxIdx, setLightboxIdx] = useState(null)

  const { data: report, isLoading } = useQuery({
    queryKey: ['portal', 'report', reportId],
    queryFn: async () => {
      const res = await apiClient.get(`/api/portal/reports/${reportId}`)
      return res.data
    },
    staleTime: 60_000,
  })

  const { data: files } = useQuery({
    queryKey: ['portal', 'report-files', reportId],
    queryFn: async () => {
      const res = await apiClient.get(`/api/portal/reports/${reportId}/files`)
      return res.data
    },
    retry: false,
    staleTime: 60_000,
  })

  const checkboxes = parseJson(report?.technical_checkboxes, {})
  const photos = files?.photos ?? []
  const photoCount = report?.photo_count ?? parseJson(report?.photo_paths, []).length

  return (
    <>
      {/* Backdrop */}
      <div className="fixed inset-0 bg-black/50 z-40" onClick={onClose} />

      {/* Modal */}
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
                  <InfoRow label="Técnico" value={report.tech_name} />
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
            <button
              onClick={() => setLightboxIdx(null)}
              className="fixed top-4 right-4 z-[70] p-2 rounded-full bg-black/50 text-white hover:bg-black/70 transition-colors"
            >
              <X size={20} />
            </button>
            {photos.length > 1 && (
              <>
                <button
                  onClick={() => setLightboxIdx((i) => ((i - 1 + photos.length) % photos.length))}
                  className="fixed left-4 top-1/2 -translate-y-1/2 z-[70] p-2 rounded-full bg-black/50 text-white hover:bg-black/70 transition-colors"
                >
                  <ChevronLeft size={24} />
                </button>
                <button
                  onClick={() => setLightboxIdx((i) => ((i + 1) % photos.length))}
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
