import { useState, useEffect } from 'react'
import { Outlet, NavLink, useLocation } from 'react-router-dom'
import { useAuth, logout } from '../hooks/useAuth'

// ── Lucide-style inline SVG icons ─────────────────────────────────────────────
const Icons = {
  dashboard: (
    <svg className="h-[18px] w-[18px] shrink-0" fill="none" stroke="currentColor" strokeWidth={1.8} viewBox="0 0 24 24" aria-hidden="true">
      <rect x="3" y="3" width="7" height="7" rx="1.5" /><rect x="14" y="3" width="7" height="7" rx="1.5" />
      <rect x="3" y="14" width="7" height="7" rx="1.5" /><rect x="14" y="14" width="7" height="7" rx="1.5" />
    </svg>
  ),
  printers: (
    <svg className="h-[18px] w-[18px] shrink-0" fill="none" stroke="currentColor" strokeWidth={1.8} viewBox="0 0 24 24" aria-hidden="true">
      <path d="M6 9V4a1 1 0 011-1h10a1 1 0 011 1v5M6 18H4a1 1 0 01-1-1v-6a1 1 0 011-1h16a1 1 0 011 1v6a1 1 0 01-1 1h-2" />
      <rect x="6" y="14" width="12" height="7" rx="1" />
      <circle cx="17.5" cy="11.5" r=".75" fill="currentColor" />
    </svg>
  ),
  reports: (
    <svg className="h-[18px] w-[18px] shrink-0" fill="none" stroke="currentColor" strokeWidth={1.8} viewBox="0 0 24 24" aria-hidden="true">
      <path d="M9 12h6M9 16h6M9 8h3M5 4h14a1 1 0 011 1v14a1 1 0 01-1 1H5a1 1 0 01-1-1V5a1 1 0 011-1z" />
    </svg>
  ),
  policies: (
    <svg className="h-[18px] w-[18px] shrink-0" fill="none" stroke="currentColor" strokeWidth={1.8} viewBox="0 0 24 24" aria-hidden="true">
      <path d="M12 2L4 6v6c0 5.25 3.5 10.15 8 11.25C16.5 22.15 20 17.25 20 12V6l-8-4z" />
      <path d="M9 12l2 2 4-4" />
    </svg>
  ),
  logout: (
    <svg className="h-[15px] w-[15px] shrink-0" fill="none" stroke="currentColor" strokeWidth={1.8} viewBox="0 0 24 24" aria-hidden="true">
      <path d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a2 2 0 01-2 2H5a2 2 0 01-2-2V7a2 2 0 012-2h6a2 2 0 012 2v1" />
    </svg>
  ),
  menu: (
    <svg className="h-5 w-5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24" aria-hidden="true">
      <path d="M4 6h16M4 12h16M4 18h16" />
    </svg>
  ),
  chevronLeft: (
    <svg className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24" aria-hidden="true">
      <path d="M15 18l-6-6 6-6" />
    </svg>
  ),
  chevronRight: (
    <svg className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24" aria-hidden="true">
      <path d="M9 18l6-6-6-6" />
    </svg>
  ),
}

// ── Nav items ─────────────────────────────────────────────────────────────────
const NAV_LINKS = [
  { to: '/dashboard',  label: 'Dashboard',  icon: Icons.dashboard },
  { to: '/impresoras', label: 'Impresoras', icon: Icons.printers  },
  { to: '/reportes',   label: 'Reportes',   icon: Icons.reports   },
  { to: '/polizas',    label: 'Pólizas',    icon: Icons.policies  },
]

// ── Page title map ────────────────────────────────────────────────────────────
const PAGE_TITLES = {
  '/dashboard':  'Dashboard',
  '/impresoras': 'Impresoras',
  '/reportes':   'Reportes',
  '/polizas':    'Pólizas',
}

const SIDEBAR_KEY = 'smp_portal_sidebar_collapsed'

// ── Sidebar panel (shared) ────────────────────────────────────────────────────
function SidebarPanel({ collapsed, onToggle, onMobileClose }) {
  const { user } = useAuth()

  return (
    <aside
      className={[
        'flex flex-col h-full',
        'bg-navy overflow-hidden',
        'transition-[width] duration-300 ease-in-out',
      ].join(' ')}
      aria-label="Navegación principal"
    >
      {/* Logo area */}
      <div className={['flex items-center shrink-0 border-b border-white/10', collapsed ? 'px-2 py-4 justify-center' : 'px-5 py-4 gap-3'].join(' ')}>
        <div className="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-xl bg-primary text-white font-bold text-sm shadow">
          SM
        </div>
        {!collapsed && (
          <div className="min-w-0">
            <p className="text-sm font-semibold text-white truncate font-heading">Servicios Main PC</p>
            <p className="text-xs text-[#A8BBDE] truncate font-sans">Portal de Clientes</p>
          </div>
        )}
        {!collapsed && onMobileClose && (
          <button
            onClick={onMobileClose}
            className="ml-auto text-[#A8BBDE] hover:text-white transition-colors"
            aria-label="Cerrar menú"
          >
            <svg className="h-5 w-5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
              <path d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        )}
      </div>

      {/* Nav */}
      <nav className="flex-1 overflow-y-auto overflow-x-hidden py-3 scrollbar-thin" aria-label="Menú principal">
        <ul className="space-y-0.5 px-2">
          {NAV_LINKS.map(({ to, label, icon }) => (
            <li key={to}>
              <NavLink
                to={to}
                onClick={onMobileClose}
                title={label}
                className={({ isActive }) => [
                  'flex items-center rounded-lg',
                  'text-sm font-medium transition-all duration-150 no-underline',
                  collapsed ? 'justify-center py-2.5 gap-3 px-3' : 'gap-3 px-3 py-2.5',
                  isActive
                    ? 'bg-primary text-white'
                    : 'text-[#E8EDF8] hover:bg-white/[0.08]',
                ].join(' ')}
                style={({ isActive }) => ({
                  borderLeft: `3px solid ${isActive ? '#3B6FE8' : 'transparent'}`,
                })}
              >
                {({ isActive }) => (
                  <>
                    <span className={isActive ? 'text-white shrink-0' : 'text-[#A8BBDE] shrink-0'}>
                      {icon}
                    </span>
                    <span className={['truncate leading-none', collapsed ? 'hidden' : ''].join(' ')}>
                      {label}
                    </span>
                  </>
                )}
              </NavLink>
            </li>
          ))}
        </ul>
      </nav>

      {/* User info + logout */}
      {!collapsed && (
        <div className="shrink-0 border-t border-white/10 px-4 py-4">
          <div className="mb-3">
            <p className="text-sm font-medium text-white truncate font-sans">{user?.name || 'Usuario'}</p>
            <p className="text-xs text-[#A8BBDE] truncate font-sans">{user?.clientName || 'Cliente'}</p>
            {user?.plantName && (
              <p className="text-xs text-[#6B85BE] truncate font-sans">{user.plantName}</p>
            )}
          </div>
          <button
            onClick={logout}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium text-[#E8EDF8] hover:text-red-300 hover:bg-red-500/10 transition-colors w-full text-left"
            aria-label="Cerrar sesión"
          >
            {Icons.logout}
            <span>Cerrar sesión</span>
          </button>
        </div>
      )}

      {/* Collapse toggle (desktop) */}
      <div className="hidden md:flex shrink-0 border-t border-white/10 p-2">
        <button
          onClick={onToggle}
          className={[
            'flex items-center w-full rounded-lg px-3 py-2',
            'text-[#A8BBDE] hover:text-[#E8EDF8] hover:bg-white/[0.08]',
            'transition-colors duration-150 text-xs font-medium',
            collapsed ? 'justify-center' : 'gap-2',
          ].join(' ')}
          aria-label={collapsed ? 'Expandir sidebar' : 'Colapsar sidebar'}
        >
          {collapsed ? Icons.chevronRight : (
            <>
              {Icons.chevronLeft}
              <span>Colapsar</span>
            </>
          )}
        </button>
      </div>
    </aside>
  )
}

// ── Layout ────────────────────────────────────────────────────────────────────
export default function Layout() {
  const [collapsed, setCollapsed] = useState(() => {
    try { return localStorage.getItem(SIDEBAR_KEY) === 'true' } catch { return false }
  })
  const [mobileOpen, setMobileOpen] = useState(false)
  const location = useLocation()

  // Close mobile drawer on route change
  useEffect(() => { setMobileOpen(false) }, [location.pathname])

  // Close mobile drawer when resizing to desktop
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

  const pageTitle = Object.entries(PAGE_TITLES).find(([path]) =>
    location.pathname.startsWith(path)
  )?.[1] ?? 'Portal'

  return (
    <div className="min-h-screen bg-surface overflow-x-hidden">
      {/* ── Mobile backdrop ── */}
      {mobileOpen && (
        <div
          className="fixed inset-0 bg-black/60 z-20 md:hidden"
          onClick={() => setMobileOpen(false)}
          aria-hidden="true"
        />
      )}

      {/* ── Sidebar ── */}
      <div
        className={[
          'fixed top-0 left-0 h-full z-30',
          'transition-[width,transform] duration-300 ease-in-out',
          // Mobile width always 256px, slides in/out
          'w-64',
          // Desktop width controlled by collapsed state
          collapsed ? 'md:w-16' : 'md:w-60',
          mobileOpen ? 'translate-x-0' : '-translate-x-full md:translate-x-0',
        ].join(' ')}
      >
        <SidebarPanel
          collapsed={collapsed}
          onToggle={handleToggleCollapse}
          onMobileClose={mobileOpen ? () => setMobileOpen(false) : null}
        />
      </div>

      {/* ── Content wrapper ── */}
      <div
        className={[
          'flex flex-col min-h-screen',
          'transition-[padding-left] duration-300 ease-in-out',
          collapsed ? 'md:pl-16' : 'md:pl-60',
        ].join(' ')}
      >
        {/* ── Top bar — mirrors admin-web Header.tsx ── */}
        <header
          className="sticky top-0 z-10 flex items-center justify-between bg-white border-b border-border px-4"
          style={{ height: '60px' }}
          aria-label="Barra de navegación superior"
        >
          {/* Left: hamburger + page title */}
          <div className="flex items-center gap-3">
            <button
              onClick={() => setMobileOpen((p) => !p)}
              className="md:hidden flex items-center justify-center w-9 h-9 rounded-lg text-gray-500 hover:text-gray-800 hover:bg-gray-100 transition-colors"
              aria-label="Abrir menú de navegación"
            >
              {Icons.menu}
            </button>

            <img
              src="/logo_smp.png"
              alt="SMP"
              className="h-10 w-auto object-contain shrink-0"
              draggable={false}
              onError={(e) => { e.target.style.display = 'none' }}
            />

            <span className="w-px h-5 bg-gray-200 shrink-0" aria-hidden="true" />

            <h1 className="text-[18px] font-bold text-[#1A1A2E] font-heading leading-none">
              {pageTitle}
            </h1>
          </div>

          {/* Right: logout */}
          <button
            onClick={logout}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium text-gray-600 hover:text-red-600 hover:bg-red-50 transition-colors"
            title="Cerrar sesión"
            aria-label="Cerrar sesión"
          >
            {Icons.logout}
            <span className="hidden sm:inline">Cerrar sesión</span>
          </button>
        </header>

        {/* ── Page content ── */}
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
