import { useState, useMemo } from 'react'
import { useSearchParams, useNavigate } from 'react-router-dom'
import { jwtDecode } from 'jwt-decode'
import { Loader2 } from 'lucide-react'
import axios from 'axios'

const PASSWORD_CRITERIA = [
  { label: 'Mínimo 8 caracteres', test: (p) => p.length >= 8 },
  { label: 'Una mayúscula', test: (p) => /[A-Z]/.test(p) },
  { label: 'Un número', test: (p) => /[0-9]/.test(p) },
  { label: 'Un carácter especial', test: (p) => /[!@#$%^&*-]/.test(p) },
]

function decodeEmail(token) {
  try {
    const payload = jwtDecode(token)
    return typeof payload?.email === 'string' ? payload.email : null
  } catch {
    return null
  }
}

export default function ResetPassword() {
  const [searchParams] = useSearchParams()
  const navigate = useNavigate()

  const token = searchParams.get('token') ?? ''
  const decodedEmail = useMemo(() => (token ? decodeEmail(token) : null), [token])

  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  const criteria = PASSWORD_CRITERIA.map((c) => ({ label: c.label, met: c.test(password) }))
  const allCriteriaMet = criteria.every((c) => c.met)
  const passwordsMatch = password === confirmPassword
  const isFormValid = allCriteriaMet && passwordsMatch && confirmPassword.length > 0

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (loading || !isFormValid) return

    setError('')
    setLoading(true)

    try {
      await axios.post(
        `${import.meta.env.VITE_API_URL}/api/portal/reset-password`,
        { token, new_password: password },
        { headers: { 'Content-Type': 'application/json' } }
      )
      navigate('/login', { replace: true })
    } catch (err) {
      const msg = err.response?.data?.detail ?? 'Error al restablecer. El enlace puede haber expirado.'
      setError(typeof msg === 'string' ? msg : 'Error al restablecer la contraseña.')
    } finally {
      setLoading(false)
    }
  }

  if (!token) {
    return (
      <div className="min-h-screen bg-surface flex items-center justify-center p-4">
        <div className="bg-white rounded-2xl shadow-lg border border-border p-8 text-center max-w-sm w-full">
          <p className="text-sm text-red-600">Enlace de restablecimiento inválido o expirado.</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-surface flex items-center justify-center p-4">
      <div className="w-full max-w-sm bg-white rounded-2xl shadow-lg border border-border p-8">
        <div className="flex flex-col items-center mb-8">
          <img src="/logo_smp.png" alt="SMP" className="h-14 w-auto object-contain mb-4" draggable={false} />
          <h1 className="text-xl font-bold text-navy font-heading">Nueva contraseña</h1>
          <p className="text-sm text-gray-500 mt-1">Ingresa tu nueva contraseña</p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4" noValidate>
          {decodedEmail && (
            <div>
              <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-1">
                Correo electrónico
              </label>
              <input
                id="email"
                type="email"
                value={decodedEmail}
                readOnly
                disabled
                className="w-full px-3 py-2.5 rounded-lg border border-border text-sm bg-gray-100 text-gray-500 cursor-not-allowed"
              />
            </div>
          )}

          <div>
            <label htmlFor="password" className="block text-sm font-medium text-gray-700 mb-1">
              Nueva contraseña
            </label>
            <input
              id="password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              disabled={loading}
              autoComplete="new-password"
              className="w-full px-3 py-2.5 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-primary disabled:opacity-50 transition-colors"
              placeholder="Crea tu contraseña"
            />
            {password && (
              <ul className="mt-2 space-y-1" aria-label="Requisitos de contraseña">
                {criteria.map((c) => (
                  <li
                    key={c.label}
                    className={`flex items-center gap-1.5 text-xs ${c.met ? 'text-green-600' : 'text-red-500'}`}
                  >
                    <span aria-hidden="true">{c.met ? '✓' : '✗'}</span>
                    {c.label}
                  </li>
                ))}
              </ul>
            )}
          </div>

          <div>
            <label htmlFor="confirmPassword" className="block text-sm font-medium text-gray-700 mb-1">
              Confirmar contraseña
            </label>
            <input
              id="confirmPassword"
              type="password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              disabled={loading}
              autoComplete="new-password"
              className="w-full px-3 py-2.5 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-primary disabled:opacity-50 transition-colors"
              placeholder="Repite tu contraseña"
            />
            {confirmPassword && !passwordsMatch && (
              <p className="mt-1 text-xs text-red-600">Las contraseñas no coinciden</p>
            )}
          </div>

          {error && (
            <p className="text-sm text-red-600 text-center" role="alert">{error}</p>
          )}

          <button
            type="submit"
            disabled={loading || !isFormValid}
            className="w-full flex items-center justify-center gap-2 bg-primary hover:bg-primary-dark text-white font-medium py-2.5 px-4 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? (
              <>
                <Loader2 size={16} className="animate-spin" aria-hidden="true" />
                Guardando…
              </>
            ) : 'Guardar contraseña'}
          </button>
        </form>
      </div>
    </div>
  )
}
