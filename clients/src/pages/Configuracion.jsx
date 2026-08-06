import { useEffect, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Mail, Plus, Trash2 } from 'lucide-react'
import apiClient from '@/api/axios'
import { useAuth } from '@/hooks/useAuth'
import { SkeletonLine } from '@/components/Skeleton'
import EmptyState from '@/components/EmptyState'

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

export default function Configuracion() {
  const { user } = useAuth()
  const clientId = user?.client_id

  const [emails, setEmails] = useState([])
  const [showForm, setShowForm] = useState(false)
  const [newEmail, setNewEmail] = useState('')
  const [newLabel, setNewLabel] = useState('')
  const [formError, setFormError] = useState(null)
  const [saving, setSaving] = useState(false)
  const [actionIds, setActionIds] = useState(new Set())
  const [confirmId, setConfirmId] = useState(null)
  const [actionError, setActionError] = useState(null)

  const { data, isLoading, error } = useQuery({
    queryKey: ['portal', 'contact-emails', clientId],
    queryFn: async () => {
      const res = await apiClient.get(`/api/admin/clients/${clientId}/contact-emails`)
      return res.data
    },
    enabled: !!clientId,
  })

  useEffect(() => {
    if (data) setEmails(data)
  }, [data])

  async function handleAdd(e) {
    e.preventDefault()
    setFormError(null)
    const trimmed = newEmail.trim()
    if (!EMAIL_RE.test(trimmed)) {
      setFormError('Ingresa un correo electrónico válido.')
      return
    }
    setSaving(true)
    try {
      const res = await apiClient.post(`/api/admin/clients/${clientId}/contact-emails`, {
        email: trimmed,
        label: newLabel.trim() || null,
      })
      setEmails((prev) => [...prev, res.data])
      setNewEmail('')
      setNewLabel('')
      setShowForm(false)
    } catch (err) {
      setFormError(err?.response?.data?.detail ?? 'Error al agregar el correo.')
    } finally {
      setSaving(false)
    }
  }

  async function handleDelete(emailId) {
    setActionIds((prev) => new Set(prev).add(emailId))
    setActionError(null)
    try {
      await apiClient.delete(`/api/admin/clients/${clientId}/contact-emails/${emailId}`)
      setEmails((prev) => prev.filter((em) => em.id !== emailId))
    } catch (err) {
      setActionError(err?.response?.data?.detail ?? 'Error al eliminar el correo.')
    } finally {
      setActionIds((prev) => {
        const next = new Set(prev)
        next.delete(emailId)
        return next
      })
      setConfirmId(null)
    }
  }

  return (
    <div className="space-y-5">
      <div>
        <h2 className="text-xl font-bold text-[#1A1A2E] font-heading">Configuración</h2>
        <p className="text-sm text-gray-400 font-sans mt-0.5">
          Administra los correos que reciben notificaciones de tus reportes de servicio
        </p>
      </div>

      <div className="bg-white rounded-xl border border-border shadow-sm">
        <div className="px-5 py-4 border-b border-border flex items-center gap-3 flex-wrap">
          <div className="w-9 h-9 rounded-lg bg-primary/10 flex items-center justify-center shrink-0">
            <Mail size={17} className="text-primary" />
          </div>
          <div>
            <h3 className="font-semibold text-[#1A1A2E] font-heading text-sm">Correos para notificaciones</h3>
            <p className="text-xs text-gray-400 font-sans">Reciben copia de tus reportes de servicio firmados</p>
          </div>
          <button
            onClick={() => { setShowForm((v) => !v); setFormError(null) }}
            className="ml-auto flex items-center gap-1.5 px-3 py-2 text-xs font-semibold font-sans text-primary bg-primary/10 border border-primary/20 hover:bg-primary/20 rounded-lg transition-colors"
          >
            <Plus size={14} />
            Agregar correo
          </button>
        </div>

        {showForm && (
          <form
            onSubmit={handleAdd}
            className="px-5 py-4 border-b border-border bg-gray-50/60 flex items-start gap-2 flex-wrap"
          >
            <div className="flex-1 min-w-[200px]">
              <input
                type="email"
                value={newEmail}
                onChange={(e) => { setNewEmail(e.target.value); setFormError(null) }}
                placeholder="correo@empresa.com"
                className="w-full text-sm font-sans border border-border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary focus:border-primary bg-white"
                autoFocus
              />
            </div>
            <div className="w-44">
              <input
                type="text"
                value={newLabel}
                onChange={(e) => setNewLabel(e.target.value)}
                placeholder="Etiqueta (opcional)"
                className="w-full text-sm font-sans border border-border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary focus:border-primary bg-white"
              />
            </div>
            <button
              type="submit"
              disabled={saving}
              className="px-4 py-2 text-sm font-semibold font-sans text-white bg-primary hover:bg-primary/90 disabled:opacity-60 disabled:cursor-not-allowed rounded-lg transition-colors"
            >
              {saving ? 'Guardando…' : 'Guardar'}
            </button>
            <button
              type="button"
              onClick={() => { setShowForm(false); setNewEmail(''); setNewLabel(''); setFormError(null) }}
              className="px-4 py-2 text-sm font-semibold font-sans text-gray-600 bg-gray-100 hover:bg-gray-200 rounded-lg transition-colors"
            >
              Cancelar
            </button>
            {formError && <p className="w-full text-xs text-red-600 font-sans">{formError}</p>}
          </form>
        )}

        {error && (
          <p className="px-5 py-4 text-sm text-red-600 font-sans" role="alert">
            Error al cargar los correos de contacto. Intenta recargar la página.
          </p>
        )}

        {actionError && (
          <p className="px-5 pt-3 text-xs text-red-600 font-sans">{actionError}</p>
        )}

        {isLoading ? (
          <div className="p-5 space-y-2">
            {[1, 2].map((i) => <SkeletonLine key={i} className="h-9" />)}
          </div>
        ) : emails.length === 0 ? (
          <EmptyState message="No tienes correos de notificación registrados" icon={Mail} />
        ) : (
          <ul className="divide-y divide-gray-50">
            {emails.map((em) => (
              <li key={em.id} className="flex items-center justify-between gap-3 px-5 py-3">
                <div className="min-w-0">
                  <p className="text-sm font-medium text-[#1A1A2E] font-sans truncate">{em.email}</p>
                  {em.label && <p className="text-xs text-gray-400 font-sans mt-0.5">{em.label}</p>}
                </div>
                {confirmId === em.id ? (
                  <div className="flex items-center gap-1.5 shrink-0">
                    <button
                      onClick={() => handleDelete(em.id)}
                      disabled={actionIds.has(em.id)}
                      className="px-2.5 py-1.5 text-xs font-semibold font-sans text-white bg-red-600 hover:bg-red-700 rounded-lg transition-colors disabled:opacity-60"
                    >
                      {actionIds.has(em.id) ? '...' : 'Confirmar'}
                    </button>
                    <button
                      onClick={() => setConfirmId(null)}
                      className="px-2.5 py-1.5 text-xs font-semibold font-sans text-gray-600 bg-gray-100 hover:bg-gray-200 rounded-lg transition-colors"
                    >
                      Cancelar
                    </button>
                  </div>
                ) : (
                  <button
                    onClick={() => setConfirmId(em.id)}
                    title="Eliminar"
                    className="shrink-0 p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition-colors"
                  >
                    <Trash2 size={15} />
                  </button>
                )}
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  )
}
