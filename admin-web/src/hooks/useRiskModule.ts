import { useQuery } from '@tanstack/react-query'
import apiClient from '@/api/client'
import { API } from '@/api/endpoints'
import { isModuleOffError } from '@/lib/risk'
import type { ModeloInfo } from '@/types/risk'

/**
 * Disponibilidad del módulo de riesgo. Se oculta (menú, ruta, bloques) solo cuando model/info
 * responde 503/404 (módulo desactivado o sin modelo). Un fallo de red no lo oculta.
 */
export function useRiskModule() {
  const q = useQuery<ModeloInfo>({
    queryKey: ['risk-model-info'],
    queryFn: async () => (await apiClient.get<ModeloInfo>(API.risk.modelInfo)).data,
    staleTime: 5 * 60_000,
    retry: false,
  })
  const off = q.isError && isModuleOffError(q.error)
  return {
    isLoading: q.isLoading,
    available: q.isSuccess || (q.isError && !off),
    info: q.data ?? null,
  }
}
