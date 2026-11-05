import type { ReactNode } from 'react'
import { Navigate } from 'react-router-dom'
import { useRiskModule } from '@/hooks/useRiskModule'

/** Protege la ruta: si el módulo está desactivado o sin modelo, vuelve al inicio. */
export default function RiskModuleGuard({ children }: { children: ReactNode }) {
  const { isLoading, available } = useRiskModule()
  if (isLoading) {
    return (
      <div className="p-8 flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" />
      </div>
    )
  }
  return available ? <>{children}</> : <Navigate to="/" replace />
}
