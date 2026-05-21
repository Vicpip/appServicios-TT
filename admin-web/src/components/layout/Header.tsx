import { useLocation, useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { LogOut, Menu, Wifi, WifiOff } from 'lucide-react'
import apiClient from '@/api/client'
import { API } from '@/api/endpoints'
import { useAuth } from '@/auth/AuthContext'

const SECTION_LABELS: Record<string, string> = {
  '/': 'Dashboard',
  '/reports': 'Reportes',
  '/clients': 'Clientes',
  '/technicians': 'Técnicos',
  '/printers': 'Impresoras',
  '/policies': 'Pólizas',
  '/sync': 'Sincronización',
}

const getSectionTitle = (pathname: string): string => {
  // Exact match first
  if (SECTION_LABELS[pathname]) return SECTION_LABELS[pathname]

  // Prefix match for nested routes
  const match = Object.keys(SECTION_LABELS)
    .filter((key) => key !== '/' && pathname.startsWith(key))
    .sort((a, b) => b.length - a.length)[0]

  return match ? (SECTION_LABELS[match] ?? 'Panel') : 'Panel'
}

interface HeaderProps {
  onMobileMenuToggle: () => void
}

const Header = ({ onMobileMenuToggle }: HeaderProps) => {
  const location = useLocation()
  const navigate = useNavigate()
  const { logout } = useAuth()
  const sectionTitle = getSectionTitle(location.pathname)

  const handleLogout = () => {
    logout()
    navigate('/login', { replace: true })
  }

  const { data: healthData, isError } = useQuery({
    queryKey: ['health'],
    queryFn: async () => {
      const res = await apiClient.get<{ status: string }>(API.health)
      return res.data
    },
    refetchInterval: 30000,
    retry: 1,
    // Don't throw to error boundary — we handle UI state manually
    throwOnError: false,
  })

  const isConnected = !isError && healthData != null

  return (
    <header
      className="sticky top-0 z-10 flex items-center justify-between bg-white border-b border-border px-4"
      style={{ height: '60px' }}
      aria-label="Barra de navegación superior"
    >
      {/* Left: hamburger (mobile) + logo + section title */}
      <div className="flex items-center gap-3">
        <button
          onClick={onMobileMenuToggle}
          className="md:hidden flex items-center justify-center w-9 h-9 rounded-lg text-gray-500 hover:text-gray-800 hover:bg-gray-100 transition-colors"
          aria-label="Abrir menú de navegación"
        >
          <Menu size={20} aria-hidden="true" />
        </button>

        <img
          src="/logo_smp.png"
          alt="SMP"
          className="h-10 w-auto object-contain shrink-0"
          draggable={false}
        />

        <span className="w-px h-5 bg-gray-200 shrink-0" aria-hidden="true" />

        <h1 className="text-[18px] font-bold text-[#1A1A2E] font-heading leading-none">
          {sectionTitle}
        </h1>
      </div>

      {/* Right: logout + API health status */}
      <div className="flex items-center gap-2">
        <button
          onClick={handleLogout}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium text-gray-600 hover:text-red-600 hover:bg-red-50 transition-colors"
          title="Cerrar sesión"
          aria-label="Cerrar sesión"
        >
          <LogOut size={15} aria-hidden="true" />
          <span className="hidden sm:inline">Cerrar sesión</span>
        </button>

        <div
          className={[
            'flex items-center gap-2 px-3 py-1.5 rounded-full border text-sm font-medium font-sans',
            'transition-colors duration-300',
            isConnected
              ? 'bg-green-50 border-green-200 text-green-700'
              : 'bg-red-50 border-red-200 text-red-600',
          ].join(' ')}
          role="status"
          aria-label={isConnected ? 'API conectada' : 'API desconectada'}
          title={isConnected ? 'Servidor respondiendo correctamente' : 'No se puede conectar al servidor'}
        >
          {isConnected ? (
            <>
              <span
                className="w-2 h-2 rounded-full bg-green-500 animate-pulse shrink-0"
                aria-hidden="true"
              />
              <Wifi size={13} className="shrink-0" aria-hidden="true" />
              <span className="hidden sm:inline">API Conectada</span>
              <span className="sm:hidden">Online</span>
            </>
          ) : (
            <>
              <span
                className="w-2 h-2 rounded-full bg-red-500 shrink-0"
                aria-hidden="true"
              />
              <WifiOff size={13} className="shrink-0" aria-hidden="true" />
              <span className="hidden sm:inline">API Desconectada</span>
              <span className="sm:hidden">Offline</span>
            </>
          )}
        </div>
      </div>
    </header>
  )
}

export default Header
