import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { Users, FileText, Clock, Plus, Pencil, Trash2, X, AlertTriangle, Eye, EyeOff } from 'lucide-react'
import apiClient from '@/api/client'
import { API } from '@/api/endpoints'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface TechnicianListItem {
  id: string
  code: string | null
  name: string
  email: string
  role: string
  reports_count: number
  last_sync_at: string | null
}

interface PagedResponse<T> {
  total: number
  offset: number
  limit: number
  items: T[]
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function fmtDatetime(iso: string) {
  return new Date(iso).toLocaleDateString('es-MX', {
    day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  })
}

function relativeTime(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime()
  const mins = Math.floor(diff / 60_000)
  if (mins < 60) return `hace ${mins}m`
  const hrs = Math.floor(mins / 60)
  if (hrs < 24) return `hace ${hrs}h`
  return `hace ${Math.floor(hrs / 24)}d`
}

function InitialAvatar({ name }: { name: string }) {
  const initials = name.split(' ').slice(0, 2).map((w) => w[0]).join('').toUpperCase()
  return (
    <div className="w-9 h-9 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
      <span className="text-primary font-bold text-sm font-sans">{initials}</span>
    </div>
  )
}

// ---------------------------------------------------------------------------
// Technician modal (create / edit)
// ---------------------------------------------------------------------------

interface TechFormData {
  name: string
  email: string
  password: string
  confirmPassword: string
  role: string
}

const EMPTY_TECH_FORM: TechFormData = { name: '', email: '', password: '', confirmPassword: '', role: 'technician' }

interface TechModalProps {
  tech?: TechnicianListItem | null
  onClose: () => void
}

function TechModal({ tech, onClose }: TechModalProps) {
  const qc = useQueryClient()
  const isEdit = !!tech

  const [form, setForm] = useState<TechFormData>(
    isEdit
      ? { name: tech!.name, email: tech!.email, password: '', confirmPassword: '', role: tech!.role }
      : EMPTY_TECH_FORM,
  )
  const [showPwd, setShowPwd] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const saveMutation = useMutation({
    mutationFn: async () => {
      if (isEdit) {
        const payload: Record<string, string> = {}
        if (form.name !== tech!.name) payload.name = form.name
        if (form.email !== tech!.email) payload.email = form.email
        if (form.role !== tech!.role) payload.role = form.role
        await apiClient.put(API.technicians.detail(tech!.id), payload)
      } else {
        await apiClient.post(API.technicians.create, {
          name: form.name,
          email: form.email,
          password: form.password,
          role: form.role,
        })
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['technicians'] })
      onClose()
    },
    onError: (err: unknown) => {
      const msg = (err as { response?: { data?: { detail?: string } } })?.response?.data?.detail
      setError(msg ?? 'Error al guardar.')
    },
  })

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError(null)
    if (!form.name.trim() || !form.email.trim()) {
      setError('Nombre y email son obligatorios.')
      return
    }
    if (!isEdit) {
      if (!form.password) { setError('La contraseña es obligatoria.'); return }
      if (form.password !== form.confirmPassword) { setError('Las contraseñas no coinciden.'); return }
      if (form.password.length < 6) { setError('La contraseña debe tener al menos 6 caracteres.'); return }
    }
    saveMutation.mutate()
  }

  const inputCls = 'w-full text-sm font-sans border border-border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition-colors'
  const labelCls = 'block text-xs font-semibold text-gray-500 font-sans mb-1'

  return (
    <>
      <div className="fixed inset-0 bg-black/40 z-40" onClick={onClose} />
      <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div className="bg-white rounded-xl shadow-2xl w-full max-w-md flex flex-col">
          {/* Header */}
          <div className="flex items-center justify-between px-6 py-4 border-b border-border shrink-0">
            <div className="flex items-center gap-2">
              <Users size={16} className="text-primary" />
              <h3 className="font-semibold text-[#1A1A2E] font-heading">
                {isEdit ? 'Editar técnico' : 'Nuevo técnico'}
              </h3>
            </div>
            <button onClick={onClose} className="p-1.5 rounded-lg text-gray-400 hover:text-gray-700 hover:bg-gray-100 transition-colors">
              <X size={18} />
            </button>
          </div>

          <form onSubmit={handleSubmit}>
            <div className="px-6 py-5 space-y-4">
              <div>
                <label className={labelCls}>Nombre completo *</label>
                <input type="text" value={form.name} onChange={(e) => setForm((p) => ({ ...p, name: e.target.value }))} className={inputCls} placeholder="Juan García López" />
              </div>
              <div>
                <label className={labelCls}>Email *</label>
                <input type="email" value={form.email} onChange={(e) => setForm((p) => ({ ...p, email: e.target.value }))} className={inputCls} placeholder="juan@empresa.com" />
              </div>
              <div>
                <label className={labelCls}>Rol</label>
                <select value={form.role} onChange={(e) => setForm((p) => ({ ...p, role: e.target.value }))} className={inputCls}>
                  <option value="technician">Técnico</option>
                  <option value="admin">Administrador</option>
                </select>
              </div>

              {!isEdit && (
                <>
                  <div>
                    <label className={labelCls}>Contraseña *</label>
                    <div className="relative">
                      <input
                        type={showPwd ? 'text' : 'password'}
                        value={form.password}
                        onChange={(e) => setForm((p) => ({ ...p, password: e.target.value }))}
                        className={`${inputCls} pr-10`}
                        placeholder="Mínimo 6 caracteres"
                      />
                      <button type="button" onClick={() => setShowPwd((v) => !v)} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
                        {showPwd ? <EyeOff size={15} /> : <Eye size={15} />}
                      </button>
                    </div>
                  </div>
                  <div>
                    <label className={labelCls}>Confirmar contraseña *</label>
                    <input
                      type={showPwd ? 'text' : 'password'}
                      value={form.confirmPassword}
                      onChange={(e) => setForm((p) => ({ ...p, confirmPassword: e.target.value }))}
                      className={inputCls}
                      placeholder="Repite la contraseña"
                    />
                  </div>
                </>
              )}

              {error && (
                <div className="flex items-center gap-2 bg-red-50 border border-red-200 rounded-lg px-3 py-2.5">
                  <AlertTriangle size={14} className="text-red-500 shrink-0" />
                  <p className="text-sm text-red-600 font-sans">{error}</p>
                </div>
              )}
            </div>

            <div className="px-6 py-4 border-t border-border bg-gray-50 flex gap-2 justify-end">
              <button type="button" onClick={onClose} className="px-4 py-2 text-sm font-semibold text-gray-600 font-sans rounded-lg hover:bg-gray-100 transition-colors">
                Cancelar
              </button>
              <button type="submit" disabled={saveMutation.isPending} className="px-5 py-2 text-sm font-semibold text-white bg-primary hover:bg-primary-dark disabled:opacity-50 rounded-lg transition-colors font-sans">
                {saveMutation.isPending ? 'Guardando…' : isEdit ? 'Guardar cambios' : 'Crear técnico'}
              </button>
            </div>
          </form>
        </div>
      </div>
    </>
  )
}

// ---------------------------------------------------------------------------
// Delete confirm
// ---------------------------------------------------------------------------

function DeleteTechModal({ tech, onClose }: { tech: TechnicianListItem; onClose: () => void }) {
  const qc = useQueryClient()
  const deleteMutation = useMutation({
    mutationFn: async () => apiClient.delete(API.technicians.detail(tech.id)),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['technicians'] }); onClose() },
  })

  return (
    <>
      <div className="fixed inset-0 bg-black/40 z-40" onClick={onClose} />
      <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div className="bg-white rounded-xl shadow-2xl w-full max-w-sm p-6">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 rounded-full bg-red-50 flex items-center justify-center shrink-0">
              <AlertTriangle size={18} className="text-red-500" />
            </div>
            <div>
              <h3 className="font-semibold text-[#1A1A2E] font-heading">Desactivar técnico</h3>
              <p className="text-sm text-gray-400 font-sans">El técnico quedará inactivo.</p>
            </div>
          </div>
          <p className="text-sm text-gray-600 font-sans mb-5">
            ¿Desactivar a <span className="font-semibold">{tech.name}</span>?
          </p>
          <div className="flex gap-2 justify-end">
            <button onClick={onClose} className="px-4 py-2 text-sm font-semibold text-gray-600 font-sans rounded-lg hover:bg-gray-100 transition-colors">Cancelar</button>
            <button onClick={() => deleteMutation.mutate()} disabled={deleteMutation.isPending} className="px-4 py-2 text-sm font-semibold text-white bg-red-500 hover:bg-red-600 disabled:opacity-50 rounded-lg transition-colors font-sans">
              {deleteMutation.isPending ? 'Desactivando…' : 'Desactivar'}
            </button>
          </div>
        </div>
      </div>
    </>
  )
}

// ---------------------------------------------------------------------------
// Main page
// ---------------------------------------------------------------------------

export default function TechniciansPage() {
  const [showCreate, setShowCreate] = useState(false)
  const [editTech, setEditTech] = useState<TechnicianListItem | null>(null)
  const [deleteTech, setDeleteTech] = useState<TechnicianListItem | null>(null)

  const { data, isLoading, isFetching } = useQuery({
    queryKey: ['technicians'],
    queryFn: async () => {
      const res = await apiClient.get<PagedResponse<TechnicianListItem>>(API.technicians.list, {
        params: { limit: 200 },
      })
      return res.data
    },
    placeholderData: (prev) => prev,
    retry: false,
  })

  const items = data?.items ?? []
  const total = data?.total ?? 0

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h2 className="text-xl font-bold text-[#1A1A2E] font-heading">Técnicos</h2>
          <p className="text-sm text-gray-400 font-sans mt-0.5">
            {isFetching ? 'Actualizando…' : `${total} técnico${total !== 1 ? 's' : ''} registrado${total !== 1 ? 's' : ''}`}
          </p>
        </div>
        <button
          onClick={() => setShowCreate(true)}
          className="flex items-center gap-2 bg-primary hover:bg-primary-dark text-white text-sm font-semibold font-sans rounded-lg px-4 py-2 transition-colors"
        >
          <Plus size={15} />
          Nuevo técnico
        </button>
      </div>

      {/* Cards grid */}
      {isLoading ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">
          {Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className="bg-white rounded-xl border border-border p-5 shadow-sm animate-pulse space-y-3">
              <div className="flex items-center gap-3">
                <div className="w-9 h-9 rounded-full bg-gray-100" />
                <div className="space-y-1.5 flex-1">
                  <div className="h-4 bg-gray-100 rounded w-3/4" />
                  <div className="h-3 bg-gray-100 rounded w-1/2" />
                </div>
              </div>
            </div>
          ))}
        </div>
      ) : items.length === 0 ? (
        <div className="bg-white rounded-xl border border-border p-12 text-center shadow-sm">
          <Users size={32} className="mx-auto text-gray-200 mb-3" />
          <p className="text-sm text-gray-400 font-sans">No hay técnicos registrados.</p>
          <button onClick={() => setShowCreate(true)} className="mt-3 text-sm text-primary font-semibold font-sans hover:underline">
            Crear el primero
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">
          {items.map((tech) => (
            <div key={tech.id} className="bg-white rounded-xl border border-border p-5 shadow-sm hover:shadow-md transition-shadow group">
              {/* Identity row */}
              <div className="flex items-center gap-3 mb-4">
                <InitialAvatar name={tech.name} />
                <div className="min-w-0 flex-1">
                  <p className="font-semibold text-[#1A1A2E] font-sans truncate">{tech.name}</p>
                  <p className="text-xs text-gray-400 font-sans truncate">{tech.email}</p>
                </div>
                {tech.code && (
                  <span className="font-mono text-xs text-primary font-semibold bg-primary/10 px-2 py-0.5 rounded shrink-0">
                    {tech.code}
                  </span>
                )}
              </div>

              <div className="border-t border-gray-50 my-3" />

              {/* Metrics */}
              <div className="flex items-center gap-4 text-sm">
                <div className="flex items-center gap-1.5 text-gray-600 font-sans">
                  <FileText size={14} className="text-primary shrink-0" />
                  <span className="font-semibold text-[#1A1A2E]">{tech.reports_count}</span>
                  <span className="text-gray-400 text-xs">reportes</span>
                </div>
                {tech.last_sync_at && (
                  <div className="flex items-center gap-1.5 text-gray-500 font-sans ml-auto">
                    <Clock size={13} className="text-gray-400 shrink-0" />
                    <span className="text-xs" title={fmtDatetime(tech.last_sync_at)}>{relativeTime(tech.last_sync_at)}</span>
                  </div>
                )}
              </div>

              <div className="mt-3 flex items-center justify-between">
                <span className="inline-flex items-center px-2 py-0.5 rounded-full border text-xs font-medium font-sans bg-slate-50 text-slate-600 border-slate-200 capitalize">
                  {tech.role}
                </span>
                {/* Action buttons */}
                <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                  <button
                    onClick={() => setEditTech(tech)}
                    className="p-1.5 rounded-lg text-gray-400 hover:text-primary hover:bg-primary/10 transition-colors"
                    title="Editar"
                  >
                    <Pencil size={14} />
                  </button>
                  <button
                    onClick={() => setDeleteTech(tech)}
                    className="p-1.5 rounded-lg text-gray-400 hover:text-red-500 hover:bg-red-50 transition-colors"
                    title="Desactivar"
                  >
                    <Trash2 size={14} />
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {showCreate && <TechModal onClose={() => setShowCreate(false)} />}
      {editTech && <TechModal tech={editTech} onClose={() => setEditTech(null)} />}
      {deleteTech && <DeleteTechModal tech={deleteTech} onClose={() => setDeleteTech(null)} />}
    </div>
  )
}
