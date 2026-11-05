import { useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { Activity, ChevronLeft, ChevronRight, Info } from 'lucide-react'
import apiClient from '@/api/client'
import { API } from '@/api/endpoints'
import RiskLevelBadge, { MonitoreoTag } from '@/components/risk/RiskLevelBadge'
import { RIESGO_AYUDA, RIESGO_AYUDA_INDICE, fmtFecha, fmtFechaHora, readErrorMessage } from '@/lib/risk'
import type { EquipoSnapshot, Nivel, Pieza, PiezaSnapshot, RiesgoSnapshots } from '@/types/risk'

const PAGE_SIZE = 25
const FETCH_LIMIT = 500   // máximo del contrato; se pagina en cliente

type Orden = 'desc' | 'asc'

const selectCls =
  'text-sm font-sans border border-border rounded-lg px-3 py-2 bg-white text-gray-700 focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition-colors'

function maxIndice(e: EquipoSnapshot, pieza: Pieza | ''): number {
  return pieza ? e[pieza].indice_riesgo : Math.max(e.cabezal.indice_riesgo, e.rodillo.indice_riesgo)
}

function CeldaPieza({ datos }: { datos: PiezaSnapshot }) {
  return (
    <div className="space-y-1">
      <div className="flex items-center gap-2 flex-wrap">
        <RiskLevelBadge nivel={datos.nivel} />
        <span className="text-sm text-gray-700 font-sans tabular-nums">{Math.round(datos.indice_riesgo)}</span>
      </div>
      {datos.en_monitoreo && <MonitoreoTag />}
      {datos.dano_detectado_en_notas && (
        <p className="text-[10px] text-blue-800 font-sans">Daño detectado en notas</p>
      )}
    </div>
  )
}

export default function RiskPage() {
  const navigate = useNavigate()
  const [level, setLevel] = useState<Nivel | ''>('')
  const [piece, setPiece] = useState<Pieza | ''>('')
  const [clientId, setClientId] = useState('')
  const [plantId, setPlantId] = useState('')
  const [orden, setOrden] = useState<Orden>('desc')
  const [page, setPage] = useState(0)

  // Nivel y pieza se filtran en el servidor; cliente y planta en el cliente, con los datos de la propia respuesta.
  const params = {
    limit: FETCH_LIMIT,
    ...(level && { level }),
    ...(piece && { piece }),
  }
  const { data, isLoading, isError, error } = useQuery<RiesgoSnapshots>({
    queryKey: ['risk-list', params],
    queryFn: async () => (await apiClient.get<RiesgoSnapshots>(API.risk.printers, { params })).data,
    placeholderData: (prev) => prev,
    retry: false,
  })

  const todos = useMemo(() => data?.equipos ?? [], [data])

  const clientes = useMemo(() => {
    const m = new Map<string, string>()
    todos.forEach((e) => m.set(e.client_id, e.client_name ?? 'Sin nombre'))
    return [...m].sort((a, b) => a[1].localeCompare(b[1], 'es'))
  }, [todos])

  const plantas = useMemo(() => {
    const m = new Map<string, string>()
    todos.forEach((e) => {
      if (e.plant_id && (!clientId || e.client_id === clientId)) m.set(e.plant_id, e.plant_name ?? 'Sin nombre')
    })
    return [...m].sort((a, b) => a[1].localeCompare(b[1], 'es'))
  }, [todos, clientId])

  const equipos = useMemo(() => {
    const base = todos.filter((e) => (!clientId || e.client_id === clientId) && (!plantId || e.plant_id === plantId))
    return orden === 'desc' ? base : [...base].reverse()
  }, [todos, clientId, plantId, orden])

  const totalPages = Math.max(1, Math.ceil(equipos.length / PAGE_SIZE))
  const pagina = Math.min(page, totalPages - 1)
  const visibles = equipos.slice(pagina * PAGE_SIZE, (pagina + 1) * PAGE_SIZE)
  const hayFiltros = Boolean(level || piece || clientId || plantId)
  const sinSnapshots = !!data && data.equipos.length === 0 && !hayFiltros
  const truncado = !!data && data.total > data.equipos.length

  function cambiar(fn: () => void) { fn(); setPage(0) }

  return (
    <div className="space-y-4">
      <div>
        <h2 className="text-xl font-bold text-[#1A1A2E] font-heading">Riesgo de piezas</h2>
        <p className="text-sm text-gray-600 font-sans mt-0.5">{RIESGO_AYUDA}</p>
        <p className="text-xs text-gray-500 font-sans mt-0.5">
          {RIESGO_AYUDA_INDICE} El rodillo está en monitoreo (evidencia débil); el cabezal se presenta como nivel de riesgo.
        </p>
      </div>

      <div className="bg-white rounded-xl border border-border p-4 shadow-sm">
        <div className="flex flex-wrap gap-3 items-center">
          <select aria-label="Filtrar por nivel" value={level}
            onChange={(e) => cambiar(() => setLevel(e.target.value as Nivel | ''))} className={selectCls}>
            <option value="">Todos los niveles</option>
            <option value="ALTO">ALTO</option>
            <option value="MEDIO">MEDIO</option>
            <option value="BAJO">BAJO</option>
          </select>
          <select aria-label="Filtrar por pieza" value={piece}
            onChange={(e) => cambiar(() => setPiece(e.target.value as Pieza | ''))} className={selectCls}>
            <option value="">Ambas piezas</option>
            <option value="cabezal">Cabezal</option>
            <option value="rodillo">Rodillo (en monitoreo)</option>
          </select>
          <select aria-label="Filtrar por cliente" value={clientId}
            onChange={(e) => cambiar(() => { setClientId(e.target.value); setPlantId('') })} className={selectCls}>
            <option value="">Todos los clientes</option>
            {clientes.map(([id, name]) => <option key={id} value={id}>{name}</option>)}
          </select>
          <select aria-label="Filtrar por planta" value={plantId}
            onChange={(e) => cambiar(() => setPlantId(e.target.value))} className={selectCls}>
            <option value="">Todas las plantas</option>
            {plantas.map(([id, name]) => <option key={id} value={id}>{name}</option>)}
          </select>
          <select aria-label="Orden" value={orden}
            onChange={(e) => cambiar(() => setOrden(e.target.value as Orden))} className={selectCls}>
            <option value="desc">Mayor riesgo primero</option>
            <option value="asc">Menor riesgo primero</option>
          </select>
          {hayFiltros && (
            <button onClick={() => cambiar(() => { setLevel(''); setPiece(''); setClientId(''); setPlantId('') })}
              className="text-xs text-gray-500 hover:text-primary font-sans transition-colors">
              Limpiar filtros
            </button>
          )}
        </div>
        {level && !piece && (
          <p className="text-xs text-gray-500 font-sans mt-2">
            Sin elegir pieza, el nivel aplica a cualquiera de las dos.
          </p>
        )}
      </div>

      {isError && (
        <div role="alert" className="bg-red-50 border border-red-200 text-red-700 text-sm rounded-lg px-4 py-3 font-sans">
          {readErrorMessage(error)}
        </div>
      )}

      {truncado && (
        <div className="flex items-start gap-2 bg-amber-50 border border-amber-200 text-amber-900 text-sm rounded-lg px-4 py-2 font-sans">
          <Info size={14} className="mt-0.5 shrink-0" aria-hidden="true" />
          Se muestran las {data.equipos.length} impresoras de mayor riesgo de {data.total}. Usa los filtros para acotar.
        </div>
      )}

      <div className="bg-white rounded-xl border border-border shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-gray-50 border-b border-border text-left">
                {['Código', 'Serie', 'Modelo', 'Cliente', 'Planta / Área', 'Cabezal (nivel · índice)', 'Rodillo (nivel · índice)', 'Calculado', 'Estado'].map((h) => (
                  <th key={h} className="px-3 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide font-sans">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {isLoading ? (
                Array.from({ length: 6 }).map((_, i) => (
                  <tr key={i} className="animate-pulse">
                    {Array.from({ length: 9 }).map((_, j) => (
                      <td key={j} className="px-3 py-3.5"><div className="h-4 bg-gray-100 rounded" /></td>
                    ))}
                  </tr>
                ))
              ) : visibles.length === 0 ? (
                <tr>
                  <td colSpan={9} className="px-4 py-12 text-center text-sm text-gray-500 font-sans">
                    <Activity size={28} className="mx-auto mb-2 text-gray-300" aria-hidden="true" />
                    {sinSnapshots
                      ? 'Aún no se ha calculado el riesgo. Usa «Actualizar riesgo» en una impresora o en una póliza.'
                      : 'No hay impresoras con los filtros aplicados.'}
                    {sinSnapshots && data && data.sin_calcular > 0 && (
                      <span className="block text-xs text-gray-400 mt-1">
                        {data.sin_calcular} impresora{data.sin_calcular !== 1 ? 's' : ''} pendiente{data.sin_calcular !== 1 ? 's' : ''} de cálculo.
                      </span>
                    )}
                  </td>
                </tr>
              ) : (
                visibles.map((e) => (
                  <tr key={e.printer_id} onClick={() => navigate(`/printers/${e.printer_id}`)}
                    className="hover:bg-gray-50/60 transition-colors cursor-pointer align-top"
                    title={`Índice máximo ${Math.round(maxIndice(e, piece))}`}>
                    <td className="px-3 py-3.5 font-mono text-xs text-primary font-semibold whitespace-nowrap">{e.code ?? '—'}</td>
                    <td className="px-3 py-3.5 font-mono text-xs text-gray-700 whitespace-nowrap">{e.numero_serie}</td>
                    <td className="px-3 py-3.5 text-gray-600 font-sans whitespace-nowrap">{e.modelo_impresora}</td>
                    <td className="px-3 py-3.5 text-gray-700 font-sans">{e.client_name ?? '—'}</td>
                    <td className="px-3 py-3.5 text-gray-500 font-sans">
                      {[e.plant_name, e.area_name].filter(Boolean).join(' / ') || '—'}
                    </td>
                    <td className="px-3 py-3.5"><CeldaPieza datos={e.cabezal} /></td>
                    <td className="px-3 py-3.5"><CeldaPieza datos={e.rodillo} /></td>
                    <td className="px-3 py-3.5 text-gray-500 font-sans">
                      {fmtFechaHora(e.computed_at)}
                      <span className="block text-[11px] text-gray-400">Última visita {fmtFecha(e.fecha_ultima_visita)}</span>
                    </td>
                    <td className="px-3 py-3.5">
                      <div className="flex flex-col gap-1 items-start">
                        {e.stale && (
                          <span className="px-2 py-0.5 rounded-full border border-amber-300 bg-amber-50 text-amber-900 text-[11px] font-medium font-sans">Desactualizado</span>
                        )}
                        {e.historial_corto && (
                          <span className="px-2 py-0.5 rounded-full border border-gray-300 bg-gray-50 text-gray-700 text-[11px] font-medium font-sans">Historial corto</span>
                        )}
                        {!e.vigente && (
                          <span className="px-2 py-0.5 rounded-full border border-gray-300 bg-gray-100 text-gray-700 text-[11px] font-medium font-sans">Vencido</span>
                        )}
                        {!e.stale && !e.historial_corto && e.vigente && <span className="text-gray-400 text-xs">—</span>}
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
        {equipos.length > PAGE_SIZE && (
          <div className="px-4 py-3 border-t border-border flex items-center justify-between text-sm font-sans">
            <span className="text-gray-500">Página {pagina + 1} de {totalPages} · {equipos.length} impresoras</span>
            <div className="flex gap-2">
              <button aria-label="Página anterior" onClick={() => setPage(Math.max(0, pagina - 1))} disabled={pagina === 0}
                className="p-1.5 rounded-lg border border-border hover:bg-gray-50 disabled:opacity-40"><ChevronLeft size={16} /></button>
              <button aria-label="Página siguiente" onClick={() => setPage(pagina + 1)} disabled={pagina >= totalPages - 1}
                className="p-1.5 rounded-lg border border-border hover:bg-gray-50 disabled:opacity-40"><ChevronRight size={16} /></button>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

