import { createContext, useCallback, useContext, useState } from 'react'
import { jwtDecode } from 'jwt-decode'
import { getToken, setToken, clearToken } from '@/api/axios'

function validateAndDecodeToken(token) {
  if (!token) return null
  const parts = token.split('.')
  if (parts.length !== 3) {
    clearToken()
    return null
  }
  try {
    const decoded = jwtDecode(token)
    if (!decoded.exp || decoded.exp * 1000 <= Date.now()) {
      clearToken()
      return null
    }
    if (decoded.role !== 'portal_client') {
      clearToken()
      return null
    }
    return {
      id: decoded.sub,
      email: decoded.email,
      name: decoded.name,
      client_id: decoded.client_id,
      client_name: decoded.client_name,
      plant_id: decoded.plant_id ?? null,
      plant_name: decoded.plant_name ?? null,
    }
  } catch {
    clearToken()
    return null
  }
}

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [user, setUser] = useState(() => {
    const token = getToken()
    return validateAndDecodeToken(token)
  })

  const login = useCallback((token, userData) => {
    setToken(token)
    setUser(userData)
  }, [])

  const logout = useCallback(() => {
    clearToken()
    setUser(null)
  }, [])

  return (
    <AuthContext.Provider value={{ user, isAuthenticated: !!user, login, logout }}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider')
  return ctx
}
