import { useState } from 'react'
import { useNavigate, useSearchParams, Link } from 'react-router-dom'
import api from '../api/axios'

export default function ResetPassword() {
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const token = searchParams.get('token') ?? ''

  const [form, setForm]       = useState({ password: '', confirm: '' })
  const [error, setError]     = useState('')
  const [loading, setLoading] = useState(false)

  const handleChange = (e) =>
    setForm((f) => ({ ...f, [e.target.name]: e.target.value }))

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')
    if (form.password !== form.confirm) {
      setError('Las contraseñas no coinciden.')
      return
    }
    setLoading(true)
    try {
      await api.post('/api/portal/auth/reset-password', { token, password: form.password })
      navigate('/login?reset=1', { replace: true })
    } catch (err) {
      setError(err.response?.data?.detail || 'Enlace inválido o expirado.')
    } finally {
      setLoading(false)
    }
  }

  if (!token) {
    return (
      <div className="min-h-screen bg-navy flex items-center justify-center p-4">
        <div className="bg-white rounded-2xl p-8 max-w-sm w-full text-center">
          <p className="text-red-600 font-medium font-sans">Enlace inválido o expirado.</p>
          <Link to="/recuperar" className="btn-primary mt-4 inline-block">Solicitar nuevo enlace</Link>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-navy flex items-center justify-center p-4 relative overflow-hidden">
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -bottom-40 -right-40 h-96 w-96 rounded-full bg-primary/20 blur-3xl" />
      </div>

      <div className="relative w-full max-w-md">
        <div className="mb-8 text-center">
          <div className="inline-flex h-16 w-16 items-center justify-center rounded-2xl bg-primary shadow-lg shadow-primary/40 mb-4">
            <span className="text-white font-bold text-xl font-heading">SM</span>
          </div>
          <h1 className="text-2xl font-bold text-white font-heading">Nueva contraseña</h1>
          <p className="text-[#A8BBDE] text-sm mt-1 font-sans">Portal de Clientes</p>
        </div>

        <div className="bg-white rounded-2xl shadow-2xl p-8">
          <h2 className="text-lg font-semibold text-[#1A1A2E] mb-6 font-heading">Restablecer contraseña</h2>

          {error && (
            <div className="mb-4 rounded-lg bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-700">{error}</div>
          )}

          <form onSubmit={handleSubmit} className="space-y-5">
            <div>
              <label htmlFor="new-password" className="block text-sm font-medium text-gray-700 mb-1.5">Nueva contraseña</label>
              <input id="new-password" name="password" type="password" required minLength={8} className="input" placeholder="Mínimo 8 caracteres" value={form.password} onChange={handleChange} />
            </div>
            <div>
              <label htmlFor="rp-confirm" className="block text-sm font-medium text-gray-700 mb-1.5">Confirmar contraseña</label>
              <input id="rp-confirm" name="confirm" type="password" required className="input" placeholder="Repita la contraseña" value={form.confirm} onChange={handleChange} />
            </div>
            <button type="submit" disabled={loading} className="btn-primary w-full py-3">
              {loading ? 'Guardando…' : 'Guardar contraseña'}
            </button>
          </form>
        </div>
      </div>
    </div>
  )
}
