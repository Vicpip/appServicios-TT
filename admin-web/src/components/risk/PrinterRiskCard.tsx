import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Activity, AlertTriangle, CheckCircle2, Info, Loader2, RefreshCw } from 'lucide-react'
import apiClient from '@/api/client'
import { API } from '@/api/endpoints'
import RiskLevelBadge, { MonitoreoTag } from '@/components/risk/RiskLevelBadge'
import { useRiskModule } from '@/hooks/useRiskModule'
import {
  PIEZA_LABEL, RIESGO_AYUDA, RIESGO_AYUDA_INDICE, fmtFecha, fmtFechaHora,
  isNotFound, notFoundDetail, readErrorMessage, refreshErrorMessage,
} from '@/lib/risk'
import type { EquipoSnapshot, Pieza, PiezaSnapshot, RefreshRespuesta } from '@/types/risk'

function PiezaFila({ pieza, datos }: { pieza: Pieza; datos: PiezaSnapshot }) {
  return (
    <div className="bg-gray-50 rounded-lg px-3 py-2.5 space-y-1.5">
      <div className="flex items-center gap-2 flex-wrap">
        <p className="text-[11px] font-semibold text-gray-500 uppercase tracking-wide font-sans">{PIEZA_LABEL[pieza]}</p>
        {datos.en_monitoreo && <MonitoreoTag />}
      </div>
      <div className="flex items-center gap-2 flex-wrap">
        <RiskLevelBadge nivel={datos.nivel} />
        <span className="text-sm text-gray-800 font-sans">
          Índice <strong>{Math.round(datos.indice_riesgo)}</strong> / 100
        </span>
      </div>
      <div className="flex flex-wrap gap-1.5">
        {datos.dano_detectado_en_notas && (
          <span className="inline-flex px-2 py-0.5 rounded-full border border-blue-200 bg-blue-50 text-blue-800 text-[11px] font-medium font-sans">
            Daño detectado en notas
          </span>
        )}
        {datos.danada_en_ultima_visita && (
          <span className="inline-flex px-2 py-0.5 rounded-full border border-gray-300 bg-white text-gray-700 text-[11px] font-medium font-sans">
            Dañada en la última visita
          </span>
        )}
        {datos.danos_previos > 0 && (
          <span className="inline-flex px-2 py-0.5 rounded-full border border-gray-300 bg-white text-gray-700 text-[11px] font-medium font-sans">
            {datos.danos_previos} daño{datos.danos_previos !== 1 ? 's' : ''} previo{datos.danos_previos !== 1 ? 's' : ''}
          </span>
        )}
      </div>
    </div>
  )
}

function Detalle({ equipo, mostrarContexto }: { equipo: EquipoSnapshot; mostrarContexto: boolean }) {
  return (
    <div className="space-y-3">
      {mostrarContexto && (
        <p className="text-xs text-gray-600 font-sans">
          {[equipo.code, equipo.numero_serie, equipo.modelo_impresora, equipo.client_name,
            [equipo.plant_name, equipo.area_name].filter(Boolean).join(' / ')]
            .filter(Boolean).join(' · ')}
        </p>
      )}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
        <PiezaFila pieza="cabezal" datos={equipo.cabezal} />
        <PiezaFila pieza="rodillo" datos={equipo.rodillo} />
      </div>

      <p className="text-xs text-gray-600 font-sans">
        {RIESGO_AYUDA} {RIESGO_AYUDA_INDICE}
      </p>

      <div className="flex flex-wrap gap-1.5">
        {equipo.stale && (
          <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full border border-amber-300 bg-amber-50 text-amber-900 text-xs font-medium font-sans">
            Desactualizado: hay reportes más nuevos que este cálculo
          </span>
        )}
        {!equipo.vigente && (
          <span className="inline-flex px-2 py-0.5 rounded-full border border-gray-300 bg-gray-100 text-gray-700 text-xs font-medium font-sans">
            Estimación vencida
          </span>
        )}
        {equipo.modelo_desactualizado && (
          <span className="inline-flex px-2 py-0.5 rounded-full border border-amber-300 bg-amber-50 text-amber-900 text-xs font-medium font-sans">
            Calculado con otra versión del modelo
          </span>
        )}
      </div>

      {equipo.historial_corto && (
        <div className="flex items-start gap-2 bg-amber-50 border border-amber-200 text-amber-900 text-sm rounded-lg px-3 py-2 font-sans">
          <AlertTriangle size={14} className="mt-0.5 shrink-0" aria-hidden="true" />
          <span>Historial corto: hay pocas visitas registradas, la estimación es poco fiable.</span>
        </div>
      )}

      <dl className="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm font-sans">
        <div>
          <dt className="text-xs text-gray-400 font-semibold uppercase tracking-wide">Calculado el</dt>
          <dd className="text-gray-800">{fmtFechaHora(equipo.computed_at)}</dd>
        </div>
        <div>
          <dt className="text-xs text-gray-400 font-semibold uppercase tracking-wide">Válido hasta</dt>
          <dd className="text-gray-800">{fmtFecha(equipo.vigente_hasta)}</dd>
        </div>
        <div>
          <dt className="text-xs text-gray-400 font-semibold uppercase tracking-wide">Versión del modelo</dt>
          <dd className="text-gray-800">{equipo.version_modelo}</dd>
        </div>
        <div>
          <dt className="text-xs text-gray-400 font-semibold uppercase tracking-wide">Visitas</dt>
          <dd className="text-gray-800">
            {equipo.visitas_app} de la app + {equipo.visitas_historicas} históricas
          </dd>
        </div>
      </dl>
    </div>
  )
}

/** `mostrarContexto`: línea código · serie · modelo · cliente · planta/área (omitida en el detalle de impresora, cuyo encabezado ya la tiene). */
export default function PrinterRiskCard({ printerId, mostrarContexto = false }: { printerId: string; mostrarContexto?: boolean }) {
  const qc = useQueryClient()
  const { available } = useRiskModule()
  const [exito, setExito] = useState<string | null>(null)
  const [errorMsg, setErrorMsg] = useState<string | null>(null)

  const query = useQuery<EquipoSnapshot>({
    queryKey: ['risk-printer', printerId],
    queryFn: async () => (await apiClient.get<EquipoSnapshot>(API.risk.printer(printerId))).data,
    enabled: available,
    retry: false,
  })

  const refresh = useMutation({
    mutationFn: async () =>
      (await apiClient.post<RefreshRespuesta>(API.risk.refreshPrinter(printerId))).data,
    onMutate: () => { setExito(null); setErrorMsg(null) },
    onSuccess: (res) => {
      const equipo = res.equipos[0]
      if (equipo) qc.setQueryData(['risk-printer', printerId], equipo)
      qc.invalidateQueries({ queryKey: ['risk-list'] })
      setExito('Riesgo actualizado correctamente.')
    },
    onError: (err: unknown) => setErrorMsg(refreshErrorMessage(err, 'impresora')),
  })

  if (!available) return null

  const sinCalculo = query.isError && isNotFound(query.error)

  return (
    <div className="bg-white rounded-xl border border-border shadow-sm p-5 space-y-4">
      <div className="flex items-center justify-between gap-3 flex-wrap">
        <div className="flex items-center gap-2">
          <Activity size={16} className="text-primary" aria-hidden="true" />
          <h2 className="font-semibold text-[#1A1A2E] font-heading text-sm">Riesgo de piezas</h2>
        </div>
        <button
          onClick={() => refresh.mutate()}
          disabled={refresh.isPending}
          className="flex items-center gap-2 px-3 py-1.5 text-sm font-semibold text-primary border border-primary/40 rounded-lg hover:bg-primary/5 disabled:opacity-50 transition-colors font-sans"
        >
          {refresh.isPending
            ? <Loader2 size={14} className="animate-spin" aria-hidden="true" />
            : <RefreshCw size={14} aria-hidden="true" />}
          {refresh.isPending ? 'Actualizando…' : 'Actualizar riesgo'}
        </button>
      </div>

      {exito && (
        <div role="status" className="flex items-center gap-2 bg-green-50 border border-green-200 text-green-800 text-sm rounded-lg px-3 py-2 font-sans">
          <CheckCircle2 size={14} aria-hidden="true" /> {exito}
        </div>
      )}
      {errorMsg && (
        <div role="alert" className="bg-red-50 border border-red-200 text-red-700 text-sm rounded-lg px-3 py-2 font-sans">
          {errorMsg}
        </div>
      )}

      {query.isLoading ? (
        <div className="h-24 bg-gray-100 rounded-lg animate-pulse" />
      ) : sinCalculo ? (
        <div className="flex items-start gap-2 text-sm text-gray-600 font-sans">
          <Info size={14} className="mt-0.5 shrink-0" aria-hidden="true" />
          <span>{notFoundDetail(query.error) ?? 'Aún no se ha calculado el riesgo de esta impresora.'}</span>
        </div>
      ) : query.isError ? (
        <div role="alert" className="bg-red-50 border border-red-200 text-red-700 text-sm rounded-lg px-3 py-2 font-sans">
          {readErrorMessage(query.error)}
        </div>
      ) : query.data ? (
        <Detalle equipo={query.data} mostrarContexto={mostrarContexto} />
      ) : null}
    </div>
  )
}
