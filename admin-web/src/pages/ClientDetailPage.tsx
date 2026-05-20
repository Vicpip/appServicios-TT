import { useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import {
  ArrowLeft, Building2, MapPin, Printer,
  CheckCircle2, AlertTriangle, Award,
} from 'lucide-react'
import apiClient from '@/api/client'
import { API } from '@/api/endpoints'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface ClientInfo {
  id: string
  name: string
  rfc: string | null
  address: string | null
  is_active: boolean
}

interface PlantInfo {
  id: string
  name: string
  contact_name: string | null
  phone: string | null
}

interface ReportsMes {
  total: number
  preventivos: number
  correctivos: number
  diagnosticos: number
}

interface TopPrinter {
  serial_number: string
  code: string | null
  model_name: string | null
  total_reportes: number
}

interface ClientStats {
  total_impresoras: number
  impresoras_activas: number
  impresoras_en_atencion: number
  reportes_ultimo_mes: ReportsMes
  polizas_activas: number
  polizas_vencidas: number
  impresora_mas_servicios: TopPrinter | null
}

interface PrinterRow {
  id: string
  code: string | null
  serial_number: string
  is_active: boolean
  model_name: string | null
  area_name: string | null
  plant_name: string | null
  ultimo_contador: number | null
  en_atencion: boolean
  total_reportes: number
}

interface ClientDetailData {
  client: ClientInfo
  plants: PlantInfo[]
  stats: ClientStats
  printers: PrinterRow[]
}

// ---------------------------------------------------------------------------
// KPI card — ultra-compact for grid-cols-6
// ---------------------------------------------------------------------------

function KpiCard({
  label,
  value,
  sub,
  alert,
}: {
  label: string
  value: React.ReactNode
  sub?: React.ReactNode
  alert?: boolean
}) {
  return (
    <div className={`bg-white rounded-xl border shadow-sm p-3 ${alert ? 'border-red-200' : 'border-border'}`}>
      <p className="text-[9px] font-semibold text-gray-400 uppercase tracking-wide font-sans leading-none truncate">
        {label}
      </p>
      <p className={`mt-1 text-lg font-bold font-heading leading-none ${alert ? 'text-red-600' : 'text-[#1A1A2E]'}`}>
        {value}
      </p>
      {sub && <div className="mt-1">{sub}</div>}
    </div>
  )
}

// ---------------------------------------------------------------------------
// Main page
// ---------------------------------------------------------------------------

export default function ClientDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const [selectedPlant, setSelectedPlant] = useState<string | null>(null)

  const { data, isLoading } = useQuery<ClientDetailData>({
    queryKey: ['client-detail', id],
    queryFn: async () => {
      const res = await apiClient.get(API.clients.clientDetail(id!))
      return res.data
    },
    enabled: !!id,
  })

  if (isLoading) {
    return (
      <div className="p-8 flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" />
      </div>
    )
  }

  if (!data) {
    return <div className="p-8 text-gray-500 font-sans">Cliente no encontrado.</div>
  }

  const { client, plants, stats, printers } = data
  const s = stats

  // Plant filter — derive unique names from printer rows
  const plantNames = Array.from(
    new Set(printers.map((p) => p.plant_name).filter((n): n is string => !!n))
  )
  const visiblePrinters =
    selectedPlant ? printers.filter((p) => p.plant_name === selectedPlant) : printers

  return (
    <div className="p-6 max-w-6xl mx-auto space-y-3">

      {/* Back */}
      <button
        onClick={() => navigate('/clients')}
        className="flex items-center gap-2 text-sm text-gray-500 hover:text-gray-800 font-sans transition-colors"
      >
        <ArrowLeft size={16} />
        Volver a Clientes
      </button>

      {/* ------------------------------------------------------------------ */}
      {/* Client info card                                                     */}
      {/* ------------------------------------------------------------------ */}
      <div className="bg-white rounded-xl border border-border shadow-sm p-4">
        <div className="flex items-start gap-3">
          <div className="p-2.5 bg-primary/10 rounded-xl shrink-0">
            <Building2 size={20} className="text-primary" />
          </div>
          <div className="flex-1 min-w-0">
            {/* Name + status */}
            <div className="flex items-center gap-2.5 flex-wrap">
              <h1 className="text-lg font-bold text-[#1A1A2E] font-heading leading-tight">{client.name}</h1>
              <span
                className={`px-2 py-0.5 text-[10px] font-semibold rounded-full border font-sans ${
                  client.is_active
                    ? 'bg-green-50 text-green-700 border-green-200'
                    : 'bg-gray-100 text-gray-500 border-gray-200'
                }`}
              >
                {client.is_active ? 'Activo' : 'Inactivo'}
              </span>
            </div>

            {/* RFC + address inline */}
            <div className="mt-1.5 flex flex-wrap gap-x-4 gap-y-0.5 text-xs font-sans text-gray-500">
              {client.rfc && (
                <span>
                  <span className="text-gray-400 font-semibold uppercase tracking-wide text-[9px]">RFC </span>
                  <span className="font-mono text-gray-700">{client.rfc}</span>
                </span>
              )}
              {client.address && (
                <span className="truncate max-w-xs">{client.address}</span>
              )}
            </div>

            {/* Plants — inline if 1, chips if multiple */}
            {plants.length === 1 && (() => {
              const pl = plants[0]!
              return (
                <div className="mt-2 flex items-center gap-2 flex-wrap text-xs font-sans">
                  <MapPin size={11} className="text-primary shrink-0" />
                  <span className="font-medium text-gray-700">{pl.name}</span>
                  {pl.contact_name && (
                    <span className="text-gray-400">· {pl.contact_name}</span>
                  )}
                  {pl.phone && (
                    <span className="text-gray-400">· {pl.phone}</span>
                  )}
                </div>
              )
            })()}
            {plants.length > 1 && (
              <div className="mt-2 flex items-center gap-1.5 flex-wrap">
                <MapPin size={11} className="text-primary shrink-0" />
                {plants.map((pl) => (
                  <span
                    key={pl.id}
                    className="inline-flex items-center gap-1 px-2 py-0.5 bg-gray-100 text-gray-600 text-[10px] font-medium rounded-full font-sans"
                    title={[pl.contact_name, pl.phone].filter(Boolean).join(' · ')}
                  >
                    {pl.name}
                  </span>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* ------------------------------------------------------------------ */}
      {/* KPIs — 6 columnas en una sola fila                                  */}
      {/* ------------------------------------------------------------------ */}
      <div className="grid grid-cols-6 gap-3">
        <KpiCard label="Impresoras" value={s.total_impresoras} />
        <KpiCard
          label="Activas"
          value={s.impresoras_activas}
          sub={
            <span className="text-[9px] text-gray-400 font-sans">
              {s.total_impresoras - s.impresoras_activas} inact.
            </span>
          }
        />
        <KpiCard
          label="En atención"
          value={
            <span className="inline-flex items-center gap-1">
              {s.impresoras_en_atencion}
              {s.impresoras_en_atencion > 0 && <AlertTriangle size={13} className="text-red-500" />}
            </span>
          }
          alert={s.impresoras_en_atencion > 0}
        />
        <KpiCard
          label="Reportes 30d"
          value={s.reportes_ultimo_mes.total}
          sub={
            s.reportes_ultimo_mes.total > 0 ? (
              <div className="flex gap-1">
                {s.reportes_ultimo_mes.preventivos > 0 && (
                  <span className="px-1 py-px text-[8px] font-medium bg-blue-50 text-blue-700 border border-blue-200 rounded font-sans">
                    {s.reportes_ultimo_mes.preventivos}P
                  </span>
                )}
                {s.reportes_ultimo_mes.correctivos > 0 && (
                  <span className="px-1 py-px text-[8px] font-medium bg-orange-50 text-orange-700 border border-orange-200 rounded font-sans">
                    {s.reportes_ultimo_mes.correctivos}C
                  </span>
                )}
                {s.reportes_ultimo_mes.diagnosticos > 0 && (
                  <span className="px-1 py-px text-[8px] font-medium bg-violet-50 text-violet-700 border border-violet-200 rounded font-sans">
                    {s.reportes_ultimo_mes.diagnosticos}D
                  </span>
                )}
              </div>
            ) : null
          }
        />
        <KpiCard
          label="Pólizas activas"
          value={s.polizas_activas}
          sub={
            <span className="inline-flex items-center gap-0.5 text-[9px] text-green-600 font-sans">
              <CheckCircle2 size={9} />
              Vigentes
            </span>
          }
        />
        <KpiCard
          label="Pólizas vencidas"
          value={s.polizas_vencidas}
          alert={s.polizas_vencidas > 0}
        />
      </div>

      {/* ------------------------------------------------------------------ */}
      {/* Impresora con más servicios                                         */}
      {/* ------------------------------------------------------------------ */}
      {s.impresora_mas_servicios && (
        <div className="bg-white rounded-xl border border-border shadow-sm px-4 py-3">
          <div className="flex items-center gap-4 flex-wrap">
            <div className="flex items-center gap-2 shrink-0">
              <Award size={14} className="text-primary" />
              <span className="text-xs font-semibold text-gray-500 uppercase tracking-wide font-sans">
                Más servicios
              </span>
            </div>
            <div className="flex items-center gap-2.5">
              <div className="p-2 bg-primary/10 rounded-lg shrink-0">
                <Printer size={15} className="text-primary" />
              </div>
              <div>
                <p className="font-bold text-[#1A1A2E] font-heading text-sm leading-tight">
                  {s.impresora_mas_servicios.serial_number}
                </p>
                {s.impresora_mas_servicios.code && (
                  <span className="text-[9px] text-primary font-semibold font-sans">
                    {s.impresora_mas_servicios.code}
                  </span>
                )}
              </div>
            </div>
            {s.impresora_mas_servicios.model_name && (
              <span className="text-xs text-gray-500 font-sans">
                {s.impresora_mas_servicios.model_name}
              </span>
            )}
            <div className="ml-auto flex items-baseline gap-1.5">
              <span className="text-xl font-bold text-primary font-heading leading-none">
                {s.impresora_mas_servicios.total_reportes}
              </span>
              <span className="text-[10px] text-gray-400 font-sans">reportes</span>
            </div>
          </div>
        </div>
      )}

      {/* ------------------------------------------------------------------ */}
      {/* Printers table                                                      */}
      {/* ------------------------------------------------------------------ */}
      <div className="bg-white rounded-xl border border-border shadow-sm">

        {/* Table header */}
        <div className="px-4 py-3 border-b border-border flex items-center gap-2">
          <Printer size={15} className="text-primary" />
          <h2 className="font-semibold text-[#1A1A2E] font-heading text-sm">Impresoras</h2>
          <span className="px-2 py-0.5 bg-gray-100 text-gray-600 text-xs rounded-full font-sans">
            {visiblePrinters.length}
          </span>
          <p className="ml-auto text-xs text-gray-400 font-sans hidden sm:block">
            Clic en una fila para ver el detalle
          </p>
        </div>

        {/* Plant filter pills */}
        {plantNames.length > 1 && (
          <div className="px-4 py-2 border-b border-border flex items-center gap-1.5 flex-wrap bg-gray-50/60">
            {([null, ...plantNames] as (string | null)[]).map((plant) => (
              <button
                key={plant ?? '__all__'}
                onClick={() => setSelectedPlant(plant)}
                className={`px-3 py-1 text-xs font-medium rounded-full transition-colors font-sans ${
                  selectedPlant === plant
                    ? 'bg-primary text-white'
                    : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                }`}
              >
                {plant ?? 'Todas'}
              </button>
            ))}
          </div>
        )}

        {/* Table body */}
        {printers.length === 0 ? (
          <div className="p-8 text-center text-gray-400 font-sans text-sm">
            Sin impresoras registradas para este cliente.
          </div>
        ) : visiblePrinters.length === 0 ? (
          <div className="p-6 text-center text-gray-400 font-sans text-sm">
            Sin impresoras para esta planta.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm font-sans">
              <thead>
                <tr className="border-b border-border bg-gray-50">
                  {['Código', 'Serie', 'Modelo', 'Planta', 'Área', 'Últ. contador', 'Estado', 'Reportes'].map(
                    (h) => (
                      <th
                        key={h}
                        className="text-left px-4 py-2.5 text-xs font-semibold text-gray-500 uppercase tracking-wide whitespace-nowrap"
                      >
                        {h}
                      </th>
                    )
                  )}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-50">
                {visiblePrinters.map((p) => (
                  <tr
                    key={p.id}
                    onClick={() => navigate(`/printers/${p.id}`)}
                    className="hover:bg-primary/[0.03] transition-colors cursor-pointer"
                  >
                    <td className="px-4 py-2.5 font-mono text-xs text-gray-500">{p.code ?? '—'}</td>
                    <td className="px-4 py-2.5 text-gray-800 font-medium whitespace-nowrap">{p.serial_number}</td>
                    <td className="px-4 py-2.5 text-gray-600">{p.model_name ?? '—'}</td>
                    <td className="px-4 py-2.5 text-gray-600">{p.plant_name ?? '—'}</td>
                    <td className="px-4 py-2.5 text-gray-600">{p.area_name ?? '—'}</td>
                    <td className="px-4 py-2.5 text-gray-600 text-right tabular-nums">
                      {p.ultimo_contador !== null ? `${p.ultimo_contador} pulg.` : '—'}
                    </td>
                    <td className="px-4 py-2.5">
                      {p.en_atencion ? (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 text-xs font-semibold rounded-full bg-red-50 text-red-700 border border-red-200 font-sans">
                          <AlertTriangle size={10} />
                          En atención
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 text-xs font-semibold rounded-full bg-green-50 text-green-700 border border-green-200 font-sans">
                          <CheckCircle2 size={10} />
                          OK
                        </span>
                      )}
                    </td>
                    <td className="px-4 py-2.5 text-gray-600 text-right tabular-nums">{p.total_reportes}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

    </div>
  )
}
