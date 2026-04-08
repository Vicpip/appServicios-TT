import { useState, useMemo } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { ArrowLeft, User, FileText, ChevronLeft, ChevronRight } from 'lucide-react'
import apiClient from '@/api/client'
import { API } from '@/api/endpoints'

interface TechnicianDetail {
  id: string
  code: string | null
  name: string
  email: string
  role: string
  is_active: boolean
  signature_url: string | null
  last_sync_at: string | null
  report_count: number
}

interface ReportRow {
  id: string
  code: string | null
  service_type: string
  service_date: string
  status: string
  printer_serial: string | null
  client_name: string | null
}

type DateRange = 'today' | 'week' | 'month' | 'year' | 'custom'

const PAGE_SIZE = 20

function fmtDate(iso: string) {
  return new Date(iso).toLocaleDateString('es-MX', { day: '2-digit', month: 'short', year: 'numeric' })
}

function startOf(unit: 'day' | 'week' | 'month' | 'year', d: Date): Date {
  const r = new Date(d)
  if (unit === 'day') { r.setHours(0, 0, 0, 0); return r }
  if (unit === 'week') { const day = r.getDay(); r.setDate(r.getDate() - day); r.setHours(0, 0, 0, 0); return r }
  if (unit === 'month') { r.setDate(1); r.setHours(0, 0, 0, 0); return r }
  r.setMonth(0, 1); r.setHours(0, 0, 0, 0); return r
}

function endOf(unit: 'day' | 'week' | 'month' | 'year', d: Date): Date {
  const r = new Date(d)
  if (unit === 'day') { r.setHours(23, 59, 59, 999); return r }
  if (unit === 'week') { const day = r.getDay(); r.setDate(r.getDate() + (6 - day)); r.setHours(23, 59, 59, 999); return r }
  if (unit === 'month') { r.setMonth(r.getMonth() + 1, 0); r.setHours(23, 59, 59, 999); return r }
  r.setMonth(11, 31); r.setHours(23, 59, 59, 999); return r
}

const STATUS_COLORS: Record<string, string> = {
  Synced: 'bg-green-50 text-green-700 border-green-200',
  Signed: 'bg-blue-50 text-blue-700 border-blue-200',
  Draft: 'bg-gray-100 text-gray-500 border-gray-200',
}

export default function TechnicianProfilePage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const [range, setRange] = useState<DateRange>('month')
  const [customFrom, setCustomFrom] = useState('')
  const [customTo, setCustomTo] = useState('')
  const [offset, setOffset] = useState(0)

  const now = new Date()

  const { dateFrom, dateTo } = useMemo(() => {
    if (range === 'today') return { dateFrom: startOf('day', now).toISOString(), dateTo: endOf('day', now).toISOString() }
    if (range === 'week') return { dateFrom: startOf('week', now).toISOString(), dateTo: endOf('week', now).toISOString() }
    if (range === 'month') return { dateFrom: startOf('month', now).toISOString(), dateTo: endOf('month', now).toISOString() }
    if (range === 'year') return { dateFrom: startOf('year', now).toISOString(), dateTo: endOf('year', now).toISOString() }
    return {
      dateFrom: customFrom ? new Date(customFrom).toISOString() : undefined,
      dateTo: customTo ? new Date(customTo + 'T23:59:59').toISOString() : undefined,
    }
  }, [range, customFrom, customTo])

  const { data: tech, isLoading } = useQuery<TechnicianDetail>({
    queryKey: ['tech-detail', id],
    queryFn: async () => {
      const res = await apiClient.get(API.technicians.detail(id!))
      return res.data
    },
    enabled: !!id,
  })

  const { data: reportsData } = useQuery<{ total: number; items: ReportRow[] }>({
    queryKey: ['tech-reports', id, dateFrom, dateTo, offset],
    queryFn: async () => {
      const params: Record<string, string | number> = { offset, limit: PAGE_SIZE }
      if (dateFrom) params.date_from = dateFrom
      if (dateTo) params.date_to = dateTo
      const res = await apiClient.get(API.technicians.reports(id!), { params })
      return res.data
    },
    enabled: !!id,
  })

  const RANGE_TABS: { key: DateRange; label: string }[] = [
    { key: 'today', label: 'Hoy' },
    { key: 'week', label: 'Esta semana' },
    { key: 'month', label: 'Este mes' },
    { key: 'year', label: 'Este año' },
    { key: 'custom', label: 'Personalizado' },
  ]

  if (isLoading) {
    return (
      <div className="p-8 flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" />
      </div>
    )
  }

  if (!tech) {
    return <div className="p-8 text-gray-500 font-sans">Técnico no encontrado.</div>
  }

  const totalPages = Math.ceil((reportsData?.total ?? 0) / PAGE_SIZE)
  const currentPage = Math.floor(offset / PAGE_SIZE) + 1

  const serverBase = typeof window !== 'undefined' ? `${window.location.protocol}//${window.location.hostname}:8000` : ''

  return (
    <div className="p-6 max-w-5xl mx-auto space-y-6">
      {/* Back button */}
      <button
        onClick={() => navigate('/technicians')}
        className="flex items-center gap-2 text-sm text-gray-500 hover:text-gray-800 font-sans transition-colors"
      >
        <ArrowLeft size={16} />
        Volver a Técnicos
      </button>

      {/* Profile + Reports grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left: Profile card */}
        <div className="bg-white rounded-xl border border-border shadow-sm p-6 space-y-4">
          {/* Avatar / Signature */}
          <div className="flex flex-col items-center gap-3">
            {tech.signature_url ? (
              <img
                src={`${serverBase}${tech.signature_url}`}
                alt="Firma"
                className="w-24 h-24 object-contain rounded-xl border border-border bg-gray-50 p-2"
              />
            ) : (
              <div className="w-20 h-20 rounded-full bg-primary/10 flex items-center justify-center">
                <User size={36} className="text-primary" />
              </div>
            )}
            <div className="text-center">
              <h2 className="font-bold text-[#1A1A2E] font-heading text-lg">{tech.name}</h2>
              {tech.code && <p className="text-xs text-primary font-semibold font-mono">{tech.code}</p>}
            </div>
          </div>

          <div className="space-y-2 text-sm font-sans">
            <div className="flex items-center justify-between">
              <span className="text-gray-400">Email</span>
              <span className="text-gray-700 truncate max-w-[140px]">{tech.email}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-gray-400">Rol</span>
              <span className="capitalize text-gray-700">{tech.role}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-gray-400">Estado</span>
              <span className={`px-2 py-0.5 text-xs font-semibold rounded-full border ${tech.is_active ? 'bg-green-50 text-green-700 border-green-200' : 'bg-gray-100 text-gray-500 border-gray-200'}`}>
                {tech.is_active ? 'Activo' : 'Inactivo'}
              </span>
            </div>
            {tech.last_sync_at && (
              <div className="flex items-center justify-between">
                <span className="text-gray-400">Último sync</span>
                <span className="text-gray-600 text-xs">{fmtDate(tech.last_sync_at)}</span>
              </div>
            )}
            <div className="pt-2 border-t border-border flex items-center justify-between">
              <span className="text-gray-400">Total reportes</span>
              <span className="text-lg font-bold text-primary">{tech.report_count}</span>
            </div>
          </div>
        </div>

        {/* Right: Reports with date filter */}
        <div className="lg:col-span-2 bg-white rounded-xl border border-border shadow-sm flex flex-col">
          {/* Date filter tabs */}
          <div className="px-4 pt-4 border-b border-border">
            <div className="flex gap-1 flex-wrap">
              {RANGE_TABS.map((tab) => (
                <button
                  key={tab.key}
                  onClick={() => { setRange(tab.key); setOffset(0) }}
                  className={`px-3 py-1.5 text-xs font-semibold rounded-lg transition-colors font-sans ${
                    range === tab.key
                      ? 'bg-primary text-white'
                      : 'text-gray-500 hover:text-gray-800 hover:bg-gray-100'
                  }`}
                >
                  {tab.label}
                </button>
              ))}
            </div>
            {range === 'custom' && (
              <div className="flex gap-2 mt-3 pb-3">
                <input
                  type="date"
                  value={customFrom}
                  onChange={(e) => { setCustomFrom(e.target.value); setOffset(0) }}
                  className="text-sm font-sans border border-border rounded-lg px-3 py-1.5 focus:outline-none focus:ring-2 focus:ring-primary/30"
                />
                <span className="text-gray-400 self-center">—</span>
                <input
                  type="date"
                  value={customTo}
                  onChange={(e) => { setCustomTo(e.target.value); setOffset(0) }}
                  className="text-sm font-sans border border-border rounded-lg px-3 py-1.5 focus:outline-none focus:ring-2 focus:ring-primary/30"
                />
              </div>
            )}
          </div>

          {/* Report count */}
          <div className="px-4 py-3 flex items-center gap-2">
            <FileText size={14} className="text-primary" />
            <span className="text-sm font-semibold text-gray-700 font-sans">
              {reportsData?.total ?? 0} reportes en el período
            </span>
          </div>

          {/* Table */}
          {!reportsData || reportsData.items.length === 0 ? (
            <div className="flex-1 p-8 text-center text-gray-400 font-sans text-sm">
              Sin reportes en el período seleccionado.
            </div>
          ) : (
            <>
              <div className="flex-1 overflow-x-auto">
                <table className="w-full text-sm font-sans">
                  <thead>
                    <tr className="border-b border-border bg-gray-50">
                      <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Fecha</th>
                      <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Código</th>
                      <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Tipo</th>
                      <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Impresora</th>
                      <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Cliente</th>
                      <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Estado</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-50">
                    {reportsData.items.map((r) => (
                      <tr key={r.id} className="hover:bg-gray-50 transition-colors">
                        <td className="px-4 py-3 text-gray-700 whitespace-nowrap">{fmtDate(r.service_date)}</td>
                        <td className="px-4 py-3 text-gray-500 font-mono text-xs">{r.code ?? '—'}</td>
                        <td className="px-4 py-3 text-gray-700">{r.service_type}</td>
                        <td className="px-4 py-3 text-gray-600">{r.printer_serial ?? '—'}</td>
                        <td className="px-4 py-3 text-gray-600">{r.client_name ?? '—'}</td>
                        <td className="px-4 py-3">
                          <span className={`inline-flex px-2 py-0.5 text-xs font-medium rounded-full border ${STATUS_COLORS[r.status] ?? 'bg-gray-100 text-gray-500 border-gray-200'}`}>
                            {r.status}
                          </span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              {totalPages > 1 && (
                <div className="px-4 py-3 border-t border-border flex items-center justify-between text-sm font-sans">
                  <span className="text-gray-500">Pág. {currentPage} / {totalPages}</span>
                  <div className="flex gap-2">
                    <button onClick={() => setOffset(Math.max(0, offset - PAGE_SIZE))} disabled={offset === 0} className="p-1.5 rounded-lg border border-border hover:bg-gray-50 disabled:opacity-40 transition-colors">
                      <ChevronLeft size={14} />
                    </button>
                    <button onClick={() => setOffset(offset + PAGE_SIZE)} disabled={currentPage >= totalPages} className="p-1.5 rounded-lg border border-border hover:bg-gray-50 disabled:opacity-40 transition-colors">
                      <ChevronRight size={14} />
                    </button>
                  </div>
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  )
}
