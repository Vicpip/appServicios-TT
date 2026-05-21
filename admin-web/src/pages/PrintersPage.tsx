import { useState, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  Printer, ChevronLeft, ChevronRight, Plus, Pencil, Trash2, X,
  AlertTriangle, Search, RotateCcw, Download, Upload, Loader2,
  CheckCircle, AlertCircle,
} from 'lucide-react'
import apiClient from '@/api/client'
import { API } from '@/api/endpoints'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface PrinterListItem {
  id: string
  code: string | null
  serial_number: string
  client_name: string | null
  plant_name: string | null
  area_name: string | null
  model_brand: string | null
  model_name: string | null
  model_dpi: number | null
  last_service_date: string | null
  printer_status: string
}

interface SelectOption { id: string; name: string }
interface PlantOption { id: string; name: string; client_id: string }
interface AreaOption { id: string; name: string; plant_id: string }
interface ModelOption { id: string; brand: string; model_name: string; dpi: number }

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const PAGE_SIZE = 20

function fmtDate(iso: string) {
  return new Date(iso).toLocaleDateString('es-MX', {
    day: '2-digit', month: 'short', year: 'numeric',
  })
}

const STATUS_STYLES: Record<string, { label: string; classes: string; dot: string }> = {
  'Correcto':       { label: 'Correcto',      classes: 'bg-green-50 text-green-700 border-green-200',  dot: 'bg-green-500' },
  'En Atención':    { label: 'En Atención',   classes: 'bg-red-50 text-red-600 border-red-200',        dot: 'bg-red-500' },
  'Sin Historial':  { label: 'Sin Historial', classes: 'bg-gray-100 text-gray-500 border-gray-200',    dot: 'bg-gray-400' },
}

function StatusChip({ status }: { status: string }) {
  const cfg = STATUS_STYLES[status] ?? { label: status, classes: 'bg-gray-100 text-gray-500 border-gray-200', dot: 'bg-gray-400' }
  return (
    <span className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full border text-xs font-medium font-sans ${cfg.classes}`}>
      <span className={`w-1.5 h-1.5 rounded-full shrink-0 ${cfg.dot}`} />
      {cfg.label}
    </span>
  )
}

const STATUS_OPTIONS = ['Correcto', 'En Atención', 'Sin Historial']

// ---------------------------------------------------------------------------
// New model mini-modal
// ---------------------------------------------------------------------------

interface NewModelModalProps {
  onClose: () => void
  onCreated: (model: ModelOption) => void
}

function NewModelModal({ onClose, onCreated }: NewModelModalProps) {
  const [brand, setBrand] = useState('')
  const [modelName, setModelName] = useState('')
  const [dpi, setDpi] = useState('203')
  const [error, setError] = useState<string | null>(null)

  const createMutation = useMutation({
    mutationFn: async () => {
      const res = await apiClient.post<ModelOption>(API.catalog.createModel, {
        brand: brand.trim(),
        model_name: modelName.trim(),
        dpi: parseInt(dpi, 10),
      })
      return res.data
    },
    onSuccess: (model) => {
      onCreated(model)
      onClose()
    },
    onError: (err: unknown) => {
      const msg = (err as { response?: { data?: { detail?: string } } })?.response?.data?.detail
      setError(msg ?? 'Error al crear el modelo.')
    },
  })

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError(null)
    if (!brand.trim() || !modelName.trim()) { setError('Marca y nombre son obligatorios.'); return }
    if (!dpi || parseInt(dpi, 10) < 1) { setError('DPI debe ser mayor a 0.'); return }
    createMutation.mutate()
  }

  const inputCls = 'w-full text-sm font-sans border border-border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition-colors'

  return (
    <>
      <div className="fixed inset-0 bg-black/50 z-[60]" onClick={onClose} />
      <div className="fixed inset-0 z-[70] flex items-center justify-center p-4">
        <div className="bg-white rounded-xl shadow-2xl w-full max-w-sm">
          <div className="flex items-center justify-between px-5 py-4 border-b border-border">
            <h4 className="font-semibold text-[#1A1A2E] font-heading text-sm">Nuevo modelo</h4>
            <button onClick={onClose} className="p-1 rounded-lg text-gray-400 hover:text-gray-700 hover:bg-gray-100 transition-colors">
              <X size={16} />
            </button>
          </div>
          <form onSubmit={handleSubmit}>
            <div className="px-5 py-4 space-y-3">
              <div>
                <label className="block text-xs font-semibold text-gray-500 font-sans mb-1">Marca *</label>
                <input type="text" value={brand} onChange={(e) => setBrand(e.target.value)} className={inputCls} placeholder="Zebra, Honeywell…" />
              </div>
              <div>
                <label className="block text-xs font-semibold text-gray-500 font-sans mb-1">Nombre del modelo *</label>
                <input type="text" value={modelName} onChange={(e) => setModelName(e.target.value)} className={inputCls} placeholder="ZT411, PC43d…" />
              </div>
              <div>
                <label className="block text-xs font-semibold text-gray-500 font-sans mb-1">DPI</label>
                <input type="number" value={dpi} onChange={(e) => setDpi(e.target.value)} className={inputCls} placeholder="203" min="1" />
              </div>
              {error && (
                <div className="flex items-center gap-2 bg-red-50 border border-red-200 rounded-lg px-3 py-2">
                  <AlertTriangle size={13} className="text-red-500 shrink-0" />
                  <p className="text-xs text-red-600 font-sans">{error}</p>
                </div>
              )}
            </div>
            <div className="px-5 py-3 border-t border-border bg-gray-50 flex gap-2 justify-end">
              <button type="button" onClick={onClose} className="px-3 py-1.5 text-sm font-semibold text-gray-600 font-sans rounded-lg hover:bg-gray-100 transition-colors">Cancelar</button>
              <button type="submit" disabled={createMutation.isPending} className="px-4 py-1.5 text-sm font-semibold text-white bg-primary hover:bg-primary-dark disabled:opacity-50 rounded-lg transition-colors font-sans">
                {createMutation.isPending ? 'Creando…' : 'Crear'}
              </button>
            </div>
          </form>
        </div>
      </div>
    </>
  )
}

// ---------------------------------------------------------------------------
// BulkUploadModal
// ---------------------------------------------------------------------------

interface BulkError { fila: number; serie: string; error: string }
interface BulkResult { total: number; exitosas: number; errores: BulkError[] }

function BulkUploadModal({ onClose, onDone }: { onClose: () => void; onDone: () => void }) {
  const [dragging, setDragging] = useState(false)
  const [file, setFile] = useState<File | null>(null)
  const [fileError, setFileError] = useState<string | null>(null)
  const [uploading, setUploading] = useState(false)
  const [result, setResult] = useState<BulkResult | null>(null)
  const [uploadError, setUploadError] = useState<string | null>(null)
  const inputRef = useRef<HTMLInputElement>(null)

  function validateFile(f: File): string | null {
    const ext = f.name.split('.').pop()?.toLowerCase()
    if (!['xlsx', 'csv'].includes(ext ?? '')) return 'Solo se aceptan archivos .xlsx o .csv'
    if (f.size > 5 * 1024 * 1024) return 'El archivo no puede superar 5 MB'
    return null
  }

  function handleFileSelect(f: File) {
    const err = validateFile(f)
    if (err) { setFileError(err); setFile(null); return }
    setFile(f)
    setFileError(null)
    setResult(null)
    setUploadError(null)
  }

  function handleDrop(e: React.DragEvent) {
    e.preventDefault()
    setDragging(false)
    const f = e.dataTransfer.files[0]
    if (f) handleFileSelect(f)
  }

  async function handleUpload() {
    if (!file) return
    setUploading(true)
    setUploadError(null)
    try {
      const fd = new FormData()
      fd.append('file', file)
      const res = await apiClient.post<BulkResult>(API.printers.bulkUpload, fd, {
        headers: { 'Content-Type': 'multipart/form-data' },
      })
      setResult(res.data)
    } catch (err: unknown) {
      const msg = (err as { response?: { data?: { detail?: string } } })?.response?.data?.detail
      setUploadError(msg ?? 'Error al procesar el archivo')
    } finally {
      setUploading(false)
    }
  }

  return (
    <>
      <div className="fixed inset-0 bg-black/40 z-40" onClick={onClose} />
      <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div className="bg-white rounded-xl shadow-2xl w-full max-w-lg flex flex-col max-h-[90vh]">
          {/* Header */}
          <div className="flex items-center justify-between px-6 py-4 border-b border-border shrink-0">
            <div className="flex items-center gap-2">
              <Upload size={16} className="text-primary" />
              <h3 className="font-semibold text-[#1A1A2E] font-heading">Carga masiva de impresoras</h3>
            </div>
            <button onClick={onClose} className="p-1.5 rounded-lg text-gray-400 hover:text-gray-700 hover:bg-gray-100 transition-colors">
              <X size={18} />
            </button>
          </div>

          <div className="flex-1 overflow-y-auto px-6 py-5 space-y-4">
            {!result ? (
              <>
                {/* Dropzone */}
                <div
                  onDragOver={(e) => { e.preventDefault(); setDragging(true) }}
                  onDragLeave={() => setDragging(false)}
                  onDrop={handleDrop}
                  onClick={() => inputRef.current?.click()}
                  className={`border-2 border-dashed rounded-xl p-8 text-center cursor-pointer transition-colors ${
                    dragging ? 'border-primary bg-primary/5' : 'border-gray-200 hover:border-primary/50 hover:bg-gray-50'
                  }`}
                >
                  <Upload size={28} className="mx-auto mb-2 text-gray-300" />
                  {file ? (
                    <p className="text-sm font-medium text-gray-700 font-sans">{file.name}</p>
                  ) : (
                    <>
                      <p className="text-sm font-medium text-gray-600 font-sans">Arrastra tu archivo aquí</p>
                      <p className="text-xs text-gray-400 font-sans mt-1">o haz clic para seleccionar · .xlsx o .csv · máx 5 MB</p>
                    </>
                  )}
                  <input
                    ref={inputRef}
                    type="file"
                    accept=".xlsx,.csv"
                    className="hidden"
                    onChange={(e) => { const f = e.target.files?.[0]; if (f) handleFileSelect(f) }}
                  />
                </div>

                {fileError && (
                  <div className="flex items-center gap-2 bg-red-50 border border-red-200 rounded-lg px-3 py-2.5">
                    <AlertCircle size={14} className="text-red-500 shrink-0" />
                    <p className="text-sm text-red-600 font-sans">{fileError}</p>
                  </div>
                )}

                {uploadError && (
                  <div className="flex items-center gap-2 bg-red-50 border border-red-200 rounded-lg px-3 py-2.5">
                    <AlertCircle size={14} className="text-red-500 shrink-0" />
                    <p className="text-sm text-red-600 font-sans">{uploadError}</p>
                  </div>
                )}

                <p className="text-xs text-gray-400 font-sans">
                  Descarga la plantilla Excel para ver el formato correcto con instrucciones y catálogos actualizados.
                </p>
              </>
            ) : (
              /* Result */
              <div className="space-y-4">
                <div className={`flex items-center gap-3 p-4 rounded-xl ${result.errores.length === 0 ? 'bg-green-50 border border-green-200' : 'bg-amber-50 border border-amber-200'}`}>
                  {result.errores.length === 0 ? (
                    <CheckCircle size={20} className="text-green-600 shrink-0" />
                  ) : (
                    <AlertCircle size={20} className="text-amber-600 shrink-0" />
                  )}
                  <div>
                    <p className="font-semibold text-gray-800 font-sans text-sm">
                      {result.exitosas} de {result.total} impresoras creadas
                    </p>
                    {result.errores.length > 0 && (
                      <p className="text-xs text-amber-700 font-sans">{result.errores.length} fila{result.errores.length !== 1 ? 's' : ''} con error</p>
                    )}
                  </div>
                </div>

                {result.errores.length > 0 && (
                  <div className="space-y-1.5 max-h-52 overflow-y-auto">
                    <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide font-sans">Errores por fila</p>
                    {result.errores.map((e) => (
                      <div key={e.fila} className="flex items-start gap-2 bg-red-50 border border-red-100 rounded-lg px-3 py-2">
                        <span className="text-xs font-mono text-red-500 shrink-0">F{e.fila}</span>
                        <span className="text-xs text-red-700 font-sans"><span className="font-medium">{e.serie}</span> — {e.error}</span>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>

          {/* Footer */}
          <div className="px-6 py-4 border-t border-border bg-gray-50 flex gap-2 justify-end shrink-0">
            {!result ? (
              <>
                <button type="button" onClick={onClose} className="px-4 py-2 text-sm font-semibold text-gray-600 font-sans rounded-lg hover:bg-gray-100 transition-colors">
                  Cancelar
                </button>
                <button
                  onClick={handleUpload}
                  disabled={!file || uploading}
                  className="flex items-center gap-2 px-5 py-2 text-sm font-semibold text-white bg-primary hover:bg-primary-dark disabled:opacity-50 rounded-lg transition-colors font-sans"
                >
                  {uploading ? <Loader2 size={14} className="animate-spin" /> : <Upload size={14} />}
                  {uploading ? 'Procesando…' : 'Cargar'}
                </button>
              </>
            ) : (
              <button
                onClick={() => { onDone(); onClose() }}
                className="px-5 py-2 text-sm font-semibold text-white bg-primary hover:bg-primary-dark rounded-lg transition-colors font-sans"
              >
                Cerrar y actualizar
              </button>
            )}
          </div>
        </div>
      </div>
    </>
  )
}

// ---------------------------------------------------------------------------
// Printer modal (create / edit)
// ---------------------------------------------------------------------------

interface PrinterFormData {
  serial_number: string
  qr_uuid: string
  client_id: string
  plant_id: string
  area_id: string
  model_id: string
}

const EMPTY_PRINTER_FORM: PrinterFormData = {
  serial_number: '', qr_uuid: '', client_id: '', plant_id: '', area_id: '', model_id: '',
}

interface PrinterModalProps {
  printer?: PrinterListItem | null
  onClose: () => void
}

function PrinterModal({ printer, onClose }: PrinterModalProps) {
  const qc = useQueryClient()
  const isEdit = !!printer

  const [form, setForm] = useState<PrinterFormData>(
    isEdit
      ? { serial_number: printer!.serial_number, qr_uuid: '', client_id: '', plant_id: '', area_id: '', model_id: '' }
      : EMPTY_PRINTER_FORM,
  )
  const [error, setError] = useState<string | null>(null)
  const [newPlantName, setNewPlantName] = useState('')
  const [newPlantContactName, setNewPlantContactName] = useState('')
  const [newPlantContactPhone, setNewPlantContactPhone] = useState('')
  const [newAreaName, setNewAreaName] = useState('')
  const [showNewPlant, setShowNewPlant] = useState(false)
  const [showNewArea, setShowNewArea] = useState(false)
  const [showNewModel, setShowNewModel] = useState(false)

  const { data: clientsData } = useQuery({
    queryKey: ['filter-clients'],
    queryFn: async () => {
      const res = await apiClient.get<{ items: SelectOption[] }>(API.clients.list, { params: { limit: 200 } })
      return res.data.items
    },
    staleTime: 60_000,
  })

  const { data: plantsData, refetch: refetchPlants } = useQuery({
    queryKey: ['plants', form.client_id],
    queryFn: async () => {
      const res = await apiClient.get<{ items: PlantOption[] }>(API.plants.list, { params: { client_id: form.client_id } })
      return res.data.items
    },
    enabled: !!form.client_id,
    staleTime: 30_000,
  })

  const { data: areasData, refetch: refetchAreas } = useQuery({
    queryKey: ['areas', form.plant_id],
    queryFn: async () => {
      const res = await apiClient.get<{ items: AreaOption[] }>(API.areas.list, { params: { plant_id: form.plant_id } })
      return res.data.items
    },
    enabled: !!form.plant_id,
    staleTime: 30_000,
  })

  const { data: modelsData, refetch: refetchModels } = useQuery({
    queryKey: ['catalog-models'],
    queryFn: async () => {
      const res = await apiClient.get<{ items: ModelOption[] }>(API.catalog.models)
      return res.data.items
    },
    staleTime: 300_000,
  })

  const createPlantMutation = useMutation({
    mutationFn: async () => {
      const res = await apiClient.post<PlantOption>(API.plants.create, {
        client_id: form.client_id,
        name: newPlantName.trim(),
        contact_name: newPlantContactName.trim(),
        contact_phone: newPlantContactPhone.trim(),
      })
      return res.data
    },
    onSuccess: (plant) => {
      refetchPlants()
      setForm((p) => ({ ...p, plant_id: plant.id, area_id: '' }))
      setNewPlantName('')
      setNewPlantContactName('')
      setNewPlantContactPhone('')
      setShowNewPlant(false)
    },
  })

  const createAreaMutation = useMutation({
    mutationFn: async () => {
      const res = await apiClient.post<AreaOption>(API.areas.create, { plant_id: form.plant_id, name: newAreaName })
      return res.data
    },
    onSuccess: (area) => {
      refetchAreas()
      setForm((p) => ({ ...p, area_id: area.id }))
      setNewAreaName('')
      setShowNewArea(false)
    },
  })

  const saveMutation = useMutation({
    mutationFn: async () => {
      if (isEdit) {
        const payload: Record<string, string> = {}
        if (form.serial_number !== printer!.serial_number) payload.serial_number = form.serial_number
        if (form.client_id) payload.client_id = form.client_id
        if (form.plant_id) payload.plant_id = form.plant_id
        if (form.area_id) payload.area_id = form.area_id
        if (form.model_id) payload.model_id = form.model_id
        await apiClient.put(API.printers.detail(printer!.id), payload)
      } else {
        await apiClient.post(API.printers.create, {
          serial_number: form.serial_number,
          qr_uuid: form.qr_uuid || undefined,
          client_id: form.client_id,
          plant_id: form.plant_id,
          area_id: form.area_id,
          model_id: form.model_id,
        })
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['printers'] })
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
    if (!form.serial_number.trim()) { setError('El número de serie es obligatorio.'); return }
    if (!isEdit && (!form.client_id || !form.plant_id || !form.area_id || !form.model_id)) {
      setError('Completa todos los campos: modelo, cliente, planta y área.')
      return
    }
    saveMutation.mutate()
  }

  const inputCls = 'w-full text-sm font-sans border border-border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition-colors'
  const labelCls = 'block text-xs font-semibold text-gray-500 font-sans mb-1'

  return (
    <>
      <div className="fixed inset-0 bg-black/40 z-40" onClick={onClose} />
      <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div className="bg-white rounded-xl shadow-2xl w-full max-w-lg max-h-[90vh] flex flex-col">
          <div className="flex items-center justify-between px-6 py-4 border-b border-border shrink-0">
            <div className="flex items-center gap-2">
              <Printer size={16} className="text-primary" />
              <h3 className="font-semibold text-[#1A1A2E] font-heading">
                {isEdit ? 'Editar impresora' : 'Nueva impresora'}
              </h3>
            </div>
            <button onClick={onClose} className="p-1.5 rounded-lg text-gray-400 hover:text-gray-700 hover:bg-gray-100 transition-colors">
              <X size={18} />
            </button>
          </div>

          <form onSubmit={handleSubmit} className="flex-1 overflow-y-auto">
            <div className="px-6 py-5 space-y-4">
              {/* Serial + QR */}
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className={labelCls}>Número de serie *</label>
                  <input type="text" value={form.serial_number} onChange={(e) => setForm((p) => ({ ...p, serial_number: e.target.value }))} className={inputCls} placeholder="ZBR-12345" />
                </div>
                {!isEdit && (
                  <div>
                    <label className={labelCls}>QR UUID <span className="text-gray-400 font-normal">(auto si vacío)</span></label>
                    <input type="text" value={form.qr_uuid} onChange={(e) => setForm((p) => ({ ...p, qr_uuid: e.target.value }))} className={inputCls} placeholder="auto" />
                  </div>
                )}
              </div>

              {/* Model selector with "+" button */}
              <div>
                <div className="flex items-center justify-between mb-1">
                  <label className={`${labelCls} mb-0`}>Modelo de impresora{!isEdit && ' *'}</label>
                  <button
                    type="button"
                    onClick={() => setShowNewModel(true)}
                    className="flex items-center gap-1 text-xs text-primary hover:underline font-sans"
                  >
                    <Plus size={11} />
                    Nuevo modelo
                  </button>
                </div>
                <select value={form.model_id} onChange={(e) => setForm((p) => ({ ...p, model_id: e.target.value }))} className={inputCls}>
                  <option value="">Seleccionar modelo…</option>
                  {modelsData?.map((m) => (
                    <option key={m.id} value={m.id}>{m.brand} — {m.model_name} · {m.dpi} dpi</option>
                  ))}
                </select>
                {form.model_id && (() => {
                  const m = modelsData?.find((x) => x.id === form.model_id)
                  return m ? (
                    <p className="mt-1 text-xs text-gray-400 font-sans">
                      {m.brand} — {m.model_name} · {m.dpi} dpi
                    </p>
                  ) : null
                })()}
              </div>

              {/* Chained: Client → Plant → Area */}
              <div>
                <label className={labelCls}>Cliente{!isEdit && ' *'}</label>
                <select
                  value={form.client_id}
                  onChange={(e) => setForm((p) => ({ ...p, client_id: e.target.value, plant_id: '', area_id: '' }))}
                  className={inputCls}
                >
                  <option value="">Seleccionar cliente…</option>
                  {clientsData?.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
                </select>
              </div>

              {form.client_id && (
                <div>
                  <div className="flex items-center justify-between mb-1">
                    <label className={`${labelCls} mb-0`}>Planta{!isEdit && ' *'}</label>
                    <button type="button" onClick={() => setShowNewPlant((v) => !v)} className="text-xs text-primary hover:underline font-sans">
                      {showNewPlant ? 'Cancelar' : '+ Nueva planta'}
                    </button>
                  </div>
                  {showNewPlant ? (
                    <div className="space-y-2">
                      <input type="text" value={newPlantName} onChange={(e) => setNewPlantName(e.target.value)} className={inputCls} placeholder="Nombre de la planta *" />
                      <input type="text" value={newPlantContactName} onChange={(e) => setNewPlantContactName(e.target.value)} className={inputCls} placeholder="Nombre de contacto *" />
                      <input type="text" value={newPlantContactPhone} onChange={(e) => setNewPlantContactPhone(e.target.value)} className={inputCls} placeholder="Teléfono de contacto *" />
                      <button type="button" onClick={() => {
                        if (!newPlantName.trim() || !newPlantContactName.trim() || !newPlantContactPhone.trim()) {
                          alert('Nombre, contacto y teléfono son requeridos')
                          return
                        }
                        createPlantMutation.mutate()
                      }} disabled={createPlantMutation.isPending} className="w-full px-3 py-2 text-sm font-semibold text-white bg-primary hover:bg-primary-dark disabled:opacity-50 rounded-lg transition-colors font-sans">
                        {createPlantMutation.isPending ? '…' : 'Crear planta'}
                      </button>
                    </div>
                  ) : (
                    <select value={form.plant_id} onChange={(e) => setForm((p) => ({ ...p, plant_id: e.target.value, area_id: '' }))} className={inputCls}>
                      <option value="">Seleccionar planta…</option>
                      {plantsData?.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
                    </select>
                  )}
                </div>
              )}

              {form.plant_id && (
                <div>
                  <div className="flex items-center justify-between mb-1">
                    <label className={`${labelCls} mb-0`}>Área{!isEdit && ' *'}</label>
                    <button type="button" onClick={() => setShowNewArea((v) => !v)} className="text-xs text-primary hover:underline font-sans">
                      {showNewArea ? 'Cancelar' : '+ Nueva área'}
                    </button>
                  </div>
                  {showNewArea ? (
                    <div className="flex gap-2">
                      <input type="text" value={newAreaName} onChange={(e) => setNewAreaName(e.target.value)} className={inputCls} placeholder="Nombre del área" />
                      <button type="button" onClick={() => createAreaMutation.mutate()} disabled={!newAreaName.trim() || createAreaMutation.isPending} className="shrink-0 px-3 py-2 text-sm font-semibold text-white bg-primary hover:bg-primary-dark disabled:opacity-50 rounded-lg transition-colors font-sans">
                        {createAreaMutation.isPending ? '…' : 'Crear'}
                      </button>
                    </div>
                  ) : (
                    <select value={form.area_id} onChange={(e) => setForm((p) => ({ ...p, area_id: e.target.value }))} className={inputCls}>
                      <option value="">Seleccionar área…</option>
                      {areasData?.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}
                    </select>
                  )}
                </div>
              )}

              {error && (
                <div className="flex items-center gap-2 bg-red-50 border border-red-200 rounded-lg px-3 py-2.5">
                  <AlertTriangle size={14} className="text-red-500 shrink-0" />
                  <p className="text-sm text-red-600 font-sans">{error}</p>
                </div>
              )}
            </div>

            <div className="px-6 py-4 border-t border-border bg-gray-50 flex gap-2 justify-end shrink-0">
              <button type="button" onClick={onClose} className="px-4 py-2 text-sm font-semibold text-gray-600 font-sans rounded-lg hover:bg-gray-100 transition-colors">Cancelar</button>
              <button type="submit" disabled={saveMutation.isPending} className="px-5 py-2 text-sm font-semibold text-white bg-primary hover:bg-primary-dark disabled:opacity-50 rounded-lg transition-colors font-sans">
                {saveMutation.isPending ? 'Guardando…' : isEdit ? 'Guardar cambios' : 'Crear impresora'}
              </button>
            </div>
          </form>
        </div>
      </div>

      {/* New model mini-modal — stacked above printer modal */}
      {showNewModel && (
        <NewModelModal
          onClose={() => setShowNewModel(false)}
          onCreated={(model) => {
            refetchModels()
            setForm((p) => ({ ...p, model_id: model.id }))
          }}
        />
      )}
    </>
  )
}

// ---------------------------------------------------------------------------
// Delete confirm
// ---------------------------------------------------------------------------

function DeletePrinterModal({ printer, onClose }: { printer: PrinterListItem; onClose: () => void }) {
  const qc = useQueryClient()
  const deleteMutation = useMutation({
    mutationFn: async () => apiClient.delete(API.printers.detail(printer.id)),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['printers'] }); onClose() },
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
              <h3 className="font-semibold text-[#1A1A2E] font-heading">Desactivar impresora</h3>
              <p className="text-sm text-gray-400 font-sans">La impresora quedará inactiva.</p>
            </div>
          </div>
          <p className="text-sm text-gray-600 font-sans mb-5">
            ¿Desactivar la impresora <span className="font-mono font-semibold">{printer.serial_number}</span>?
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

export default function PrintersPage() {
  const navigate = useNavigate()
  const qc = useQueryClient()
  const [search, setSearch] = useState('')
  const [debouncedSearch, setDebouncedSearch] = useState('')
  const [clientFilter, setClientFilter] = useState('')
  const [statusFilter, setStatusFilter] = useState('')
  const [page, setPage] = useState(0)
  const [showCreate, setShowCreate] = useState(false)
  const [editPrinter, setEditPrinter] = useState<PrinterListItem | null>(null)
  const [deletePrinter, setDeletePrinter] = useState<PrinterListItem | null>(null)
  const [showBulkUpload, setShowBulkUpload] = useState(false)
  const [debounceTimer, setDebounceTimer] = useState<ReturnType<typeof setTimeout> | null>(null)

  function handleSearch(value: string) {
    setSearch(value)
    if (debounceTimer) clearTimeout(debounceTimer)
    const t = setTimeout(() => { setDebouncedSearch(value); setPage(0) }, 350)
    setDebounceTimer(t)
  }

  const { data: clientsData } = useQuery({
    queryKey: ['filter-clients'],
    queryFn: async () => {
      const res = await apiClient.get<{ items: SelectOption[] }>(API.clients.list, { params: { limit: 200 } })
      return res.data.items
    },
    staleTime: 60_000,
  })

  const queryParams = {
    limit: PAGE_SIZE,
    offset: page * PAGE_SIZE,
    ...(clientFilter && { client_id: clientFilter }),
    ...(statusFilter && { printer_status: statusFilter }),
    ...(debouncedSearch && { search: debouncedSearch }),
  }

  const { data, isLoading, isFetching } = useQuery({
    queryKey: ['printers', queryParams],
    queryFn: async () => {
      const res = await apiClient.get<{ total: number; items: PrinterListItem[] }>(API.printers.list, { params: queryParams })
      return res.data
    },
    placeholderData: (prev) => prev,
    retry: false,
  })

  const total = data?.total ?? 0
  const items = data?.items ?? []
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE))
  const hasFilters = clientFilter || statusFilter || debouncedSearch

  function resetFilters() {
    setSearch('')
    setDebouncedSearch('')
    setClientFilter('')
    setStatusFilter('')
    setPage(0)
  }

  const selectCls = 'text-sm font-sans border border-border rounded-lg px-3 py-2 bg-white text-gray-700 focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition-colors'

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h2 className="text-xl font-bold text-[#1A1A2E] font-heading">Impresoras</h2>
          <p className="text-sm text-gray-400 font-sans mt-0.5">
            {isFetching ? 'Actualizando…' : `${items.length} impresora${items.length !== 1 ? 's' : ''} mostrada${items.length !== 1 ? 's' : ''}`}
          </p>
        </div>
        <div className="flex items-center gap-2 flex-wrap">
          <a
            href={`${(import.meta.env.VITE_API_URL as string ?? '').replace(/\/$/, '')}${API.printers.downloadTemplate}`}
            download="plantilla_impresoras.xlsx"
            className="flex items-center gap-2 border border-border text-gray-600 hover:text-primary hover:border-primary text-sm font-semibold font-sans rounded-lg px-4 py-2 transition-colors"
          >
            <Download size={15} />
            Plantilla
          </a>
          <button
            onClick={() => setShowBulkUpload(true)}
            className="flex items-center gap-2 border border-border text-gray-600 hover:text-primary hover:border-primary text-sm font-semibold font-sans rounded-lg px-4 py-2 transition-colors"
          >
            <Upload size={15} />
            Carga masiva
          </button>
          <button
            onClick={() => setShowCreate(true)}
            className="flex items-center gap-2 bg-primary hover:bg-primary-dark text-white text-sm font-semibold font-sans rounded-lg px-4 py-2 transition-colors"
          >
            <Plus size={15} />
            Nueva impresora
          </button>
        </div>
      </div>

      {/* Status quick-filter chips */}
      <div className="flex flex-wrap gap-2">
        {STATUS_OPTIONS.map((s) => (
          <button
            key={s}
            onClick={() => { setStatusFilter(statusFilter === s ? '' : s); setPage(0) }}
            className={`transition-all ${statusFilter === s ? 'ring-2 ring-primary/40 ring-offset-1' : 'opacity-70 hover:opacity-100'}`}
          >
            <StatusChip status={s} />
          </button>
        ))}
        {hasFilters && (
          <button onClick={resetFilters} className="text-xs text-gray-400 hover:text-primary font-sans ml-1 transition-colors">
            Limpiar todo
          </button>
        )}
      </div>

      {/* Search + dropdowns */}
      <div className="bg-white rounded-xl border border-border p-4 shadow-sm">
        <div className="flex flex-wrap gap-3">
          {/* Search */}
          <div className="relative w-full sm:w-64">
            <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
            <input
              type="text"
              value={search}
              onChange={(e) => handleSearch(e.target.value)}
              placeholder="Serie, código, modelo…"
              className="w-full pl-8 pr-8 py-2 text-sm font-sans border border-border rounded-lg bg-white text-gray-700 focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition-colors"
            />
            {search && (
              <button onClick={resetFilters} className="absolute right-2.5 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
                <RotateCcw size={13} />
              </button>
            )}
          </div>

          <select value={clientFilter} onChange={(e) => { setClientFilter(e.target.value); setPage(0) }} className={selectCls}>
            <option value="">Todos los clientes</option>
            {clientsData?.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>

          <select value={statusFilter} onChange={(e) => { setStatusFilter(e.target.value); setPage(0) }} className={selectCls}>
            <option value="">Todos los estados</option>
            {STATUS_OPTIONS.map((s) => <option key={s} value={s}>{s}</option>)}
          </select>
        </div>
      </div>

      {/* Table */}
      <div className="bg-white rounded-xl border border-border shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-gray-50 border-b border-border text-left">
                {['Código / Serie', 'Modelo', 'Cliente', 'Planta / Área', 'Último servicio', 'Estado', ''].map((h) => (
                  <th key={h} className="px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide font-sans whitespace-nowrap">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {isLoading ? (
                Array.from({ length: 8 }).map((_, i) => (
                  <tr key={i} className="animate-pulse">
                    {Array.from({ length: 7 }).map((_, j) => (
                      <td key={j} className="px-4 py-3.5">
                        <div className="h-4 bg-gray-100 rounded" style={{ width: `${50 + ((i + j) % 3) * 20}%` }} />
                      </td>
                    ))}
                  </tr>
                ))
              ) : items.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-4 py-12 text-center text-sm text-gray-400 font-sans">
                    <Printer size={28} className="mx-auto mb-2 text-gray-200" />
                    {debouncedSearch
                      ? `Sin resultados para "${debouncedSearch}".`
                      : 'No se encontraron impresoras con los filtros aplicados.'}
                  </td>
                </tr>
              ) : (
                items.map((row) => (
                  <tr key={row.id} className="hover:bg-gray-50/60 transition-colors group cursor-pointer" onClick={() => navigate(`/printers/${row.id}`)}>
                    <td className="px-4 py-3.5">
                      <div className="flex items-center gap-2">
                        <Printer size={14} className="text-gray-300 shrink-0" />
                        <div>
                          {row.code && <p className="font-mono text-xs text-primary font-semibold">{row.code}</p>}
                          <p className="font-mono text-xs text-gray-500">{row.serial_number}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3.5 text-gray-600 font-sans whitespace-nowrap">
                      {row.model_brand && row.model_name
                        ? <span>{row.model_brand} — <span className="font-medium">{row.model_name}</span>{row.model_dpi ? <span className="text-gray-400"> · {row.model_dpi} dpi</span> : null}</span>
                        : <span className="text-gray-400">—</span>}
                    </td>
                    <td className="px-4 py-3.5 text-gray-700 font-sans">{row.client_name ?? '—'}</td>
                    <td className="px-4 py-3.5 text-gray-500 font-sans">
                      {[row.plant_name, row.area_name].filter(Boolean).join(' / ') || '—'}
                    </td>
                    <td className="px-4 py-3.5 text-gray-500 font-sans whitespace-nowrap">
                      {row.last_service_date ? fmtDate(row.last_service_date) : '—'}
                    </td>
                    <td className="px-4 py-3.5"><StatusChip status={row.printer_status} /></td>
                    <td className="px-4 py-3.5">
                      <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                        <button onClick={(e) => { e.stopPropagation(); setEditPrinter(row) }} className="p-1.5 rounded-lg text-gray-400 hover:text-primary hover:bg-primary/10 transition-colors" title="Editar">
                          <Pencil size={14} />
                        </button>
                        <button onClick={(e) => { e.stopPropagation(); setDeletePrinter(row) }} className="p-1.5 rounded-lg text-gray-400 hover:text-red-500 hover:bg-red-50 transition-colors" title="Desactivar">
                          <Trash2 size={14} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        {total > PAGE_SIZE && (
          <div className="flex items-center justify-between px-4 py-3 border-t border-border bg-gray-50">
            <span className="text-xs text-gray-400 font-sans">
              Página {page + 1} de {totalPages} · {total} total
            </span>
            <div className="flex items-center gap-1">
              <button onClick={() => setPage((p) => Math.max(0, p - 1))} disabled={page === 0} className="p-1.5 rounded-lg text-gray-400 hover:text-primary hover:bg-primary/10 disabled:opacity-30 disabled:cursor-not-allowed transition-colors">
                <ChevronLeft size={16} />
              </button>
              {Array.from({ length: Math.min(totalPages, 5) }, (_, i) => {
                const pg = totalPages <= 5 ? i : Math.max(0, Math.min(page - 2, totalPages - 5)) + i
                return (
                  <button key={pg} onClick={() => setPage(pg)} className={`w-7 h-7 text-xs rounded-lg font-sans font-medium transition-colors ${pg === page ? 'bg-primary text-white' : 'text-gray-500 hover:bg-gray-100'}`}>
                    {pg + 1}
                  </button>
                )
              })}
              <button onClick={() => setPage((p) => Math.min(totalPages - 1, p + 1))} disabled={page >= totalPages - 1} className="p-1.5 rounded-lg text-gray-400 hover:text-primary hover:bg-primary/10 disabled:opacity-30 disabled:cursor-not-allowed transition-colors">
                <ChevronRight size={16} />
              </button>
            </div>
          </div>
        )}
      </div>

      {showCreate && <PrinterModal onClose={() => setShowCreate(false)} />}
      {editPrinter && <PrinterModal printer={editPrinter} onClose={() => setEditPrinter(null)} />}
      {deletePrinter && <DeletePrinterModal printer={deletePrinter} onClose={() => setDeletePrinter(null)} />}
      {showBulkUpload && (
        <BulkUploadModal
          onClose={() => setShowBulkUpload(false)}
          onDone={() => { qc.invalidateQueries({ queryKey: ['printers'] }) }}
        />
      )}
    </div>
  )
}
