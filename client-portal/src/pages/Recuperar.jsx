import { useState } from 'react'
import { Link } from 'react-router-dom'
import api from '../api/axios'

export default function Recuperar() {
  const [email, setEmail]     = useState('')
  const [sent, setSent]       = useState(false)
  const [error, setError]     = useState('')
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      await api.post('/api/portal/auth/forgot-password', { email })
      setSent(true)
    } catch (err) {
      setError(err.response?.data?.detail || 'Error al procesar la solicitud.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-navy flex items-center justify-center p-4 relative overflow-hidden">
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-40 -left-40 h-96 w-96 rounded-full bg-primary/20 blur-3xl" />
      </div>

      <div className="relative w-full max-w-md">
        <div className="mb-8 text-center">
          <div className="inline-flex h-16 w-16 items-center justify-center rounded-2xl bg-primary shadow-lg shadow-primary/40 mb-4">
            <span className="text-white font-bold text-xl font-heading">SM</span>
          </div>
          <h1 className="text-2xl font-bold text-white font-heading">Recuperar contraseña</h1>
          <p className="text-[#A8BBDE] text-sm mt-1 font-sans">Portal de Clientes</p>
        </div>

        <div className="bg-white rounded-2xl shadow-2xl p-8">
          {sent ? (
            <div className="text-center py-4">
              <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-green-100">
                <svg className="h-7 w-7 text-green-500" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                  <path d="M5 13l4 4L19 7" />
                </svg>
              </div>
              <h2 className="text-lg font-semibold text-gray-800">Correo enviado</h2>
              <p className="text-sm text-gray-500 mt-2">
                Si el correo está registrado, recibirá un enlace para restablecer su contraseña.
              </p>
              <Link to="/login" className="btn-primary mt-6 inline-block">Volver al inicio de sesión</Link>
            </div>
          ) : (
            <>
              <h2 className="text-lg font-semibold text-gray-800 mb-2">Olvidé mi contraseña</h2>
              <p className="text-sm text-gray-500 mb-6">
                Ingrese su correo y le enviaremos un enlace para restablecerla.
              </p>

              {error && (
                <div className="mb-4 rounded-lg bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-700">{error}</div>
              )}

              <form onSubmit={handleSubmit} className="space-y-5">
                <div>
                  <label htmlFor="rec-email" className="block text-sm font-medium text-gray-700 mb-1.5">Correo electrónico</label>
                  <input id="rec-email" type="email" required className="input" placeholder="usuario@empresa.com" value={email} onChange={(e) => setEmail(e.target.value)} />
                </div>
                <button type="submit" disabled={loading} className="btn-primary w-full py-3">
                  {loading ? 'Enviando…' : 'Enviar enlace'}
                </button>
              </form>

              <p className="mt-4 text-center text-sm text-gray-500">
                <Link to="/login" className="text-primary hover:underline font-sans">Volver al inicio de sesión</Link>
              </p>
            </>
          )}
        </div>
      </div>
    </div>
  )
}
