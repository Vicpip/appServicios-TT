import { useState, useEffect } from 'react'
import { useSearchParams, useNavigate } from 'react-router-dom'
import { Loader2 } from 'lucide-react'
import axios from 'axios'

const PASSWORD_CRITERIA = [
  { label: 'Mínimo 8 caracteres', test: (p) => p.length >= 8 },
  { label: 'Una mayúscula', test: (p) => /[A-Z]/.test(p) },
  { label: 'Un número', test: (p) => /[0-9]/.test(p) },
  { label: 'Un carácter especial', test: (p) => /[!@#$%^&*-]/.test(p) },
]

export default function Registro() {
  const [searchParams] = useSearchParams()
  const navigate = useNavigate()

  const token = searchParams.get('token') ?? ''

  // Invite info state
  const [inviteEmail, setInviteEmail] = useState(null)
  const [inviteLoading, setInviteLoading] = useState(true)
  const [inviteError, setInviteError] = useState('')

  // Form state
  const [name, setName] = useState('')
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [submitError, setSubmitError] = useState('')
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    if (!token) {
      setInviteLoading(false)
      return
    }

    let cancelled = false

    axios
      .get(`${import.meta.env.VITE_API_URL}/api/portal/invite/info`, {
        params: { token },
      })
      .then((res) => {
        if (!cancelled) setInviteEmail(res.data.email)
      })
      .catch(() => {
        if (!cancelled)
          setInviteError('Este enlace de invitación no es válido o ha expirado.')
      })
      .finally(() => {
        if (!cancelled) setInviteLoading(false)
      })

    return () => { cancelled = true }
  }, [token])

  const criteria = PASSWORD_CRITERIA.map((c) => ({ label: c.label, met: c.test(password) }))
  const allCriteriaMet = criteria.every((c) => c.met)
  const isFormValid =
    !inviteError &&
    name.trim().length >= 2 &&
    allCriteriaMet &&
    password === confirmPassword

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (loading || !isFormValid) return

    setSubmitError('')
    setLoading(true)

    try {
      await axios.post(
        `${import.meta.env.VITE_API_URL}/api/portal/register`,
        { token, name: name.trim(), password },
        { headers: { 'Content-Type': 'application/json' } }
      )
      navigate('/login', { replace: true, state: { registered: true } })
    } catch (err) {
      const msg =
        err.response?.data?.detail ?? 'Error al registrar. Verifica tu enlace de invitación.'
      setSubmitError(typeof msg === 'string' ? msg : 'Error al registrar. Intenta de nuevo.')
    } finally {
      setLoading(false)
    }
  }

  if (!token) {
    return (
      <div className="min-h-screen bg-surface flex items-center justify-center p-4">
        <div className="bg-white rounded-2xl shadow-lg border border-border p-8 text-center max-w-sm w-full">
          <p className="text-sm text-red-600">Enlace de registro inválido o expirado.</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-surface flex items-center justify-center p-4">
      <div className="w-full max-w-sm bg-white rounded-2xl shadow-lg border border-border p-8">
        <div className="flex flex-col items-center mb-8">
          <img
            src="/logo_smp.png"
            alt="SMP"
            className="h-14 w-auto object-contain mb-4"
            draggable={false}
          />
          <h1 className="text-xl font-bold text-navy font-heading">Crear cuenta</h1>
          <p className="text-sm text-gray-500 mt-1">Portal de Clientes — SMP</p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4" noValidate>
          {/* Email field — skeleton while loading, readonly when ready */}
          <div>
            <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-1">
              Correo electrónico
            </label>
            {inviteLoading ? (
              <div className="w-full h-10 rounded-lg bg-gray-200 animate-pulse" />
            ) : inviteError ? (
              <p className="text-sm text-red-600" role="alert">{inviteError}</p>
            ) : (
              <input
                id="email"
                type="email"
                value={inviteEmail ?? ''}
                disabled
                readOnly
                className="w-full px-3 py-2.5 rounded-lg border border-border text-sm bg-gray-100 text-gray-500 cursor-not-allowed"
              />
            )}
          </div>

          <div>
            <label htmlFor="name" className="block text-sm font-medium text-gray-700 mb-1">
              Nombre completo
            </label>
            <input
              id="name"
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              disabled={loading || !!inviteError || inviteLoading}
              className="w-full px-3 py-2.5 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-primary disabled:opacity-50 transition-colors"
              placeholder="Tu nombre"
            />
          </div>

          <div>
            <label htmlFor="password" className="block text-sm font-medium text-gray-700 mb-1">
              Contraseña
            </label>
            <input
              id="password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              disabled={loading || !!inviteError || inviteLoading}
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
              disabled={loading || !!inviteError || inviteLoading}
              autoComplete="new-password"
              className="w-full px-3 py-2.5 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-primary disabled:opacity-50 transition-colors"
              placeholder="Repite tu contraseña"
            />
            {confirmPassword && password !== confirmPassword && (
              <p className="mt-1 text-xs text-red-600">Las contraseñas no coinciden</p>
            )}
          </div>

          {submitError && (
            <p className="text-sm text-red-600 text-center" role="alert">
              {submitError}
            </p>
          )}

          <button
            type="submit"
            disabled={loading || !isFormValid || inviteLoading}
            className="w-full flex items-center justify-center gap-2 bg-primary hover:bg-primary-dark text-white font-medium py-2.5 px-4 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? (
              <>
                <Loader2 size={16} className="animate-spin" aria-hidden="true" />
                Creando cuenta…
              </>
            ) : (
              'Crear cuenta'
            )}
          </button>
        </form>
      </div>
    </div>
  )
}
