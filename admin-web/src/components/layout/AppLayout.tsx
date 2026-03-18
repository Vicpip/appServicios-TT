import { useState, useEffect } from 'react'
import { Outlet, useLocation } from 'react-router-dom'
import Sidebar from './Sidebar'
import Header from './Header'

const SIDEBAR_COLLAPSED_KEY = 'smp_sidebar_collapsed'

const AppLayout = () => {
  const [collapsed, setCollapsed] = useState<boolean>(() => {
    try {
      return localStorage.getItem(SIDEBAR_COLLAPSED_KEY) === 'true'
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
    const handler = (e: MediaQueryListEvent) => {
      if (e.matches) setMobileOpen(false)
    }
    mq.addEventListener('change', handler)
    return () => mq.removeEventListener('change', handler)
  }, [])

  const handleToggleCollapse = () => {
    setCollapsed((prev) => {
      const next = !prev
      try {
        localStorage.setItem(SIDEBAR_COLLAPSED_KEY, String(next))
      } catch {}
      return next
    })
  }

  return (
    // overflow-x-hidden on root eliminates any horizontal scroll
    <div className="min-h-screen bg-surface overflow-x-hidden">
      <Sidebar
        collapsed={collapsed}
        onToggleCollapse={handleToggleCollapse}
        mobileOpen={mobileOpen}
        onMobileClose={() => setMobileOpen(false)}
      />

      {/*
        Content wrapper:
        - Mobile: pl-0 (sidebar is a fixed overlay, never in flow)
        - Desktop expanded:  md:pl-60  (240px)
        - Desktop collapsed: md:pl-16  (64px)
        transition-[padding-left] animates the shift when toggling
      */}
      <div
        className={[
          'flex flex-col min-h-screen',
          'transition-[padding-left] duration-300 ease-in-out',
          collapsed ? 'md:pl-16' : 'md:pl-60',
        ].join(' ')}
      >
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

export default AppLayout
