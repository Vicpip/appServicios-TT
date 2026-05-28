import { useState } from 'react'
import { Link } from 'react-router-dom'
import { Loader2, CheckCircle } from 'lucide-react'
import axios from 'axios'

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

export default function Recuperar() {
  const [email, setEmail] = useState('')
  const [emailError, setEmailError] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const [sent, setSent] = useState(false)

  const validate = () => {
    setEmailError('')
    if (!EMAIL_RE.test(email.trim())) {
      setEmailError('Ingresa un correo electrónico válido')
      return false
    }
    return true
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (loading) return
    if (!validate()) return

    setError('')
    setLoading(true)

    try {
      await axios.post(
        `${import.meta.env.VITE_API_URL}/api/portal/forgot-password`,
        { email: email.trim() },
        { headers: { 'Content-Type': 'application/json' } }
      )
      setSent(true)
    } catch {
      setError('No se pudo enviar el correo. Intenta de nuevo.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-surface flex items-center justify-center p-4">
      <div className="w-full max-w-sm bg-white rounded-2xl shadow-lg border border-border p-8">
        <div className="flex flex-col items-center mb-8">
          <img src="/logo_smp.png" alt="SMP" className="h-14 w-auto object-contain mb-4" draggable={false} />
          <h1 className="text-xl font-bold text-navy font-heading">Recuperar contraseña</h1>
          <p className="text-sm text-gray-500 mt-1 text-center">
            Te enviaremos un enlace para restablecer tu contraseña
          </p>
        </div>

        {sent ? (
          <div className="flex flex-col items-center gap-3 py-4 text-center">
            <CheckCircle size={36} className="text-green-500" />
            <p className="text-sm text-gray-700">
              Si el correo está registrado, recibirás un enlace en breve.
            </p>
            <Link to="/login" className="text-sm text-primary hover:underline mt-2">
              Volver al inicio de sesión
            </Link>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="space-y-4" noValidate>
            <div>
              <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-1">
                Correo electrónico
              </label>
              <input
                id="email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                disabled={loading}
                autoComplete="email"
                className="w-full px-3 py-2.5 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-primary disabled:opacity-50 transition-colors"
                placeholder="correo@empresa.com"
              />
              {emailError && <p className="mt-1 text-xs text-red-600">{emailError}</p>}
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
                  Enviando…
                </>
              ) : 'Enviar enlace'}
            </button>

            <div className="text-center">
              <Link to="/login" className="text-sm text-primary hover:underline">
                Volver al inicio de sesión
              </Link>
            </div>
          </form>
        )}
      </div>
    </div>
  )
}
