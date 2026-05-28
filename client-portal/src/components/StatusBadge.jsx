/**
 * StatusBadge — maps report/policy/printer status strings to colored pill badges.
 * Mirrors the badge pattern from admin-web DashboardPage.tsx:
 *   inline-flex items-center gap-1 px-2 py-0.5 rounded-full border text-xs font-medium font-sans
 */
const STATUS_MAP = {
  // Report statuses
  completado:  { label: 'Completado', classes: 'bg-green-50 text-green-700 border-green-200' },
  pendiente:   { label: 'Pendiente',  classes: 'bg-amber-50 text-amber-700 border-amber-200' },
  en_proceso:  { label: 'En Proceso', classes: 'bg-blue-50  text-blue-700  border-blue-200'  },
  cancelado:   { label: 'Cancelado',  classes: 'bg-red-50   text-red-600   border-red-200'   },
  // Policy statuses
  activa:      { label: 'Activa',     classes: 'bg-green-50 text-green-700 border-green-200' },
  active:      { label: 'Activa',     classes: 'bg-green-50 text-green-700 border-green-200' },
  vencida:     { label: 'Vencida',    classes: 'bg-red-50   text-red-600   border-red-200'   },
  // Printer statuses
  activo:      { label: 'Activo',     classes: 'bg-green-50 text-green-700 border-green-200' },
  inactivo:    { label: 'Inactivo',   classes: 'bg-gray-50  text-gray-600  border-gray-200'  },
  'en atención':{ label: 'En atención', classes: 'bg-red-50 text-red-600 border-red-200' },
}

export default function StatusBadge({ status }) {
  const key = (status ?? '').toLowerCase()
  const { label, classes } = STATUS_MAP[key] ?? {
    label:   status ?? '—',
    classes: 'bg-gray-50 text-gray-600 border-gray-200',
  }
  return (
    <span
      className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full border text-xs font-medium font-sans ${classes}`}
    >
      {label}
    </span>
  )
}
