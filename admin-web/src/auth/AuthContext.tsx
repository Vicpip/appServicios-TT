import { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react'
import { getToken, setToken, clearToken } from './authToken'

const IDLE_TIMEOUT_MS = 60 * 60 * 1000
const ACTIVITY_EVENTS = ['mousemove', 'keydown', 'click', 'touchstart', 'scroll'] as const

interface AuthContextValue {
  isAuthenticated: boolean
  login: (token: string) => void
  logout: () => void
  sessionExpired: boolean
  clearSessionExpired: () => void
}

export const AuthContext = createContext<AuthContextValue | null>(null)

export const AuthProvider = ({ children }: { children: React.ReactNode }) => {
  const [isAuthenticated, setIsAuthenticated] = useState<boolean>(() => !!getToken())
  const [sessionExpired, setSessionExpired] = useState(false)
  const idleTimer = useRef<ReturnType<typeof setTimeout> | null>(null)

  const login = useCallback((token: string) => {
    setToken(token)
    setIsAuthenticated(true)
    setSessionExpired(false)
  }, [])

  const logout = useCallback(() => {
    clearToken()
    setIsAuthenticated(false)
  }, [])

  const resetIdleTimer = useCallback(() => {
    if (idleTimer.current) clearTimeout(idleTimer.current)
    idleTimer.current = setTimeout(() => {
      clearToken()
      setIsAuthenticated(false)
      setSessionExpired(true)
    }, IDLE_TIMEOUT_MS)
  }, [])

  // Handle 401 responses from the API client (fired via CustomEvent)
  useEffect(() => {
    const handler = () => {
      setIsAuthenticated(false)
    }
    window.addEventListener('auth:unauthorized', handler)
    return () => window.removeEventListener('auth:unauthorized', handler)
  }, [])

  // Idle session timeout
  useEffect(() => {
    if (!isAuthenticated) {
      if (idleTimer.current) clearTimeout(idleTimer.current)
      return
    }
    resetIdleTimer()
    const handler = () => resetIdleTimer()
    ACTIVITY_EVENTS.forEach((e) => window.addEventListener(e, handler, { passive: true }))
    return () => {
      if (idleTimer.current) clearTimeout(idleTimer.current)
      ACTIVITY_EVENTS.forEach((e) => window.removeEventListener(e, handler))
    }
  }, [isAuthenticated, resetIdleTimer])

  return (
    <AuthContext.Provider
      value={{
        isAuthenticated,
        login,
        logout,
        sessionExpired,
        clearSessionExpired: () => setSessionExpired(false),
      }}
    >
      {children}
    </AuthContext.Provider>
  )
}

export const useAuth = () => {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider')
  return ctx
}
