import { useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { Activity, Loader2, X } from 'lucide-react'
import apiClient from '@/api/client'
import { API } from '@/api/endpoints'
import { useRiskModule } from '@/hooks/useRiskModule'
import { refreshErrorMessage } from '@/lib/risk'
import type { RefreshRespuesta } from '@/types/risk'

interface Aviso { tipo: 'ok' | 'error'; texto: string }

function plural(n: number, uno: string, varios: string): string {
  return `${n} ${n === 1 ? uno : varios}`
}

function resumen(res: RefreshRespuesta): string {
  const n = res.equipos.length
  const partes = [`Riesgo actualizado en ${plural(n, 'impresora', 'impresoras')}.`]
  if (res.sin_datos > 0) partes.push(`${plural(res.sin_datos, 'impresora', 'impresoras')} sin visitas, no se calcularon.`)
  if (res.excluidas_no_zebra > 0) partes.push(`${plural(res.excluidas_no_zebra, 'impresora', 'impresoras')} que no son Zebra, excluidas.`)
  return partes.join(' ')
}

/** Botón + aviso para recalcular el riesgo de las impresoras de una póliza. */
export default function PolicyRiskRefreshButton({ policyId }: { policyId: string }) {
  const qc = useQueryClient()
  const { available } = useRiskModule()
  const [aviso, setAviso] = useState<Aviso | null>(null)

  const refresh = useMutation({
    mutationFn: async () =>
      (await apiClient.post<RefreshRespuesta>(API.risk.refreshPolicy(policyId), undefined, {
        timeout: 120_000,   // una póliza grande tarda más que el timeout por defecto (15 s)
      })).data,
    onMutate: () => setAviso(null),
    onSuccess: (res) => {
      qc.invalidateQueries({ queryKey: ['risk-list'] })
      qc.invalidateQueries({ queryKey: ['risk-printer'] })
      setAviso({ tipo: 'ok', texto: resumen(res) })
    },
    onError: (err: unknown) => setAviso({ tipo: 'error', texto: refreshErrorMessage(err, 'poliza') }),
  })

  if (!available) return null

  return (
    <>
      <button
        onClick={() => refresh.mutate()}
        disabled={refresh.isPending}
        className="flex items-center gap-2 px-3 py-2 text-sm font-semibold text-gray-600 font-sans border border-border rounded-lg hover:text-primary hover:border-primary hover:bg-primary/5 disabled:opacity-50 transition-colors shrink-0"
      >
        {refresh.isPending
          ? <Loader2 size={14} className="animate-spin" aria-hidden="true" />
          : <Activity size={14} aria-hidden="true" />}
        {refresh.isPending ? 'Actualizando riesgo…' : 'Actualizar riesgo'}
      </button>
      {aviso && (
        <div
          role={aviso.tipo === 'error' ? 'alert' : 'status'}
          className={`basis-full flex items-center gap-2 px-4 py-2.5 rounded-lg border text-sm font-sans ${
            aviso.tipo === 'ok'
              ? 'bg-green-50 border-green-200 text-green-800'
              : 'bg-red-50 border-red-200 text-red-700'
          }`}
        >
          <span className="flex-1">{aviso.texto}</span>
          <button onClick={() => setAviso(null)} aria-label="Cerrar aviso" className="opacity-60 hover:opacity-100">
            <X size={14} />
          </button>
        </div>
      )}
    </>
  )
}
