export function SkeletonLine({ className = '' }) {
  return <div className={`animate-pulse rounded bg-gray-100 ${className}`} />
}

export function SkeletonCard() {
  return (
    <div className="bg-white rounded-xl border border-border shadow-sm p-5 space-y-3 animate-pulse">
      <div className="h-4 w-2/3 rounded bg-gray-100" />
      <div className="h-3 w-1/2 rounded bg-gray-100" />
      <div className="h-3 w-1/3 rounded bg-gray-100" />
    </div>
  )
}

export function SkeletonTable({ rows = 5, cols = 4 }) {
  return (
    <div className="divide-y divide-gray-50">
      {Array.from({ length: rows }).map((_, i) => (
        <div key={i} className="flex items-center gap-4 px-5 py-3.5 animate-pulse">
          {Array.from({ length: cols }).map((_, j) => (
            <div key={j} className="h-4 flex-1 rounded bg-gray-100" />
          ))}
        </div>
      ))}
    </div>
  )
}
