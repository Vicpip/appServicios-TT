# Sprint 2 — Plan de Implementación
> **Proyecto:** industrial_service_reports — Backend + Admin Web + Flutter Sync
> **Worktree:** `C:\Users\Victor\Documents\app\.claude\worktrees\eloquent-tesla`
> **Fecha:** 2026-03-16

---

## Contexto

Sprint 1 entregó la app Flutter completa (offline-first). Sprint 2 conecta esa app al mundo: un servidor FastAPI ya tiene los endpoints de sincronización básicos (`POST /api/reports`, `POST /api/files`), pero aún falta: verificar que funcionen, construir los endpoints de administración, crear el panel web React, conectar la app Flutter, y gestionar pólizas desde el admin.

**Estado actual del servidor:**
- ✅ `POST /api/reports` — upsert de reporte (implementado, sin probar con datos reales)
- ✅ `POST /api/reports/bulk` — upsert masivo
- ✅ `POST /api/files` — subida de fotos/firmas con deduplicación SHA256
- ✅ `GET /api/health` — health check
- ❌ Sin endpoints admin
- ❌ Sin autenticación
- ❌ Sin panel web
- ❌ Flutter sync es un mock (delay de 3 segundos)

**Archivos clave del servidor:**
- `server/app/main.py` — punto de entrada FastAPI
- `server/app/api/routers/sync.py` — endpoints de sincronización existentes
- `server/app/models/` — 13 modelos SQLAlchemy (users, clients, plants, areas, printers, reports, policy, sync, etc.)
- `server/app/schemas/report.py` — ReportCreate / ReportRead
- `server/app/database.py` — SessionLocal, engine

**Archivos Flutter a tocar:**
- `lib/features/sync/sync_dashboard_screen.dart` — botón sync es mock
- `lib/features/sync/sync_history_screen.dart` — historial vacío

---

## Orden de tareas (por dependencias)

---

### FASE 1 — Verificar sincronización base (sin dependencias)

**Objetivo:** Confirmar que el servidor recibe reportes reales antes de construir encima.

#### Tarea 1.1 — Probar POST /api/reports con payload real
- Abrir Swagger en `http://localhost:8000/docs`
- Enviar un reporte con todos los campos: `id`, `printer_id`, `tech_id`, `service_type`, `status`, `service_date`, `technical_checkboxes`, `notes`, `photo_paths`
- Verificar que se inserta en PostgreSQL
- Corregir cualquier error de schema Pydantic o ORM

**Archivo:** `server/app/api/routers/sync.py`, `server/app/schemas/report.py`

#### Tarea 1.2 — Probar POST /api/files con archivo real
- Enviar imagen JPG vía multipart desde Swagger
- Verificar que guarda en `/var/smp/uploads/` y registra en tabla `files`
- Verificar deduplicación SHA256 (misma foto → mismo registro)

**Archivo:** `server/app/api/routers/sync.py`

#### Tarea 1.3 — Endpoint GET /api/sync/status (útil para app)
- Nuevo endpoint: retorna `{ pending_reports, synced_total, failed }`
- Consulta tabla `sync_log` agrupando por `status`

**Archivo:** `server/app/api/routers/sync.py` (agregar endpoint)

---

### FASE 2 — Endpoints Admin (depende de Fase 1 funcionando)

**Objetivo:** Crear `server/app/api/routers/admin.py` con todos los endpoints de consulta para el panel web.

#### Tarea 2.1 — Crear router admin y registrarlo
- Crear `server/app/api/routers/admin.py`
- Crear `server/app/schemas/admin.py` con schemas de respuesta
- Registrar router en `server/app/main.py` con prefix `/api/admin`

#### Tarea 2.2 — GET /api/admin/reports
```
Query params: client_id, tech_id, status, date_from, date_to
Paginado: offset, limit (default 20)
Retorna: [{ id, code, printer_serial, tech_name, service_date, service_type, status }]
```
- Join: reports → printers → users (technician)
- Ordenado por `service_date DESC`

#### Tarea 2.3 — GET /api/admin/reports/{report_id}
```
Retorna: reporte completo + nombre técnico + serial impresora +
         nombre cliente + URLs de fotos + firma
```
- Join: reports → printers → clients → users → entity_files → files

#### Tarea 2.4 — GET /api/admin/clients
```
Query params: search (name/rfc), policy_status
Retorna: [{ id, name, rfc, plant_count, printer_count, active_policy_count }]
```
- Subconsultas con COUNT agrupado

#### Tarea 2.5 — GET /api/admin/technicians
```
Retorna: [{ id, code, name, reports_count, last_sync_at }]
```

#### Tarea 2.6 — GET /api/admin/printers
```
Query params: client_id, status
Retorna: [{ id, code, serial, client_name, plant_name, area_name, last_service_date, status }]
Status calculado: si último reporte tiene algún checkbox dañado=true → "En Atención";
                  si tiene reportes sin dañado → "Correcto"; sin reportes → "Sin Historial"
```

#### Tarea 2.7 — GET /api/admin/policies
```
Query params: client_id, status
Retorna: [{ id, code, client_name, coverage_type, start_date, end_date, status, printer_count }]
Status calculado: end_date < hoy → "Expired"; end_date < hoy+30 → "Expiring"; → "Active"
```

#### Tarea 2.8 — POST /api/admin/reports/{report_id}/review
```
Body: { status: "approved|rejected", notes: "..." }
Actualiza: reports.status = "Reviewed", reports.internal_notes
```

#### Tarea 2.9 — GET /api/admin/sync/history
```
Query params: status (synced|failed), date_from, date_to
Retorna: [{ id, entity_type, entity_id, action, status, synced_at, error_message }]
Fuente: tabla sync_log
```

---

### FASE 3 — Gestión de Pólizas (depende de Fase 2)

**Objetivo:** CRUD completo de pólizas desde el admin, con asignación de impresoras.

#### Tarea 3.1 — CRUD de pólizas
```
POST   /api/admin/policies              # crear póliza
PUT    /api/admin/policies/{id}         # editar
DELETE /api/admin/policies/{id}         # eliminar (soft delete)
```
- Validar: `client_id` existe, `start_date < end_date`
- Auto-calcular `status` al insertar/actualizar
- Generar `code` autoincremental (P-001, P-002...)

**Archivo:** `server/app/api/routers/admin.py`

#### Tarea 3.2 — Asignación de impresoras a póliza
```
POST   /api/admin/policies/{id}/printers              # asignar impresora(s)
DELETE /api/admin/policies/{id}/printers/{printer_id} # quitar impresora
```
- Validar: impresora pertenece al mismo cliente de la póliza
- Tabla: `policy_printers` (ya modelada en `server/app/models/policy.py`)

#### Tarea 3.3 — Endpoint para app Flutter
```
GET /api/policies?client_id=...    # app obtiene pólizas vigentes del cliente
```
- Solo pólizas `status != "Expired"`
- Retorna datos mínimos para la app

---

### ✅ Fase 3 completada (16/03/2026)
- CRUD pólizas funcionando
- Asignación impresoras a póliza funcionando
- GET /api/policies para Flutter funcionando

---

### ✅ CRUD completo completado (16/03/2026)

Implementado en `server/app/api/routers/admin.py`:

| Endpoint | Descripción |
|----------|-------------|
| POST/PUT/DELETE /api/admin/technicians | Técnicos |
| POST/PUT/DELETE /api/admin/clients | Clientes |
| POST/PUT/DELETE /api/admin/printers | Impresoras |
| GET/POST /api/admin/plants | Plantas (por cliente) |
| GET/POST /api/admin/areas | Áreas (por planta) |
| GET /api/admin/catalog/models | Modelos de impresoras |

Helper `_next_code(db, model, prefix, digits)` para códigos legibles T-0001/I-0001/etc.
Helper `_hash_password(password)` con PBKDF2-HMAC-SHA256.
Migración 002 agrega columna `password_hash` a `users`.

Frontend actualizado: TechniciansPage, ClientsPage, PrintersPage con modales create/edit/delete.
PrintersPage tiene selectores encadenados: cliente → planta → área → modelo.
Se pueden crear plantas y áreas inline desde el modal de impresora.

---

### ✅ Mejoras PrintersPage completadas (16/03/2026)

1. **Búsqueda** — campo con debounce 350ms → `?search=` en GET /api/admin/printers (serial, código, modelo)
2. **Columna Modelo** — muestra `{brand} {model_name}` en la tabla
3. **CRUD Modelos** — `NewModelModal` (brand, model_name, dpi) con `POST /api/admin/catalog/models`; botón "+" en PrinterModal abre modal apilado (z-60/z-70); auto-selecciona modelo creado
4. **Ícono Sidebar** — `Sidebar.tsx` cambia `Cpu` → `Printer` (lucide-react) para la entrada "Impresoras"

---

### ✅ Mejoras UI admin-web completadas (16/03/2026)

1. **Logo solo en Header** — Logo eliminado del sidebar; aparece en `Header.tsx` (h-10) junto al separador + título de sección
2. **Modal de reporte** — Convertido de panel lateral a modal centrado (`max-w-2xl`), sin botones de revisión
3. **Evidencia fotográfica** — Galería de miniaturas 3-col con lightbox fullscreen y navegación prev/next
4. **Firma como imagen** — Muestra `<img>` de la firma PNG desde `/uploads/` si está disponible; fallback a avatar
5. **Botón "Ver PDF"** — Abre `/uploads/...` en nueva pestaña si existe el archivo
6. **Nuevo endpoint** — `GET /api/admin/reports/{id}/files` retorna `{photos, signature, pdf}` con URLs relativas a `/uploads/`
7. **Static files** — `main.py` monta `UPLOAD_DIR` en `/uploads` con `StaticFiles`
8. **Ícono Dashboard** — `Cpu` → `Printer` en KPI "Impresoras en atención"

---

### Tarea pendiente — IDs legibles en todas las tablas
> ✅ IMPLEMENTADO — helper _next_code() en admin.py

- Técnicos: T-0001, T-0002...
- Clientes: (sin código aún — campo no en modelo Client)
- Impresoras: I-0001, I-0002...
- Pólizas: P-0001, P-0002...
- Reportes: R-0001... (generado por sync router)

---

### ✅ FASE 4 — Panel Web React — COMPLETADA (16/03/2026)

**Objetivo:** SPA React en `admin-web/` para que el administrador gestione datos.

#### Tarea 4.1 — Setup del proyecto
- Crear `admin-web/` con Vite + React + TypeScript + Tailwind CSS
- Instalar: `axios` (HTTP), `react-router-dom` (navegación), `react-query` (cache), `react-table` (tablas), `recharts` (gráficas)
- Variables de entorno: `VITE_API_URL=http://localhost:8000`

#### Tarea 4.2 — Layout y navegación
- Sidebar con: Dashboard, Reportes, Clientes, Técnicos, Impresoras, Pólizas, Sincronización
- Header con nombre de sección activa
- Responsive (colapsa en móvil)

#### Tarea 4.3 — Dashboard con KPIs
Tarjetas con:
- Total reportes del mes
- Clientes activos
- Impresoras "En Atención"
- Pólizas por vencer (< 30 días)
- Últimas sincronizaciones (mini-tabla)

#### Tarea 4.4 — Pantalla de Reportes
- Tabla paginada con filtros (cliente, técnico, estado, fecha)
- Click en fila → detalle completo (fotos, firma, checkboxes)
- Botón "Aprobar / Rechazar" reporte (llama POST /api/admin/reports/{id}/review)

#### Tarea 4.5 — Pantalla de Clientes
- Lista de clientes con conteos (plantas, impresoras, pólizas)
- Búsqueda por nombre/RFC

#### Tarea 4.6 — Pantalla de Técnicos
- Lista con código, nombre, conteo de reportes, última sync

#### Tarea 4.7 — Pantalla de Impresoras
- Tabla filtrable por cliente, estado (Correcto / En Atención / Sin Historial)
- Chip de color por estado

#### Tarea 4.8 — Pantalla de Pólizas
- Tabla con estado coloreado (Active=verde, Expiring=amarillo, Expired=rojo)
- Crear / Editar / Eliminar póliza (formulario modal)
- Selector multi-impresora para asignar cobertura (filtradas por cliente)

#### Tarea 4.9 — Pantalla de Sincronización
- Historial de sync_log con filtros
- Contadores: total synced, failed, pending

---

### FASE 5 — Conectar app Flutter al backend (depende de Fase 1)

**Objetivo:** Reemplazar el mock de 3 segundos por sincronización real HTTP.

#### Tarea 5.1 — Agregar config de URL servidor
- Agregar constante `kServerBaseUrl` en `lib/core/constants.dart` (o similar)
- Ejemplo: `http://192.168.1.x:8000` para red local de pruebas

#### Tarea 5.2 — Implementar SyncService en Flutter
- Crear `lib/features/sync/services/sync_service.dart`
- Leer registros `pending` de `sync_queue` (Drift)
- Para cada registro:
  - Si `entityType == 'report'`: POST a `/api/reports` con `payloadJson`
  - Si `entityType == 'file'`: POST a `/api/files` con multipart
  - Si éxito: actualizar `estadoPeticion = 'synced'` en Drift
  - Si falla: incrementar `intentosFallidos`, actualizar `estadoPeticion = 'failed'` si >= max_attempts
- Actualizar `lastSyncAt` del técnico en Drift

#### Tarea 5.3 — Conectar SyncService al botón Sync
- Reemplazar `_startSync()` en `sync_dashboard_screen.dart` (línea ~90)
- Llamar `SyncService.runSync()` y manejar progreso/errores en UI

### ✅ Fase 5 completada (16/03/2026)

**Tareas 5.1–5.3 implementadas:**
- `lib/core/constants.dart` — `kServerBaseUrl`, `kServerBaseUrlDevice`, `kMaxSyncAttempts`, `kAuthTokenKey`
- `lib/features/sync/services/sync_service.dart` — SyncService real: POST /api/reports (JSON), POST /api/files (multipart), actualiza `estadoPeticion`, cuenta intentos fallidos, actualiza `lastSyncAt`, inyecta JWT
- `sync_dashboard_screen.dart` — Conectado a SyncService con progress callback + snackbars de éxito/error; `BuildContext` resuelto antes de `await`

---

### ✅ Tarea 5.4 — Autenticación JWT (16/03/2026)

**Backend:**
- `server/app/auth.py` — `create_access_token`, `verify_token`, `get_current_user` (FastAPI dependency)
- `server/app/api/routers/auth.py` — `POST /api/auth/login`: valida email + PBKDF2-HMAC-SHA256, retorna `{access_token, token_type, user}`
- `server/app/api/routers/sync.py` — 4 endpoints protegidos con `Depends(get_current_user)`: POST /reports, POST /reports/bulk, POST /files, GET /sync/status
- `server/app/main.py` — Registrado `auth_router`

**Flutter:**
- `pubspec.yaml` — Agregado `flutter_secure_storage: ^9.0.0`
- `lib/core/constants.dart` — Agregada `kAuthTokenKey = 'auth_token'`
- `lib/features/auth/services/auth_service.dart` — `login()`, `logout()`, `getToken()`, `isLoggedIn()`, `getStoredSession()`; almacena JWT + datos de usuario en FlutterSecureStorage
- `lib/features/auth/providers/auth_provider.dart` — Llama `AuthService.login()` (API real), upserta usuario en DB local, actualiza sessionProvider
- `lib/features/auth/presentation/login_screen.dart` — Campo "Contraseña" (de PIN a password), sin valores por defecto
- `lib/features/sync/services/sync_service.dart` — Lee JWT con `AuthService().getToken()` y agrega `Authorization: Bearer {token}` en cada request
- `lib/main.dart` — `ProviderContainer` + `UncontrolledProviderScope`; restaura sesión desde secure storage al iniciar la app

**APK generado:** `C:\Users\Victor\Desktop\servicios_mainpc_v5.apk` (79.6 MB)

**Archivos Flutter:**
- `lib/features/sync/sync_dashboard_screen.dart` (botón mock)
- `lib/features/sync/sync_history_screen.dart` (ya tiene estructura de historial)

---

### FASE 6 — Despliegue (depende de todo lo anterior)

#### Tarea 6.1 — Docker Compose
- `server/docker-compose.yml` con: postgres + app FastAPI
- Variables de entorno en `.env`
- Volume para `/var/smp/uploads`

#### Tarea 6.2 — Deploy en servidor
- Seleccionar servidor destino (VPS, servidor local, etc.)
- Configurar PostgreSQL en producción
- Ejecutar migraciones Alembic
- Iniciar con Docker Compose o systemd
- Actualizar `kServerBaseUrl` en Flutter con IP/dominio real

---

## Orden de implementación recomendado

```
1.1 → 1.2 → 1.3 (verificar sync)
    ↓
2.1 → 2.2 → ... → 2.9 (endpoints admin)
    ↓
3.1 → 3.2 → 3.3 (pólizas)
    ↓
4.1 → 4.2 → ... → 4.9 (panel web)  ← en paralelo con Fase 5
5.1 → 5.2 → 5.3 (Flutter sync)     ← puede empezar después de 1.x
    ↓
6.1 → 6.2 (deploy)
```

---

## Archivos a crear

| Archivo | Descripción |
|---------|-------------|
| `server/app/api/routers/admin.py` | Todos los endpoints GET/POST admin |
| `server/app/schemas/admin.py` | Schemas Pydantic de respuesta admin |
| `admin-web/` | Proyecto React completo |
| `lib/features/sync/services/sync_service.dart` | Lógica de sync HTTP en Flutter |
| `lib/core/constants.dart` | URL del servidor |

## Archivos a modificar

| Archivo | Cambio |
|---------|--------|
| `server/app/main.py` | Registrar router admin |
| `server/app/api/routers/sync.py` | Agregar GET /api/sync/status + GET /api/policies |
| `lib/features/sync/sync_dashboard_screen.dart` | Reemplazar mock sync |

---

## Verificación por fase

| Fase | Cómo verificar |
|------|---------------|
| 1 | Swagger → POST /api/reports → ver en PostgreSQL con `SELECT * FROM reports` |
| 2 | Swagger → GET /api/admin/reports → retorna lista paginada |
| 3 | Swagger → POST /api/admin/policies → crear póliza → asignar impresora |
| 4 | `npm run dev` en admin-web → ver datos reales en tablas |
| 5 | Flutter → botón Sync → ver registro en PostgreSQL |
| 6 | `docker-compose up` → app accede al servidor por IP de red |
