import { NavLink, useLocation } from 'react-router-dom'
import {
  LayoutDashboard,
  FileText,
  Building2,
  Users,
  Printer,
  ShieldCheck,
  RefreshCw,
  ChevronLeft,
  ChevronRight,
} from 'lucide-react'

interface NavItem {
  path: string
  icon: React.ElementType
  label: string
}

const NAV_ITEMS: NavItem[] = [
  { path: '/', icon: LayoutDashboard, label: 'Dashboard' },
  { path: '/reports', icon: FileText, label: 'Reportes' },
  { path: '/clients', icon: Building2, label: 'Clientes' },
  { path: '/technicians', icon: Users, label: 'Técnicos' },
  { path: '/printers', icon: Printer, label: 'Impresoras' },
  { path: '/policies', icon: ShieldCheck, label: 'Pólizas' },
  { path: '/sync', icon: RefreshCw, label: 'Sincronización' },
]

interface SidebarProps {
  collapsed: boolean
  onToggleCollapse: () => void
  mobileOpen: boolean
  onMobileClose: () => void
}

export default function Sidebar({
  collapsed,
  onToggleCollapse,
  mobileOpen,
  onMobileClose,
}: SidebarProps) {
  const location = useLocation()

  const isActive = (path: string) =>
    path === '/' ? location.pathname === '/' : location.pathname.startsWith(path)

  return (
    <>
      {/* ── Mobile backdrop ── */}
      {mobileOpen && (
        <div
          className="fixed inset-0 bg-black/60 z-20 md:hidden"
          onClick={onMobileClose}
          aria-hidden="true"
        />
      )}

      {/*
        ── Sidebar panel ──
        Width logic:
          • Mobile  → w-64, slides in/out with translateX
          • Desktop expanded  → md:w-60 (240px)
          • Desktop collapsed → md:w-16  (64px)

        overflow-hidden clips everything at the sidebar border.
        Tooltips use the native `title` attribute instead of absolute children
        so they never break out and cause horizontal scroll.
      */}
      <aside
        className={[
          'fixed top-0 left-0 h-full z-30 flex flex-col',
          'bg-navy overflow-hidden',
          'transition-[width,transform] duration-300 ease-in-out',
          // Mobile width (always 256px; position controlled by translate)
          'w-64',
          // Desktop width overrides
          collapsed ? 'md:w-16' : 'md:w-60',
          // Slide in/out: mobile uses translate, desktop always visible
          mobileOpen ? 'translate-x-0' : '-translate-x-full md:translate-x-0',
        ].join(' ')}
        aria-label="Navegación principal"
      >
        {/* ── Nav items ── */}
        <nav
          className="flex-1 overflow-y-auto overflow-x-hidden py-3"
          aria-label="Menu principal"
        >
          <ul className="space-y-0.5 px-2">
            {NAV_ITEMS.map(({ path, icon: Icon, label }) => {
              const active = isActive(path)
              return (
                <li key={path}>
                  <NavLink
                    to={path}
                    end={path === '/'}
                    onClick={onMobileClose}
                    // native title provides tooltip when collapsed (no custom element needed)
                    title={label}
                    className={[
                      'flex items-center rounded-lg',
                      'text-sm font-medium transition-all duration-150 no-underline',
                      // Collapsed desktop → center icon; expanded → row with gap
                      collapsed ? 'md:justify-center md:py-2.5 gap-3 px-3 py-2.5' : 'gap-3 px-3 py-2.5',
                      active
                        ? 'bg-primary text-white'
                        : 'text-[#E8EDF8] hover:bg-white/[0.08]',
                    ].join(' ')}
                    style={{
                      borderLeft: `3px solid ${active ? '#3B6FE8' : 'transparent'}`,
                    }}
                  >
                    <Icon
                      size={18}
                      className={[
                        'shrink-0',
                        active ? 'text-white' : 'text-[#A8BBDE]',
                      ].join(' ')}
                      aria-hidden="true"
                    />

                    {/* Label hidden on desktop when collapsed; always shown on mobile */}
                    <span className={['truncate leading-none', collapsed ? 'md:hidden' : ''].join(' ')}>
                      {label}
                    </span>
                  </NavLink>
                </li>
              )
            })}
          </ul>
        </nav>

        {/* ── Collapse toggle (desktop only) ── */}
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
