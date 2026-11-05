import { AlertOctagon, AlertTriangle, CheckCircle2 } from 'lucide-react'
import type { Nivel } from '@/types/risk'

const NIVEL_STYLE: Record<Nivel, { cls: string; Icon: typeof AlertTriangle }> = {
  ALTO: { cls: 'bg-red-50 text-red-800 border-red-300', Icon: AlertOctagon },
  MEDIO: { cls: 'bg-amber-50 text-amber-900 border-amber-300', Icon: AlertTriangle },
  BAJO: { cls: 'bg-green-50 text-green-800 border-green-300', Icon: CheckCircle2 },
}

/** Nivel con texto + icono (no depende solo del color). */
export default function RiskLevelBadge({ nivel }: { nivel: Nivel }) {
  const { cls, Icon } = NIVEL_STYLE[nivel]
  return (
    <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full border text-xs font-bold font-sans ${cls}`}>
      <Icon size={12} aria-hidden="true" />
      {nivel}
    </span>
  )
}

export function MonitoreoTag() {
  return (
    <span
      className="inline-flex items-center px-1.5 py-0.5 rounded border border-gray-300 bg-gray-50 text-[10px] font-semibold text-gray-600 font-sans"
      title="Evidencia débil: se muestra solo como seguimiento"
    >
      En monitoreo
    </span>
  )
}
