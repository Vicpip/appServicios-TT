import { useState } from 'react'
import { useSearchParams, useNavigate } from 'react-router-dom'
import { Loader2 } from 'lucide-react'
import axios from 'axios'

export default function ResetPassword() {
  const [searchParams] = useSearchParams()
  const navigate = useNavigate()

  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [passwordError, setPasswordError] = useState('')
  const [confirmError, setConfirmError] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  const token = searchParams.get('token') ?? ''

  const validate = () => {
    let valid = true
    setPasswordError('')
    setConfirmError('')

    if (!token) {
      setError('Enlace de restablecimiento inválido o expirado.')
      return false
    }
    if (password.length < 8) {
      setPasswordError('La contraseña debe tener al menos 8 caracteres')
      valid = false
    }
    if (password !== confirmPassword) {
      setConfirmError('Las contraseñas no coinciden')
      valid = false
    }
    return valid
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (loading) return
    if (!validate()) return

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
              placeholder="Mínimo 8 caracteres"
            />
            {passwordError && <p className="mt-1 text-xs text-red-600">{passwordError}</p>}
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
            {confirmError && <p className="mt-1 text-xs text-red-600">{confirmError}</p>}
          </div>

          {error && <p className="text-sm text-red-600 text-center" role="alert">{error}</p>}

          <button
            type="submit"
            disabled={loading}
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
