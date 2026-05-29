import { useState, useEffect } from 'react'
import { Outlet, NavLink, useLocation, useNavigate } from 'react-router-dom'
import {
  LayoutDashboard,
  Printer,
  FileText,
  ShieldCheck,
  ChevronLeft,
  ChevronRight,
  LogOut,
  Menu,
  User,
} from 'lucide-react'
import { useAuth } from '@/hooks/useAuth'

const NAV_ITEMS = [
  { path: '/dashboard', icon: LayoutDashboard, label: 'Dashboard' },
  { path: '/impresoras', icon: Printer, label: 'Mis Impresoras' },
  { path: '/reportes', icon: FileText, label: 'Reportes' },
  { path: '/polizas', icon: ShieldCheck, label: 'Mis Pólizas' },
]

const SECTION_LABELS = {
  '/dashboard': 'Dashboard',
  '/impresoras': 'Mis Impresoras',
  '/reportes': 'Reportes',
  '/polizas': 'Mis Pólizas',
}

function getSectionTitle(pathname) {
  if (SECTION_LABELS[pathname]) return SECTION_LABELS[pathname]
  const match = Object.keys(SECTION_LABELS)
    .filter((key) => pathname.startsWith(key))
    .sort((a, b) => b.length - a.length)[0]
  return match ? SECTION_LABELS[match] : 'Portal'
}

const SIDEBAR_KEY = 'portal_sidebar_collapsed'

const _API_BASE = import.meta.env.VITE_API_URL ?? ''

function Sidebar({ collapsed, onToggleCollapse, mobileOpen, onMobileClose }) {
  const location = useLocation()
  const navigate = useNavigate()
  const { user, logout } = useAuth()

  const isActive = (path) => location.pathname === path || location.pathname.startsWith(path + '/')

  const handleLogout = () => {
    logout()
    navigate('/login', { replace: true })
  }

  return (
    <>
      {mobileOpen && (
        <div
          className="fixed inset-0 bg-black/60 z-20 md:hidden"
          onClick={onMobileClose}
          aria-hidden="true"
        />
      )}

      <aside
        className={[
          'fixed top-0 left-0 h-full z-30 flex flex-col',
          'bg-navy overflow-hidden',
          'transition-[width,transform] duration-300 ease-in-out',
          'w-64',
          collapsed ? 'md:w-16' : 'md:w-60',
          mobileOpen ? 'translate-x-0' : '-translate-x-full md:translate-x-0',
        ].join(' ')}
        aria-label="Navegación principal"
      >
        {/* Logo area */}
        <div className={[
          'shrink-0 flex flex-col border-b border-white/10',
          collapsed ? 'md:items-center px-3 py-4' : 'px-4 py-4',
        ].join(' ')}>
          <div className={['flex items-center', collapsed ? 'md:justify-center' : 'gap-3'].join(' ')}>
            <img
              src="/logo_smp.png"
              alt="SMP"
              className="h-8 w-auto object-contain shrink-0"
              draggable={false}
            />
            <span className={['text-white font-bold font-heading text-sm truncate', collapsed ? 'md:hidden' : ''].join(' ')}>
              Portal Cliente
            </span>
          </div>
        </div>

        {/* Nav items */}
        <nav className="flex-1 overflow-y-auto overflow-x-hidden py-3 scrollbar-thin" aria-label="Menú principal">
          <ul className="space-y-0.5 px-2">
            {NAV_ITEMS.map(({ path, icon: Icon, label }) => {
              const active = isActive(path)
              return (
                <li key={path}>
                  <NavLink
                    to={path}
                    onClick={onMobileClose}
                    title={label}
                    className={[
                      'flex items-center rounded-lg',
                      'text-sm font-medium transition-all duration-150 no-underline',
                      collapsed ? 'md:justify-center md:py-2.5 gap-3 px-3 py-2.5' : 'gap-3 px-3 py-2.5',
                      active ? 'bg-primary text-white' : 'text-[#E8EDF8] hover:bg-white/[0.08]',
                    ].join(' ')}
                    style={{ borderLeft: `3px solid ${active ? '#3B6FE8' : 'transparent'}` }}
                  >
                    <Icon
                      size={18}
                      className={['shrink-0', active ? 'text-white' : 'text-[#A8BBDE]'].join(' ')}
                      aria-hidden="true"
                    />
                    <span className={['truncate leading-none', collapsed ? 'md:hidden' : ''].join(' ')}>
                      {label}
                    </span>
                  </NavLink>
                </li>
              )
            })}
          </ul>
        </nav>

        {/* User info + logout */}
        <div className={[
          'shrink-0 border-t border-white/10 p-3',
          collapsed ? 'md:flex md:justify-center' : '',
        ].join(' ')}>
          {!collapsed && (
            <div className="flex items-center gap-2 px-2 py-1.5 mb-1">
              <div className="shrink-0 w-7 h-7 rounded-full bg-primary/30 flex items-center justify-center">
                <User size={13} className="text-[#A8BBDE]" />
              </div>
              <div className="min-w-0">
                {user?.name
                  ? <p className="text-xs font-medium text-[#E8EDF8] truncate">{user.name}</p>
                  : <div className="w-24 h-4 bg-white/20 rounded animate-pulse" />
                }
                {user?.client_name
                  ? <p className="text-[10px] text-[#A8BBDE] truncate mt-0.5">{user.client_name}</p>
                  : <div className="w-16 h-3 bg-white/20 rounded animate-pulse mt-1" />
                }
              </div>
            </div>
          )}
          <button
            onClick={handleLogout}
            title="Cerrar sesión"
            className={[
              'flex items-center w-full rounded-lg px-3 py-2',
              'text-[#A8BBDE] hover:text-[#E8EDF8] hover:bg-white/[0.08]',
              'transition-colors duration-150 text-xs font-medium',
              collapsed ? 'md:justify-center' : 'gap-2',
            ].join(' ')}
            aria-label="Cerrar sesión"
          >
            <LogOut size={15} aria-hidden="true" />
            <span className={collapsed ? 'md:hidden' : ''}>Cerrar sesión</span>
          </button>
        </div>

        {/* Collapse toggle (desktop only) */}
        <div className="hidden md:flex shrink-0 border-t border-white/10 p-2">
          <button
            onClick={onToggleCollapse}
            className={[
              'flex items-center w-full rounded-lg px-3 py-2',
              'text-[#A8BBDE] hover:text-[#E8EDF8] hover:bg-white/[0.08]',
              'transition-colors duration-150 text-xs font-medium',
              collapsed ? 'justify-center' : 'gap-2',
            ].join(' ')}
            aria-label={collapsed ? 'Expandir sidebar' : 'Colapsar sidebar'}
          >
            {collapsed ? (
              <ChevronRight size={16} aria-hidden="true" />
            ) : (
              <>
                <ChevronLeft size={16} aria-hidden="true" />
                <span>Colapsar</span>
              </>
            )}
          </button>
        </div>
      </aside>
    </>
  )
}

function Header({ onMobileMenuToggle }) {
  const location = useLocation()
  const navigate = useNavigate()
  const { user, logout } = useAuth()
  const sectionTitle = getSectionTitle(location.pathname)

  const handleLogout = () => {
    logout()
    navigate('/login', { replace: true })
  }

  return (
    <header
      className="sticky top-0 z-10 flex items-center justify-between bg-white border-b border-border px-4"
      style={{ height: '60px' }}
      aria-label="Barra de navegación superior"
    >
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

        {user?.client_id && (
          <>
            <span className="w-px h-7 bg-gray-200 shrink-0" aria-hidden="true" />
            <img
              src={`${import.meta.env.VITE_API_URL}/api/portal/client-logo?client_id=${user.client_id}`}
              alt="Logo del cliente"
              className="max-h-9 w-auto object-contain shrink-0"
              onError={(e) => { e.currentTarget.style.display = 'none' }}
            />
          </>
        )}

        <span className="w-px h-5 bg-gray-200 shrink-0" aria-hidden="true" />

        <h1 className="text-[18px] font-bold text-[#1A1A2E] font-heading leading-none">
          {sectionTitle}
        </h1>
      </div>

      <button
        onClick={handleLogout}
        className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium text-gray-600 hover:text-red-600 hover:bg-red-50 transition-colors"
        title="Cerrar sesión"
        aria-label="Cerrar sesión"
      >
        <LogOut size={15} aria-hidden="true" />
        <span className="hidden sm:inline">Cerrar sesión</span>
      </button>
    </header>
  )
}

export default function Layout() {
  const [collapsed, setCollapsed] = useState(() => {
    try {
      return localStorage.getItem(SIDEBAR_KEY) === 'true'
    } catch {
      return false
    }
  })
  const [mobileOpen, setMobileOpen] = useState(false)
  const location = useLocation()

  useEffect(() => {
    setMobileOpen(false)
  }, [location.pathname])

  useEffect(() => {
    const mq = window.matchMedia('(min-width: 768px)')
    const handler = (e) => { if (e.matches) setMobileOpen(false) }
    mq.addEventListener('change', handler)
    return () => mq.removeEventListener('change', handler)
  }, [])

  const handleToggleCollapse = () => {
    setCollapsed((prev) => {
      const next = !prev
      try { localStorage.setItem(SIDEBAR_KEY, String(next)) } catch {}
      return next
    })
  }

  return (
    <div className="min-h-screen bg-surface overflow-x-hidden">
      <Sidebar
        collapsed={collapsed}
        onToggleCollapse={handleToggleCollapse}
        mobileOpen={mobileOpen}
        onMobileClose={() => setMobileOpen(false)}
      />
      <div className={[
        'flex flex-col min-h-screen',
        'transition-[padding-left] duration-300 ease-in-out',
        collapsed ? 'md:pl-16' : 'md:pl-60',
      ].join(' ')}>
        <Header onMobileMenuToggle={() => setMobileOpen((prev) => !prev)} />
        <main
          className="flex-1 overflow-y-auto overflow-x-hidden bg-surface p-6"
          id="main-content"
          role="main"
        >
          <Outlet />
        </main>
      </div>
    </div>
  )
}
