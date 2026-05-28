import { useState } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import api from '../api/axios'

export default function Login() {
  const navigate = useNavigate()
  const [form, setForm]       = useState({ email: '', password: '' })
  const [error, setError]     = useState('')
  const [loading, setLoading] = useState(false)

  const handleChange = (e) =>
    setForm((f) => ({ ...f, [e.target.name]: e.target.value }))

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      const { data } = await api.post('/api/portal/login', {
        email:    form.email,
        password: form.password,
      })
      localStorage.setItem('portal_token', data.access_token)
      navigate('/dashboard', { replace: true })
    } catch (err) {
      setError(
        err.response?.data?.detail ||
          'Credenciales incorrectas. Intente de nuevo.'
      )
    } finally {
      setLoading(false)
    }
  }

  return (
    /* Full-screen navy background — same as admin-web sidebar color */
    <div className="min-h-screen bg-navy flex items-center justify-center p-4 relative overflow-hidden">

      {/* Background glow decorations */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-40 -right-40 h-96 w-96 rounded-full bg-primary/20 blur-3xl" />
        <div className="absolute -bottom-40 -left-40 h-96 w-96 rounded-full bg-primary-light/10 blur-3xl" />
      </div>

      <div className="relative w-full max-w-md">

        {/* Logo block */}
        <div className="mb-8 text-center">
          <div className="inline-flex h-16 w-16 items-center justify-center rounded-2xl bg-primary shadow-lg shadow-primary/40 mb-4">
            <span className="text-white font-bold text-xl font-heading">SM</span>
          </div>
          <h1 className="text-2xl font-bold text-white font-heading">Servicios Main PC</h1>
          <p className="text-[#A8BBDE] text-sm mt-1 font-sans">Portal de Clientes</p>
        </div>

        {/* Card — white, rounded-2xl, heavy shadow */}
        <div className="bg-white rounded-2xl shadow-2xl p-8">
          <h2 className="text-lg font-semibold text-[#1A1A2E] mb-6 font-heading">Iniciar sesión</h2>

          {error && (
            <div className="mb-4 rounded-lg bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-700 font-sans">
              {error}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-5">
            <div>
              <label htmlFor="email" className="block text-sm font-medium text-gray-700 font-sans mb-1.5">
                Correo electrónico
              </label>
              <input
                id="email"
                name="email"
                type="email"
                autoComplete="email"
                required
                className="input"
                placeholder="usuario@empresa.com"
                value={form.email}
                onChange={handleChange}
              />
            </div>

            <div>
              <div className="flex items-center justify-between mb-1.5">
                <label htmlFor="password" className="block text-sm font-medium text-gray-700 font-sans">
                  Contraseña
                </label>
                <Link to="/recuperar" className="text-xs text-primary hover:underline font-sans">
                  ¿Olvidó su contraseña?
                </Link>
              </div>
              <input
                id="password"
                name="password"
                type="password"
                autoComplete="current-password"
                required
                className="input"
                placeholder="••••••••"
                value={form.password}
                onChange={handleChange}
              />
            </div>

            <button
              type="submit"
              disabled={loading}
              className="btn-primary w-full py-3"
            >
              {loading ? 'Iniciando sesión…' : 'Entrar'}
            </button>
          </form>
        </div>

        <p className="mt-6 text-center text-xs text-[#6B85BE] font-sans">
          ¿No tiene cuenta? Solicite una invitación a su técnico asignado.
        </p>
      </div>
    </div>
  )
}
