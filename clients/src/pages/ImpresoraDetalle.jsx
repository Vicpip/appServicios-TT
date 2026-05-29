import { useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { ArrowLeft, Printer, FileText, ChevronLeft, ChevronRight, BarChart2 } from 'lucide-react'
import apiClient from '@/api/axios'
import StatusBadge from '@/components/StatusBadge'
import { SkeletonLine, SkeletonTable } from '@/components/Skeleton'

const LIMIT = 10

function fmtDate(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString('es-MX', { day: '2-digit', month: 'short', year: 'numeric' })
}

export default function ImpresoraDetalle() {
  const { id } = useParams()
  const [offset, setOffset] = useState(0)

  const { data: printer, isLoading: loadingPrinter, error: printerError } = useQuery({
    queryKey: ['portal', 'printer', id],
    queryFn: async () => {
      const res = await apiClient.get(`/api/portal/printers/${id}`)
      return res.data
    },
    staleTime: 60_000,
  })

  const { data: reportsData, isLoading: loadingReports } = useQuery({
    queryKey: ['portal', 'printer-reports', id, offset],
    queryFn: async () => {
      const res = await apiClient.get('/api/portal/reports', {
        params: { printer_id: id, limit: LIMIT, offset },
      })
      return res.data
    },
    staleTime: 60_000,
  })

  const reports = reportsData?.items ?? []
  const total = reportsData?.total ?? 0
  const totalPages = Math.ceil(total / LIMIT)
  const currentPage = Math.floor(offset / LIMIT) + 1

  // Client-side stats from loaded reports filtered to last 30 days
  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
  const recent = reports.filter(r => r.service_date && new Date(r.service_date) >= thirtyDaysAgo)
  const totalRecent = recent.length
  const completados = recent.filter(r => r.status?.toLowerCase() === 'completado').length
  const pendientes = recent.filter(r => r.status?.toLowerCase() === 'pendiente').length
  const typeFreq = {}
  recent.forEach(r => { if (r.service_type) typeFreq[r.service_type] = (typeFreq[r.service_type] ?? 0) + 1 })
  const tipoFrecuente = Object.keys(typeFreq).sort((a, b) => typeFreq[b] - typeFreq[a])[0] ?? '—'
  const ultimaObs = recent.find(r => r.notes)?.notes ?? null
  const estadoGeneral = recent.length === 0
    ? { label: 'Sin reportes', cls: 'bg-gray-100 text-gray-500 border-gray-200' }
    : pendientes > 0
      ? { label: 'Con pendientes', cls: 'bg-amber-50 text-amber-700 border-amber-200' }
      : { label: 'Al día', cls: 'bg-green-50 text-green-700 border-green-200' }

  return (
    <div className="p-6 max-w-5xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <Link
          to="/impresoras"
          className="flex items-center gap-2 text-sm text-gray-500 hover:text-gray-800 font-sans transition-colors"
        >
          <ArrowLeft size={16} />
          Mis Impresoras
        </Link>
      </div>

      {printerError && (
        <div className="bg-red-50 border border-red-200 text-red-700 text-sm rounded-lg px-4 py-3 font-sans">
          Error al cargar la impresora.
        </div>
      )}

      {/* Printer Info Card */}
      <div className="bg-white rounded-xl border border-border shadow-sm p-6">
        <div className="flex items-start gap-4">
          <div className="p-3 bg-primary/10 rounded-xl">
            <Printer size={24} className="text-primary" />
          </div>
          <div className="flex-1 min-w-0">
            {loadingPrinter ? (
              <div className="space-y-3">
                <SkeletonLine className="h-6 w-48" />
                <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
                  {Array.from({ length: 4 }).map((_, i) => (
                    <SkeletonLine key={i} className="h-10 w-full" />
                  ))}
                </div>
              </div>
            ) : printer ? (
              <>
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
                  {(printer.model_brand || printer.model_name) && (
                    <div>
                      <span className="text-gray-400 text-xs font-semibold uppercase tracking-wide">Modelo</span>
                      <p className="text-gray-800 font-medium">
                        {[printer.model_brand, printer.model_name].filter(Boolean).join(' — ')}
                      </p>
                      {printer.model_dpi != null && (
                        <p className="text-gray-400 text-xs">{printer.model_dpi} dpi</p>
                      )}
                    </div>
                  )}
                  {printer.plant_name && (
                    <div>
                      <span className="text-gray-400 text-xs font-semibold uppercase tracking-wide">Planta</span>
                      <p className="text-gray-800 font-medium">{printer.plant_name}</p>
                    </div>
                  )}
                  {printer.area_name && (
                    <div>
                      <span className="text-gray-400 text-xs font-semibold uppercase tracking-wide">Área</span>
                      <p className="text-gray-800 font-medium">{printer.area_name}</p>
                    </div>
                  )}
                </div>
              </>
            ) : null}
          </div>
        </div>
      </div>

      {/* Technical Stats */}
      {!loadingReports && (
        <div className="bg-white rounded-xl border border-border shadow-sm p-5 space-y-4">
          <div className="flex items-center gap-2">
            <BarChart2 size={16} className="text-primary" />
            <h2 className="font-semibold text-[#1A1A2E] font-heading text-sm">Estadísticas Técnicas</h2>
            <span className="text-xs text-gray-400 font-sans">(últimos 30 días)</span>
          </div>

          {/* Row 1 — 4 KPIs */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            {[
              { label: 'Total reportes', value: String(totalRecent) },
              { label: 'Tipo frecuente', value: tipoFrecuente },
              { label: 'Completados', value: String(completados) },
              { label: 'Pendientes', value: String(pendientes) },
            ].map((kpi) => (
              <div key={kpi.label} className="bg-gray-50 rounded-lg px-3 py-2.5">
                <p className="text-[9px] font-semibold text-gray-400 uppercase tracking-wide font-sans leading-none">{kpi.label}</p>
                <p className="mt-1 text-base font-bold text-[#1A1A2E] font-heading leading-none">{kpi.value}</p>
              </div>
            ))}
          </div>

          {/* Row 2 — última observación + estado general */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            <div className="bg-gray-50 rounded-lg px-3 py-2.5">
              <p className="text-[9px] font-semibold text-gray-400 uppercase tracking-wide font-sans mb-1">Última observación</p>
              <p className="text-sm text-gray-700 font-sans leading-snug">
                {ultimaObs ?? <span className="text-gray-400 italic">Sin notas</span>}
              </p>
            </div>
            <div className="bg-gray-50 rounded-lg px-3 py-2.5">
              <p className="text-[9px] font-semibold text-gray-400 uppercase tracking-wide font-sans mb-1.5">Estado general</p>
              <span className={`inline-flex items-center px-2 py-0.5 border text-xs font-medium rounded-full font-sans ${estadoGeneral.cls}`}>
                {estadoGeneral.label}
              </span>
            </div>
          </div>
        </div>
      )}

      {/* Report History */}
      <div className="bg-white rounded-xl border border-border shadow-sm">
        <div className="px-6 py-4 border-b border-border flex items-center gap-2">
          <FileText size={16} className="text-primary" />
          <h2 className="font-semibold text-[#1A1A2E] font-heading">Historial de Reportes</h2>
          {!loadingReports && total > 0 && (
            <span className="px-2 py-0.5 bg-gray-100 text-gray-600 text-xs rounded-full font-sans">{total}</span>
          )}
        </div>

        {loadingReports ? (
          <SkeletonTable rows={5} cols={4} />
        ) : reports.length === 0 ? (
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
                    <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Estado</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-50">
                  {reports.map((r) => (
                    <tr key={r.id} className="hover:bg-gray-50 transition-colors">
                      <td className="px-6 py-3 text-gray-700 whitespace-nowrap">{fmtDate(r.service_date)}</td>
                      <td className="px-4 py-3 font-mono text-xs text-gray-500">
                        <Link to={`/reportes/${r.id}`} className="text-primary hover:underline">
                          {r.code ?? '—'}
                        </Link>
                      </td>
                      <td className="px-4 py-3 text-gray-700">{r.service_type ?? '—'}</td>
                      <td className="px-4 py-3">
                        <StatusBadge status={r.status} />
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
                  <button
                    onClick={() => setOffset(Math.max(0, offset - LIMIT))}
                    disabled={offset === 0}
                    className="p-1.5 rounded-lg border border-border hover:bg-gray-50 disabled:opacity-40 transition-colors"
                  >
                    <ChevronLeft size={16} />
                  </button>
                  <button
                    onClick={() => setOffset(offset + LIMIT)}
                    disabled={currentPage >= totalPages}
                    className="p-1.5 rounded-lg border border-border hover:bg-gray-50 disabled:opacity-40 transition-colors"
                  >
                    <ChevronRight size={16} />
                  </button>
                </div>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  )
}
