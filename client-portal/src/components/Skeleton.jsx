/**
 * Skeleton — loading placeholder shapes.
 * Uses admin-web's animate-pulse pattern: h-X w-X rounded-md bg-gray-100 animate-pulse
 *
 * Usage: <Skeleton className="h-4 w-32" />
 *        <Skeleton.Card />
 *        <Skeleton.Table rows={5} cols={4} />
 */
function Skeleton({ className = '' }) {
  return <div className={`animate-pulse bg-gray-100 rounded-md ${className}`} />
}

Skeleton.Card = function SkeletonCard() {
  return (
    <div className="card space-y-4">
      <Skeleton className="h-4 w-1/3" />
      <Skeleton className="h-8 w-1/2" />
      <Skeleton className="h-3 w-2/3" />
    </div>
  )
}

Skeleton.Table = function SkeletonTable({ rows = 5, cols = 4 }) {
  return (
    <div className="overflow-hidden rounded-xl border border-border bg-white">
      {/* Header */}
      <div
        className="grid gap-4 border-b bg-gray-50 px-5 py-2.5 animate-pulse"
        style={{ gridTemplateColumns: `repeat(${cols}, 1fr)` }}
      >
        {Array.from({ length: cols }).map((_, i) => (
          <div key={i} className="h-3 rounded bg-gray-200 w-20" />
        ))}
      </div>
      {/* Rows */}
      {Array.from({ length: rows }).map((_, r) => (
        <div
          key={r}
          className="grid gap-4 border-b border-gray-50 px-5 py-3.5 last:border-0 animate-pulse"
          style={{ gridTemplateColumns: `repeat(${cols}, 1fr)` }}
        >
          {Array.from({ length: cols }).map((_, c) => (
            <div key={c} className="h-4 rounded bg-gray-100 w-full" />
          ))}
        </div>
      ))}
    </div>
  )
}

export default Skeleton
