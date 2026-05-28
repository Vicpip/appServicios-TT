/**
 * EmptyState — shown when a list/table has no data.
 * Mirrors admin-web's empty patterns (centered icon + text in surface background).
 */
export default function EmptyState({ icon: Icon, title, description, action }) {
  return (
    <div className="flex flex-col items-center justify-center py-16 px-4 text-center">
      {Icon && (
        <div className="mb-4 flex h-16 w-16 items-center justify-center rounded-2xl bg-surface border border-border">
          <Icon className="h-8 w-8 text-gray-400" />
        </div>
      )}
      <h3 className="text-base font-semibold text-[#1A1A2E] font-heading">{title}</h3>
      {description && (
        <p className="mt-1 text-sm text-gray-400 font-sans max-w-sm">{description}</p>
      )}
      {action && <div className="mt-6">{action}</div>}
    </div>
  )
}
