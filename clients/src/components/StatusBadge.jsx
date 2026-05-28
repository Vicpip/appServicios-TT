const STATUS_MAP = {
  completado: { label: 'Completado', classes: 'bg-green-50 text-green-700 border-green-200' },
  pendiente:  { label: 'Pendiente',  classes: 'bg-amber-50 text-amber-700 border-amber-200' },
  en_proceso: { label: 'En proceso', classes: 'bg-blue-50 text-blue-700 border-blue-200' },
  cancelado:  { label: 'Cancelado',  classes: 'bg-red-50 text-red-600 border-red-200' },
  activa:     { label: 'Activa',     classes: 'bg-green-50 text-green-700 border-green-200' },
  activo:     { label: 'Activo',     classes: 'bg-green-50 text-green-700 border-green-200' },
  inactivo:   { label: 'Inactivo',   classes: 'bg-gray-100 text-gray-500 border-gray-200' },
}

export default function StatusBadge({ status }) {
  const normalized = typeof status === 'string' ? status.trim().toLowerCase() : ''
  const cfg = STATUS_MAP[normalized] ?? {
    label: status ?? '—',
    classes: 'bg-gray-50 text-gray-600 border-gray-200',
  }
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded-full border text-xs font-medium font-sans ${cfg.classes}`}>
      {cfg.label}
    </span>
  )
}
