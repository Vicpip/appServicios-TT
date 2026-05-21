import { useEffect, useRef, useState } from 'react'
import { Navigate, useNavigate } from 'react-router-dom'
import { Loader2, Lock } from 'lucide-react'
import axios from 'axios'
import { useAuth } from '@/auth/AuthContext'

const MAX_ATTEMPTS = 5
const LOCKOUT_SECONDS = 30

interface LoginResponse {
  access_token: string
  token_type: string
}

const LoginPage = () => {
  const { isAuthenticated, login, sessionExpired, clearSessionExpired } = useAuth()
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const [attempts, setAttempts] = useState(0)
  const [lockoutSecondsLeft, setLockoutSecondsLeft] = useState(0)
  const lockoutTimer = useRef<ReturnType<typeof setInterval> | null>(null)
  const passwordRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    return () => {
      if (lockoutTimer.current) clearInterval(lockoutTimer.current)
    }
  }, [])

  if (isAuthenticated) return <Navigate to="/" replace />

  const isLockedOut = lockoutSecondsLeft > 0

  const startLockout = () => {
    setLockoutSecondsLeft(LOCKOUT_SECONDS)
    lockoutTimer.current = setInterval(() => {
      setLockoutSecondsLeft((prev) => {
        if (prev <= 1) {
          clearInterval(lockoutTimer.current!)
          lockoutTimer.current = null
          return 0
        }
        return prev - 1
      })
    }, 1000)
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (isLockedOut || loading) return

    setError(null)
    setLoading(true)

    try {
      const res = await axios.post<LoginResponse>(
        `${import.meta.env.VITE_API_URL}/api/auth/login`,
        { email: email.trim(), password, client_type: 'web' },
        { headers: { 'Content-Type': 'application/json' } }
      )
      clearSessionExpired()
      login(res.data.access_token)
      navigate('/', { replace: true })
    } catch {
      const next = attempts + 1
      setAttempts(next)
      setError('Credenciales inválidas')
      setPassword('')
      passwordRef.current?.focus()
      if (next >= MAX_ATTEMPTS) {
        setAttempts(0)
        startLockout()
      }
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-surface flex items-center justify-center p-4">
      <div className="w-full max-w-sm bg-white rounded-2xl shadow-lg border border-border p-8">
        {/* Logo + nombre */}
        <div className="flex flex-col items-center mb-8">
          <img
            src="/logo_smp.png"
            alt="Servicios Main PC"
            className="h-14 w-auto object-contain mb-4"
            draggable={false}
          />
          <h1 className="text-xl font-bold text-navy font-heading">Servicios Main PC</h1>
          <p className="text-sm text-gray-500 mt-1">Panel de Administración</p>
        </div>

        {/* Aviso de sesión expirada */}
        {sessionExpired && (
          <div
            className="mb-5 px-4 py-3 rounded-lg bg-amber-50 border border-amber-200 text-amber-800 text-sm text-center"
            role="status"
          >
            Tu sesión expiró por inactividad. Inicia sesión nuevamente.
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4" autoComplete="off">
          <div>
            <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-1">
              Correo electrónico
            </label>
            <input
              id="email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              disabled={isLockedOut || loading}
              autoComplete="email"
              className="w-full px-3 py-2.5 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-primary disabled:opacity-50 disabled:bg-gray-50 transition-colors"
              placeholder="correo@ejemplo.com"
            />
          </div>

          <div>
            <label htmlFor="password" className="block text-sm font-medium text-gray-700 mb-1">
              Contraseña
            </label>
            <input
              id="password"
              type="password"
              ref={passwordRef}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              disabled={isLockedOut || loading}
              autoComplete="off"
              className="w-full px-3 py-2.5 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-primary disabled:opacity-50 disabled:bg-gray-50 transition-colors"
              placeholder="••••••••"
            />
          </div>

          {error && !isLockedOut && (
            <p className="text-sm text-red-600 text-center" role="alert">
              {error}
            </p>
          )}

          {isLockedOut && (
            <div
              className="text-sm text-red-700 bg-red-50 border border-red-200 rounded-lg px-4 py-3 text-center"
              role="alert"
            >
              Demasiados intentos fallidos. Espera{' '}
              <span className="font-bold tabular-nums">{lockoutSecondsLeft}s</span> para volver a
              intentarlo.
            </div>
          )}

          <button
            type="submit"
            disabled={isLockedOut || loading}
            className="w-full flex items-center justify-center gap-2 bg-primary hover:bg-primary-dark text-white font-medium py-2.5 px-4 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed mt-2"
          >
            {loading ? (
              <>
                <Loader2 size={16} className="animate-spin" aria-hidden="true" />
                Iniciando sesión…
              </>
            ) : isLockedOut ? (
              <>
                <Lock size={16} aria-hidden="true" />
                Bloqueado ({lockoutSecondsLeft}s)
              </>
            ) : (
              'Iniciar sesión'
            )}
          </button>
        </form>
      </div>
    </div>
  )
}

export default LoginPage
