import { Inbox } from 'lucide-react'

export default function EmptyState({ message = 'Sin resultados', icon: Icon = Inbox }) {
  return (
    <div className="flex flex-col items-center gap-3 py-14 px-5 text-center">
      <Icon size={32} className="text-gray-300" />
      <p className="text-sm text-gray-400 font-sans">{message}</p>
    </div>
  )
}
