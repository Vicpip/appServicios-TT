import { Navigate, Outlet } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'

/**
 * Renders child routes only when a valid JWT exists.
 * Redirects to /login otherwise, preserving the attempted URL.
 */
export default function ProtectedRoute() {
  const { isAuthenticated } = useAuth()
  return isAuthenticated ? <Outlet /> : <Navigate to="/login" replace />
}
