import { useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, Printer, Trash2, FileText, Download, ChevronLeft, ChevronRight } from 'lucide-react'
import apiClient from '@/api/client'
import { API } from '@/api/endpoints'

const API_BASE = (import.meta.env.VITE_API_URL as string ?? '').replace(/\/$/, '')

// Types
interface PrinterDetail {
  id: string
  code: string | null
  serial_number: string
  qr_uuid: string | null
  is_active: boolean
  client: { id: string; name: string } | null
  plant: { id: string; name: string; contact_name: string | null; phone: string | null } | null
  area: { id: string; name: string } | null
  model: { id: string; brand: string; model_name: string; dpi: number } | null
}

interface ReportRow {
  id: string
  code: string | null
  service_type: string
  service_date: string
  status: string
  tech_name: string | null
  notes: string | null
  signature_name: string | null
  signature_role: string | null
  linear_inches_counter: number
  darkness_level: number | null
  technical_checkboxes: string
  photo_count: number
}

const PAGE_SIZE = 20

function fmtDate(iso: string) {
  return new Date(iso).toLocaleDateString('es-MX', { day: '2-digit', month: 'short', year: 'numeric' })
}

const STATUS_COLORS: Record<string, string> = {
  Synced: 'bg-green-50 text-green-700 border-green-200',
  Signed: 'bg-blue-50 text-blue-700 border-blue-200',
  Draft: 'bg-gray-100 text-gray-500 border-gray-200',
}

export default function PrinterDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const qc = useQueryClient()
  const [offset, setOffset] = useState(0)
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)
  const [deleteError, setDeleteError] = useState<string | null>(null)

  const { data: printer, isLoading } = useQuery<PrinterDetail>({
    queryKey: ['printer-detail', id],
    queryFn: async () => {
      const res = await apiClient.get(API.printers.detail(id!))
      return res.data
    },
    enabled: !!id,
  })

  const { data: reportsData } = useQuery<{ total: number; items: ReportRow[] }>({
    queryKey: ['printer-reports', id, offset],
    queryFn: async () => {
      const res = await apiClient.get(API.printers.reports(id!), { params: { offset, limit: PAGE_SIZE } })
      return res.data
    },
    enabled: !!id,
  })

  const deleteMutation = useMutation({
    mutationFn: async () => {
      await apiClient.delete(API.printers.detail(id!))
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['printers'] })
      navigate('/printers')
    },
    onError: (err: unknown) => {
      const msg = (err as { response?: { data?: { detail?: string } } })?.response?.data?.detail
      setDeleteError(msg ?? 'Error al eliminar')
    },
  })

  async function handleDelete() {
    setDeleteError(null)
    // Check if printer has reports — block deletion if yes
    if (reportsData && reportsData.total > 0) {
      setDeleteError('No se puede eliminar una impresora con reportes existentes')
      setShowDeleteConfirm(false)
      return
    }
    deleteMutation.mutate()
  }

  async function handleDownloadPdf(reportId: string) {
    const res = await apiClient.get(API.reports.files(reportId))
    const pdf = res.data?.pdf
    if (pdf) {
      window.open(`${API_BASE}${pdf}`, '_blank')
    } else {
      alert('No hay PDF disponible para este reporte')
    }
  }

  if (isLoading) {
    return (
      <div className="p-8 flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" />
      </div>
    )
  }

  if (!printer) {
    return <div className="p-8 text-gray-500 font-sans">Impresora no encontrada.</div>
  }

  const totalPages = Math.ceil((reportsData?.total ?? 0) / PAGE_SIZE)
  const currentPage = Math.floor(offset / PAGE_SIZE) + 1

  return (
    <div className="p-6 max-w-5xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <button
          onClick={() => navigate('/printers')}
          className="flex items-center gap-2 text-sm text-gray-500 hover:text-gray-800 font-sans transition-colors"
        >
          <ArrowLeft size={16} />
          Volver a Impresoras
        </button>
        <button
          onClick={() => { setShowDeleteConfirm(true); setDeleteError(null) }}
          className="flex items-center gap-2 px-3 py-2 text-sm font-semibold text-red-600 border border-red-200 rounded-lg hover:bg-red-50 transition-colors font-sans"
        >
          <Trash2 size={14} />
          Eliminar
        </button>
      </div>

      {deleteError && (
        <div className="bg-red-50 border border-red-200 text-red-700 text-sm rounded-lg px-4 py-3 font-sans">
          {deleteError}
        </div>
      )}

      {/* Printer Info Card */}
      <div className="bg-white rounded-xl border border-border shadow-sm p-6">
        <div className="flex items-start gap-4">
          <div className="p-3 bg-primary/10 rounded-xl">
            <Printer size={24} className="text-primary" />
          </div>
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-3 flex-wrap">
              <h1 className="text-xl font-bold text-[#1A1A2E] font-heading">{printer.serial_number}</h1>
              {printer.code && (
                <span className="px-2.5 py-0.5 bg-primary/10 text-primary text-xs font-semibold rounded-full font-sans">
                  {printer.code}
                </span>
              )}
              <span className={`px-2.5 py-0.5 text-xs font-semibold rounded-full border font-sans ${printer.is_active ? 'bg-green-50 text-green-700 border-green-200' : 'bg-gray-100 text-gray-500 border-gray-200'}`}>
                {printer.is_active ? 'Activa' : 'Inactiva'}
              </span>
            </div>
            <div className="mt-3 grid grid-cols-2 md:grid-cols-3 gap-3 text-sm font-sans">
              {printer.model && (
                <div>
                  <span className="text-gray-400 text-xs font-semibold uppercase tracking-wide">Modelo</span>
                  <p className="text-gray-800 font-medium">{printer.model.brand} — {printer.model.model_name}</p>
                  <p className="text-gray-400 text-xs">{printer.model.dpi} dpi</p>
                </div>
              )}
              {printer.client && (
                <div>
                  <span className="text-gray-400 text-xs font-semibold uppercase tracking-wide">Cliente</span>
                  <p className="text-gray-800 font-medium">{printer.client.name}</p>
                </div>
              )}
              {printer.plant && (
                <div>
                  <span className="text-gray-400 text-xs font-semibold uppercase tracking-wide">Planta</span>
                  <p className="text-gray-800 font-medium">{printer.plant.name}</p>
                  {printer.plant.contact_name && <p className="text-gray-400 text-xs">{printer.plant.contact_name}</p>}
                  {printer.plant.phone && <p className="text-gray-400 text-xs">{printer.plant.phone}</p>}
                </div>
              )}
              {printer.area && (
                <div>
                  <span className="text-gray-400 text-xs font-semibold uppercase tracking-wide">Área</span>
                  <p className="text-gray-800 font-medium">{printer.area.name}</p>
                </div>
              )}
              {printer.qr_uuid && (
                <div>
                  <span className="text-gray-400 text-xs font-semibold uppercase tracking-wide">QR UUID</span>
                  <p className="text-gray-600 text-xs font-mono truncate">{printer.qr_uuid}</p>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Report History */}
      <div className="bg-white rounded-xl border border-border shadow-sm">
        <div className="px-6 py-4 border-b border-border flex items-center justify-between">
          <div className="flex items-center gap-2">
            <FileText size={16} className="text-primary" />
            <h2 className="font-semibold text-[#1A1A2E] font-heading">Historial de Reportes</h2>
            {reportsData && (
              <span className="px-2 py-0.5 bg-gray-100 text-gray-600 text-xs rounded-full font-sans">{reportsData.total}</span>
            )}
          </div>
        </div>

        {!reportsData || reportsData.items.length === 0 ? (
          <div className="p-8 text-center text-gray-400 font-sans text-sm">
            Sin reportes registrados para esta impresora.
          </div>
        ) : (
          <>
            <div className="overflow-x-auto">
              <table className="w-full text-sm font-sans">
                <thead>
                  <tr className="border-b border-border bg-gray-50">
                    <th className="text-left px-6 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Fecha</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Código</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Tipo</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Técnico</th>
                    <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Estado</th>
                    <th className="text-right px-6 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">PDF</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-50">
                  {reportsData.items.map((r) => (
                    <tr key={r.id} className="hover:bg-gray-50 transition-colors">
                      <td className="px-6 py-3 text-gray-700 whitespace-nowrap">{fmtDate(r.service_date)}</td>
                      <td className="px-4 py-3 text-gray-500 font-mono text-xs">{r.code ?? '—'}</td>
                      <td className="px-4 py-3 text-gray-700">{r.service_type}</td>
                      <td className="px-4 py-3 text-gray-700">{r.tech_name ?? '—'}</td>
                      <td className="px-4 py-3">
                        <span className={`inline-flex px-2 py-0.5 text-xs font-medium rounded-full border ${STATUS_COLORS[r.status] ?? 'bg-gray-100 text-gray-500 border-gray-200'}`}>
                          {r.status}
                        </span>
                      </td>
                      <td className="px-6 py-3 text-right">
                        <button
                          onClick={() => handleDownloadPdf(r.id)}
                          className="inline-flex items-center gap-1 text-xs text-primary hover:underline font-sans"
                        >
                          <Download size={12} />
                          PDF
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {totalPages > 1 && (
              <div className="px-6 py-4 border-t border-border flex items-center justify-between text-sm font-sans">
                <span className="text-gray-500">Página {currentPage} de {totalPages}</span>
                <div className="flex gap-2">
                  <button onClick={() => setOffset(Math.max(0, offset - PAGE_SIZE))} disabled={offset === 0} className="p-1.5 rounded-lg border border-border hover:bg-gray-50 disabled:opacity-40 transition-colors">
                    <ChevronLeft size={16} />
                  </button>
                  <button onClick={() => setOffset(offset + PAGE_SIZE)} disabled={currentPage >= totalPages} className="p-1.5 rounded-lg border border-border hover:bg-gray-50 disabled:opacity-40 transition-colors">
                    <ChevronRight size={16} />
                  </button>
                </div>
              </div>
            )}
          </>
        )}
      </div>

      {/* Delete Confirmation Dialog */}
      {showDeleteConfirm && (
        <>
          <div className="fixed inset-0 bg-black/40 z-40" onClick={() => setShowDeleteConfirm(false)} />
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
            <div className="bg-white rounded-xl shadow-2xl w-full max-w-sm p-6 space-y-4">
              <h3 className="font-bold text-[#1A1A2E] font-heading">¿Eliminar impresora?</h3>
              <p className="text-sm text-gray-600 font-sans">
                Esta acción desactivará la impresora <strong>{printer.serial_number}</strong>. Solo es posible si no tiene reportes asociados.
              </p>
              <div className="flex gap-3 justify-end">
                <button onClick={() => setShowDeleteConfirm(false)} className="px-4 py-2 text-sm font-semibold text-gray-600 border border-border rounded-lg hover:bg-gray-50 transition-colors font-sans">
                  Cancelar
                </button>
                <button
                  onClick={handleDelete}
                  disabled={deleteMutation.isPending}
                  className="px-4 py-2 text-sm font-semibold text-white bg-red-600 hover:bg-red-700 disabled:opacity-50 rounded-lg transition-colors font-sans"
                >
                  {deleteMutation.isPending ? 'Eliminando…' : 'Eliminar'}
                </button>
              </div>
            </div>
          </div>
        </>
      )}
    </div>
  )
}
