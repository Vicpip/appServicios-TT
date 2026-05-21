# Sprint 1 — Estado de Avance (industrial_service_reports)

> **Cliente:** Servicios Main PC
> **Proyecto:** App Flutter offline-first para reportes de servicio de impresoras de código de barras.
> **Stack:** Flutter + Drift (SQLite) + Riverpod + GoRouter.
> **Worktree activo:** `C:\Users\Victor\Documents\app\.claude\worktrees\eloquent-tesla`

---

## 🎯 ¿Qué es la aplicación?

**industrial_service_reports** es una app móvil (Android/iOS) para gestionar y documentar servicios técnicos de mantenimiento en impresoras de etiquetas Zebra y similares.

Los técnicos de campo pueden:
- ✅ Registrar clientes, plantas, áreas e impresoras
- 📱 Escanear códigos QR de las impresoras
- 📋 Crear reportes de servicio con checklist técnico
- 📸 Capturar fotos del equipo como evidencia
- ✍️ Firma digital del técnico y cliente
- 📊 Generar PDF profesional del reporte
- 🔄 Sincronizar datos con servidor backend (cuando esté disponible)
- 📚 Consultar historial de servicios por cliente/impresora
- 📅 Gestionar pólizas de mantenimiento

---

## 🔄 Flujo de uso principal

```
1. INICIO (Dashboard)
   ├─ Ver clientes registrados
   ├─ Ver reportes recientes
   └─ Ver estado de sincronización

2. CREAR REPORTE
   ├─ Escanear QR o buscar impresora
   ├─ Ver datos de la impresora (serial, modelo, cliente)
   ├─ Completar checklist técnico (8 ítems)
   ├─ Capturar fotos del equipo
   ├─ Escribir notas de servicio
   ├─ Ingresar contador de líneas impresas
   ├─ Seleccionar nivel de oscuridad y tipo de etiqueta
   ├─ Firmar digital (técnico y cliente)
   └─ Guardar reporte en BD local

3. VISUALIZAR REPORTES
   ├─ Ver historial de servicios por impresora
   ├─ Ordenar (más reciente → más antiguo)
   ├─ Ver detalle completo de cada reporte
   └─ Descargar PDF

4. GESTIÓN DE DATOS
   ├─ Clientes (crear, editar, ver plantas/pólizas)
   ├─ Impresoras (inventario, detalle técnico, historial)
   ├─ Pólizas de mantenimiento (activas, por vencer, vencidas)
   └─ Perfil técnico (datos del operador, firma digital)

5. SINCRONIZACIÓN (cuando haya backend)
   ├─ Ver reportes pendientes de sincronizar
   ├─ Cola de sincronización con reintentos automáticos
   └─ Historial de sincronizaciones exitosas
```

---

## 🏗️ Arquitectura

**Offline-first:** Todos los datos se guardan localmente en SQLite. La sincronización con servidor es eventual y asincrónica.

| Componente | Rol |
|-----------|-----|
| **UI (Flutter)** | Pantallas en Material Design 3 |
| **Riverpod** | State management (providers reactivos) |
| **GoRouter** | Navegación con rutas nombradas |
| **Drift (SQLite)** | Base de datos local tipada en Dart |
| **pdf + printing** | Generación de PDFs profesionales |
| **mobile_scanner** | Lectura de códigos QR |
| **signature** | Captura de firmas digitales |
| **image_picker** | Selección de fotos |
| **permission_handler** | Permisos de dispositivo |

---

## ✅ Completado (12/12 Tareas)

| # | Tarea | Descripción | Archivos clave |
|---|-------|-------------|---|
| Task 1 | **Perfil técnico** | Canvas de firma real (bottom sheet `_SignaturePadSheet`) + guardar PNG + `lastSyncAt` real de BD | `technician_profile_screen.dart` |
| Task 2 | **Ver detalles impresora** | "Ver detalles" en cliente → navega a ficha técnica real (`PrinterDetailArgs`) | `client_detail_screen.dart` |
| Task 3 | **Pólizas reales** | Tab Pólizas muestra pólizas reales del cliente (query Drift por `clientId`) | `client_detail_screen.dart` |
| Task 4 | **Reportes reales** | Tab Reportes muestra reportes reales del cliente (via printerIds) | `client_detail_screen.dart` |
| Task 5 | **printerId en reporte** | `printerId` pasa correctamente al crear reporte desde ficha/inventario | `printer_detail_screen.dart`, `printer_inventory_screen.dart` |
| Task 6 | **Estado impresora** | Query al último reporte: si alguno de 4 checkboxes dañado es `true` → "En Atención"; si no → "Correcto"; sin reportes → "Sin historial" | `printer_detail_screen.dart` |
| Task 7 | **Orden historial** | Radio "más reciente / más antiguo" en bottom sheet de filtros (boolean `_sortAscending`) | `service_history_screen.dart` |
| Task 8 | **Ver Reporte** | `ReportViewScreen` creada (read-only); botones "Ver Reporte" funcionales | `report_view_screen.dart`, `printer_detail_screen.dart`, `service_history_screen.dart` |
| Task 9 | **Códigos legibles** | Mostrar T-001/I-001/R-001/P-001 en UI; `code` generado al insertar | `technician_profile_screen.dart`, `printer_detail_screen.dart`, etc. |
| Task 10 | **QR overflow fix** | `resizeToAvoidBottomInset: false` en Scaffold | `qr_scanner_screen.dart` |
| Task 11 | **PDF service** | `pdf_service.dart` completo: layout dos columnas, checkboxes Sí/No, firmas lado a lado, página de fotos | `lib/features/reports/services/pdf_service.dart` |
| Task 12 | **Sync dashboard** | Consulta tabla `SyncQueue` real; cuenta pending por entityType (report/file/signature) | `sync_dashboard_screen.dart` |
| DB | **Migración v4→v5** | Columnas `code` en Users/Printers/Reports/Policies; tabla `SyncQueue`; codegen ok | `app_database.dart` |

---

## Estado Final

✅ **Sprint 1 — 100% COMPLETADO**
- 12/12 tareas implementadas
- Probado en dispositivo ✓
- APK v4 listo y en escritorio

| Archivo | Contenido |
|---------|-----------|
| `lib/data/local/app_database.dart` | Schema Drift completo (v5) |
| `lib/core/router/app_router.dart` | Rutas nombradas |
| `lib/core/router/route_args.dart` | `PrinterDetailArgs`, `CaptureArgs` |
| `lib/features/reports/providers/capture_provider.dart` | Estado del reporte en curso |
| `lib/features/reports/services/pdf_service.dart` | Generación de PDF completa |
| `lib/img/logo_smp.png` | Logo para PDF |

---

## APKs generados

| Versión | Archivo | Cambios incluidos |
|---------|---------|-------------------|
| v1 | `servicios_mainpc.apk` | Build inicial |
| v2 | `servicios_mainpc_v2.apk` | Area como texto libre en QuickAdd |
| v3 | `servicios_mainpc_v3.apk` | Tasks 2/3/4/5/10 + DB v5 |
| v4 | `servicios_mainpc_v4.apk` | PDF rediseñado (layout actual) |

---

## 📡 Sincronización esperada

| Campo en SyncQueue | Valor | Descripción |
|-------------------|-------|-------------|
| `methodHttp` | `'POST'` | Método HTTP |
| `endpointDestino` | `'/api/reports'` | Endpoint del servidor |
| `payloadJson` | JSON reporta | Estructura arriba ↑ |
| `entityType` | `'report'` \| `'file'` \| `'signature'` | Tipo de entidad |
| `entityId` | UUID | ID de la entidad |
| `estadoPeticion` | `'pending'` → `'synced'` → `'failed'` | Estado |
| `intentosFallidos` | 0+ | Reintentos automáticos |

---

# Sprint 2 — Backend Server (Python)

## 🎯 Objetivo

Crear servidor Python que:
1. ✅ Reciba datos de la app móvil (reportes, fotos, firmas)
2. ✅ Almacene en BD centralizada (PostgreSQL)
3. ✅ Exponga API web para panel administrativo
4. 🔮 Permita integración futura de modelo de estimación/predicción

---

## 🏗️ Stack recomendado

```
Backend:
├─ Python 3.10+
├─ FastAPI (alternativa: Flask)
├─ SQLAlchemy ORM (con Alembic para migraciones)
├─ PostgreSQL (BD principal)
├─ Pydantic (validación de datos)
└─ python-multipart (manejo de archivos)

Frontend Admin:
├─ React / Vue / Angular
├─ Conexión a la misma API REST
└─ Dashboard de reportes, cliente, técnicos, sync

ML (futuro):
└─ sklearn / TensorFlow (para estimación de tiempo/costos)
```

---

## 📊 Modelo de Datos (PostgreSQL)

```sql
-- Tablas principales (espejo offline-first de la app)
CREATE TABLE users (
  id UUID PRIMARY KEY,
  code VARCHAR(10),  -- T-001, T-002...
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255) UNIQUE,
  role VARCHAR(50),  -- 'technician', 'admin'
  signature_path TEXT,
  last_sync_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE clients (
  id UUID PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  rfc VARCHAR(50),
  address TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE plants (
  id UUID PRIMARY KEY,
  client_id UUID REFERENCES clients(id),
  name VARCHAR(255) NOT NULL,
  contact_name VARCHAR(255),
  contact_phone VARCHAR(20),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE areas (
  id UUID PRIMARY KEY,
  plant_id UUID REFERENCES plants(id),
  name VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE printers (
  id UUID PRIMARY KEY,
  code VARCHAR(10),  -- I-001, I-002...
  qr_uuid VARCHAR(255) UNIQUE,
  serial_number VARCHAR(255) UNIQUE NOT NULL,
  client_id UUID REFERENCES clients(id),
  plant_id UUID REFERENCES plants(id),
  area_id UUID REFERENCES areas(id),
  model_id UUID,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE reports (
  id UUID PRIMARY KEY,
  code VARCHAR(10),  -- R-001, R-002...
  printer_id UUID REFERENCES printers(id) NOT NULL,
  tech_id UUID REFERENCES users(id) NOT NULL,
  service_type VARCHAR(50),  -- 'Preventivo', 'Correctivo'
  status VARCHAR(50),  -- 'Draft', 'Signed', 'Synced'
  service_date TIMESTAMP NOT NULL,
  linear_inches_counter INT,
  darkness_level INT,
  label_type_id UUID,
  technical_checkboxes JSONB,  -- { "Mantenimiento general": true, ... }
  notes TEXT,
  signature_name VARCHAR(255),
  signature_role VARCHAR(255),
  signature_image_path TEXT,
  photo_paths JSONB,  -- ["path/to/photo1.jpg", "path/to/photo2.jpg"]
  synced_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE policies (
  id UUID PRIMARY KEY,
  code VARCHAR(10),  -- P-001, P-002...
  client_id UUID REFERENCES clients(id),
  serial_number VARCHAR(255),
  start_date DATE,
  end_date DATE,
  coverage_type VARCHAR(100),  -- 'Integral', 'Preventivo', etc.
  status VARCHAR(50),  -- 'Active', 'Expired', 'Expiring'
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE sync_queue (
  id UUID PRIMARY KEY,
  method_http VARCHAR(10),  -- 'POST', 'PUT', 'DELETE'
  endpoint_destino VARCHAR(255),  -- '/api/reports', '/api/files'
  payload_json JSONB,
  entity_type VARCHAR(50),  -- 'report', 'file', 'signature'
  entity_id UUID,
  request_status VARCHAR(50),  -- 'pending', 'in_progress', 'synced', 'failed'
  attempts INT DEFAULT 0,
  max_attempts INT DEFAULT 5,
  last_error TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Tabla para historizar sincronizaciones
CREATE TABLE sync_log (
  id SERIAL PRIMARY KEY,
  sync_queue_id UUID REFERENCES sync_queue(id),
  status VARCHAR(50),
  response_code INT,
  response_body JSONB,
  synced_at TIMESTAMP DEFAULT NOW()
);
```

---

## 🔌 Endpoints REST necesarios

### **Sincronización (recibe datos de la app)**

```
POST /api/reports
  ├─ Body: JSON de reporte (arriba ↑)
  ├─ Valida: printerId, techId, campos requeridos
  ├─ Guarda: en tabla reports
  ├─ Retorna: { "id": "report-uuid", "synced_at": "ISO8601", "status": "synced" }
  └─ Actualiza: SyncQueue.status = 'synced'

POST /api/files
  ├─ Body: multipart/form-data (foto, firma)
  ├─ Guarda: archivo en /uploads/
  ├─ Asocia: al reporte_id
  └─ Retorna: { "file_path": "...", "synced_at": "ISO8601" }

GET /api/sync/status
  ├─ Retorna: { "pending_reports": N, "synced_total": N, "failed": N }
  └─ Útil: para refresh en dashboard de app
```

### **API Admin (para web administradora)**

```
GET /api/admin/reports
  ├─ Query params: ?client_id=..., ?tech_id=..., ?status=...
  ├─ Retorna: [ { id, code, printer, tech, date, status, ... }, ... ]
  └─ Paginado: offset, limit

GET /api/admin/reports/{report_id}
  ├─ Retorna: detalle completo + fotos + firmas
  └─ Status: "Signed", "Synced", "Reviewed"

GET /api/admin/clients
  ├─ Retorna: [ { id, name, rfc, plant_count, printer_count, policy_status, ... }, ... ]
  └─ Filtros: ?search=nombre, ?policy_status=active/expired

GET /api/admin/printers
  ├─ Retorna: [ { id, code, serial, client, plant, area, last_service_date, status, ... }, ... ]
  └─ Status: "Correcto", "En Atención", "Sin Historial"

GET /api/admin/technicians
  ├─ Retorna: [ { id, code, name, reports_count, last_sync, ... }, ... ]

GET /api/admin/policies
  ├─ Retorna: [ { id, code, client, start_date, end_date, status, ... }, ... ]
  └─ Status: "Active", "Expiring (< 30 días)", "Expired"

POST /api/admin/reports/{report_id}/review
  ├─ Body: { "status": "approved|rejected", "notes": "..." }
  ├─ Guarda: en tabla reports (status = 'Reviewed')
  └─ Notifica: app (si quieres feedback)

GET /api/admin/sync/history
  ├─ Retorna: [ { id, sync_queue_id, status, response_code, synced_at }, ... ]
  └─ Filtra: ?status=synced|failed, ?date_range=...
```

---

## 🔄 Flujo de sincronización detallado

```
1️⃣ APP ENVÍA
   POST /api/reports + payloadJson

2️⃣ SERVIDOR RECIBE
   ├─ Valida schema (Pydantic)
   ├─ Verifica printerId, techId existen
   ├─ Guarda en BD (PostgreSQL)
   └─ Crea entry en sync_log

3️⃣ SERVIDOR RESPONDE
   {
     "success": true,
     "id": "report-uuid",
     "synced_at": "2026-03-13T15:30:00Z",
     "status": "synced"
   }

4️⃣ APP RECIBE RESPUESTA
   ├─ Si status = 'synced' → actualiza SyncQueue.estadoPeticion = 'synced'
   ├─ Si error → SyncQueue.estadoPeticion = 'failed', intentosFallidos++
   └─ Reintenta después (con backoff exponencial)

5️⃣ ADMIN VE EN WEB
   ├─ Reportes en tiempo real
   ├─ Status de sincronización
   └─ Dashboard con KPIs
```

---

## 🎛️ Configuración recomendada

```python
# .env
DATABASE_URL=postgresql://user:pass@localhost:5432/servicios_mainpc
JWT_SECRET=... (si quieres auth)
FILE_UPLOAD_DIR=/uploads/
MAX_RETRIES=5
RETRY_DELAY_SECONDS=60

# settings.py
DEBUG = False (producción)
CORS_ORIGINS = ["http://admin.example.com", "http://localhost:3000"]
LOG_LEVEL = "INFO"
```

---

## 📦 Estructura de carpetas recomendada

```
servicios-mainpc-backend/
├─ app/
│  ├─ main.py                 # Punto de entrada FastAPI
│  ├─ config.py               # Configuración
│  ├─ models/                 # Modelos SQLAlchemy
│  │  ├─ user.py
│  │  ├─ client.py
│  │  ├─ report.py
│  │  ├─ sync_queue.py
│  │  └─ ...
│  ├─ schemas/                # Pydantic schemas (validación)
│  │  ├─ report_schema.py
│  │  ├─ sync_schema.py
│  │  └─ ...
│  ├─ api/
│  │  ├─ routers/
│  │  │  ├─ sync.py           # POST /api/reports, /api/files
│  │  │  └─ admin.py          # GET /api/admin/...
│  │  └─ middleware/
│  │     └─ error_handler.py
│  ├─ services/
│  │  ├─ sync_service.py      # Lógica de sincronización
│  │  ├─ report_service.py    # Lógica de reportes
│  │  └─ file_service.py      # Manejo de archivos
│  ├─ database.py             # Conexión ORM
│  └─ utils/
│     ├─ validators.py
│     └─ helpers.py
├─ migrations/                # Alembic (versionado de BD)
├─ uploads/                   # Fotos, firmas
├─ tests/
├─ requirements.txt
├─ docker-compose.yml         # PostgreSQL local
├─ README.md
└─ .env.example
```

---

## 🚀 Inicio rápido (FastAPI)

```bash
# 1. Crear entorno
python -m venv venv
source venv/bin/activate

# 2. Instalar dependencias
pip install fastapi uvicorn sqlalchemy psycopg2-binary pydantic python-dotenv

# 3. Ejecutar servidor
uvicorn app.main:app --reload --port 8000

# 4. Acceder a docs interactiva
http://localhost:8000/docs
```

---

## ⏳ Tareas pendientes de Sprint 2

---

## ✅ Feature: Policy Visits — COMPLETADA (27/03/2026)

### Regla de negocio central implementada
- Sin póliza → Signed (firma individual)
- Póliza sin visita in_progress → Signed (firma individual)
- Póliza CON visita in_progress → pending_delivery (firma global)

### Sprint A — Migración
- Alembic `005_add_policy_visits.py` (down_revision=004)
- SQLAlchemy `PolicyVisit` model en `policy.py`
- Drift `PolicyVisits` table + `schemaVersion 9`

### Sprint B — Backend
- GET `/api/admin/policies/{id}/visits`
- POST `/api/admin/policies/{id}/visits/generate` (distribuye fechas uniformemente)
- PATCH `/api/admin/policies/{id}/visits/{visit_id}` (valida única in_progress)
- `policyVisits` incluido en `GET /api/sync/download`

### Sprint C — Flutter
- Nuevo `policy_visit_provider.dart` (activeVisitProvider, policyVisitsProvider)
- `sync_service.dart` descarga y persiste `policyVisits`
- `signature_screen.dart` activa condición `pending_delivery`
- `printer_confirmation_screen.dart` muestra banner "Visita X/N en curso"

### Sprint D — Flutter: Detalle de póliza
- Tab "Visitas" en `PolicyDetailScreen` (3 tabs total)
- Sección "Visita activa" con barra de progreso `X/N equipos`
- Botón "Iniciar visita" que actualiza DB local
- Lista `_VisitRow` con estado (Programada/En Curso/Completada)

### Sprint E — Admin Web
- `endpoints.ts` con visits, generateVisits, updateVisit
- `PoliciesPage.tsx` agrega sección Visitas en `AssignmentPanel`:
  - Botón "Generar visitas" (solo si no hay visitas)
  - Lista de visitas con fecha, status, badge progreso equipos
  - Botón "Activar" por visita (solo si no hay otra in_progress)

### Comandos para aplicar
```bash
alembic upgrade head
dart run build_runner build --delete-conflicting-outputs
```

---

## ✅ Mejoras UI Admin Web (20/05/2026 — sesión tarde)

| Cambio | Descripción |
|--------|-------------|
| `PolicyDetailPage.tsx` | Botón "Descargar PDF" en cada fila del historial de entregas. URL: `{base}/uploads/deliveries/delivery_{id}_resumen.pdf`. Icono `FileDown` (lucide). Fila reestructurada: div wrapper + botón expand (flex-1) + botón PDF (shrink-0, borde separador). |
| `ClientDetailPage.tsx` | Filtro por plantas ya implementado correctamente (pills dinámicos, bg-primary activo, solo visible si >1 planta). Sin cambios requeridos. |

---

## ✅ Autenticación Admin Web (20/05/2026)

| Cambio | Descripción |
|--------|-------------|
| `src/auth/authToken.ts` | Utilidades de token: `getToken/setToken/clearToken` en `localStorage` con clave `smp_admin_token` |
| `src/auth/AuthContext.tsx` | Context React: `login`, `logout`, `sessionExpired`, idle timeout 60 min con eventos de actividad, listener de evento `auth:unauthorized` |
| `src/pages/LoginPage.tsx` | Pantalla `/login`: email + contraseña, rate limiting 5 intentos → bloqueo 30s con contador, error genérico "Credenciales inválidas", spinner, aviso sesión expirada |
| `src/components/ProtectedRoute.tsx` | Guard de rutas: redirige a `/login` si no autenticado |
| `src/api/client.ts` | Interceptor request: inyecta `Authorization: Bearer {token}`. Interceptor response: 401 → clearToken + dispatchEvent `auth:unauthorized` |
| `src/router.tsx` | Ruta `/login` libre + rutas bajo `/` envueltas en `<ProtectedRoute>` |
| `src/main.tsx` | `<AuthProvider>` wrapping `<RouterProvider>` |
| `src/components/layout/Header.tsx` | Botón "Cerrar sesión" con ícono LogOut en el header |

**Seguridad implementada:**
- Rate limiting: 5 intentos fallidos → bloqueo 30s con countdown visible
- Error siempre "Credenciales inválidas" (sin revelar si es usuario o contraseña)
- Password limpiado en cada error; foco devuelto al campo
- Token nunca aparece en logs ni URLs
- `autocomplete="off"` en campo contraseña, `type="password"`
- Interceptor global 401 → cierra sesión automáticamente desde cualquier página
- Idle timeout 60 min → cierra sesión y muestra aviso "Sesión expirada"

---

## ✅ Funcionalidades reimplementadas Admin Web (20/05/2026)

| Cambio | Descripción |
|--------|-------------|
| `GET /api/admin/clients/{id}/detail` | Nuevo endpoint: detalle completo de cliente con stats, impresoras y pólizas |
| `GET /api/admin/printers/{id}/stats` | Nuevo endpoint: estadísticas técnicas últimos 30d (contador, oscuridad, etiqueta, advertencias) |
| `GET /api/admin/printers/template/download` | Nuevo endpoint: descarga Excel con 3 hojas (datos, instrucciones, catálogos); registrado ANTES de `/{id}` |
| `POST /api/admin/printers/bulk-upload` | Nuevo endpoint: carga masiva .xlsx/.csv con seguridad (5MB, 500 filas, sanitización) y respuesta de errores por fila |
| `openpyxl==3.1.5` | Instalado y agregado a `requirements.txt` |
| `router.tsx` | Agrega ruta `clients/:id` con `ClientDetailPage` |
| `ClientsPage.tsx` | Filas clickeables → `/clients/${id}`; `e.stopPropagation()` en botones editar/desactivar |
| `ClientDetailPage.tsx` | Ya existía completo; ahora accesible via `/clients/:id` |
| `PrinterDetailPage.tsx` | Sección "Estadísticas Técnicas" con 4 KPIs + observación + advertencias; modal al clic en historial |
| `TechnicianProfilePage.tsx` | Modal `DetailModal` al clic en filas del historial de reportes |
| `PrintersPage.tsx` | Botón "Plantilla" (descarga Excel) + botón "Carga masiva" (abre `BulkUploadModal` inline con dropzone, spinner y resultado) |
| `endpoints.ts` | Agrega `clients.clientDetail`, `printers.stats`, `printers.downloadTemplate`, `printers.bulkUpload` |

---

## ✅ Mejoras Dashboard Admin Web (20/05/2026)

| Cambio | Descripción |
|--------|-------------|
| KPI cards clickeables | Las 4 cards navegan a /reports, /clients, /printers, /policies con hover:shadow-md |
| Gráfica reportes 7 días | Nuevo endpoint `GET /api/admin/dashboard/reports-by-day` + BarChart apilado (Preventivo/Correctivo/Diagnóstico) con recharts |
| Impresoras en atención | Nuevo endpoint `GET /api/admin/dashboard/printers-attention` (máx 5) + lista compacta con badges de advertencia → /printers/{id} |
| Pólizas próximas a vencer | Nuevo endpoint `GET /api/admin/dashboard/policies-expiring` (máx 5, últimos 30 días) + lista con badge rojo ≤7d / amarillo >7d → /policies/{id} |
| Tabla sync mejorada | Backend: `SyncHistoryItem` agrega `tech_name` y `detalle` (join Report→User). Frontend: columnas Técnico y Detalle + traducción de acciones (Insert→"Reporte nuevo", etc.) |

---

## ✅ Fixes UI/UX Flutter (20/05/2026)

| Fix | Archivo | Cambio |
|-----|---------|--------|
| Banner sync oculto cuando 0 pendientes | `main_dashboard_screen.dart` | Condicional `if (pendingCount > 0)` alrededor del banner + SizedBox |
| Indicador ONLINE/OFFLINE real | `main_dashboard_screen.dart` | Deriva `isOnline` de `startupSyncProvider.phase == done` |
| Nombre técnico sin overflow | `main_dashboard_screen.dart` | `Flexible` + `TextOverflow.ellipsis` en el nombre del header |
| Label tile sync acortado | `main_dashboard_screen.dart` | `'Pendientes Sync'` → `'Por Sync'` |
| StatusBanner responsivo | `report_summary_screen.dart` | `Row` → `Wrap` en `_StatusBanner` para evitar overflow en pantallas angostas |
| Eliminar tile PIN en perfil | `technician_profile_screen.dart` | Eliminado tile "Cambiar PIN de Acceso" (mock sin funcionalidad) |

---

## ✅ Mejoras Flutter (20/05/2026 — sesión noche)

| Cambio | Descripción |
|--------|-------------|
| PDF entrega: estado "En Atención" / "Correcto" | `pdf_service.dart` → `_buildDeliveryPrinterTable`: solo 4 claves de daño (sin "Otros"), texto `'En Atención'` cuando hay daño |
| Timezone CDMX | `pubspec.yaml` agrega `timezone: ^0.9.0`; `main.dart` inicializa `tz.initializeTimeZones()`; nuevo helper `lib/core/utils/date_utils.dart` (`formatLocalCDMX`); 9 pantallas migradas a usar el helper |
| Ícono app | `pubspec.yaml` agrega `flutter_launcher_icons: ^0.14.1` + config `flutter_launcher_icons` apuntando a `lib/img/logo_smp.png` |
| Nombre app | `AndroidManifest.xml` ya tenía `android:label="Servicios - SMPC"` — sin cambio |

---

## ✅ Sprint 2 — Avance actual

### ✅ Fases 1, 2, 3 y 4 — COMPLETADAS (16/03/2026)

**Estado:** ✅ Backend + Panel Web React FUNCIONANDO

**Lo que se implementó:**

#### Fase 1 — Sincronización base
- POST /api/reports — recibe reportes de la app (camelCase→snake_case, sin FK)
- POST /api/reports/bulk — sincronización masiva
- POST /api/files — fotos y firmas
- GET /api/sync/status — contadores de estado
- GET /api/health — health check

#### Fase 2 — Endpoints Admin
- GET /api/admin/reports (paginado, filtros)
- GET /api/admin/reports/{id} (detalle completo)
- POST /api/admin/reports/{id}/review (aprobar/rechazar)
- GET /api/admin/clients (con conteos)
- GET /api/admin/technicians (con métricas)
- GET /api/admin/printers (con estado calculado)
- GET /api/admin/policies (con estado calculado)
- GET /api/admin/sync/history (historial paginado)

#### Fase 3 — Pólizas CRUD
- POST/PUT/DELETE /api/admin/policies
- POST/DELETE /api/admin/policies/{id}/printers
- GET /api/policies (para app Flutter)

#### Fase 4 — Panel Web React (admin-web/)
- Layout: sidebar navy, header sticky, responsive
- Dashboard con 4 KPIs + tabla sync (datos reales)
- Reportes: tabla paginada + filtros + panel lateral + aprobar/rechazar
- Clientes: tabla + búsqueda + modal crear/editar/desactivar
- Técnicos: grid de cards + modal crear/editar/desactivar
- Impresoras: tabla + modal crear (selectores encadenados cliente→planta→área→modelo) + editar/desactivar
- Pólizas: tabla + modal crear/editar/eliminar + asignación de impresoras
- Sincronización: contadores + historial paginado con filtros

#### CRUD completo (nuevo — 16/03/2026)
- POST/PUT/DELETE /api/admin/technicians — crear/editar/desactivar técnicos
- POST/PUT/DELETE /api/admin/clients — crear/editar/desactivar clientes
- POST/PUT/DELETE /api/admin/printers — crear/editar/desactivar impresoras
- GET/POST /api/admin/plants — listar/crear plantas por cliente
- GET/POST /api/admin/areas — listar/crear áreas por planta
- GET/POST /api/admin/catalog/models — catálogo de modelos de impresoras (con CRUD inline)
- Migración 002: columna password_hash en users

#### Mejoras PrintersPage (16/03/2026)
- Búsqueda con debounce 350ms → param `search=` en GET /api/admin/printers
- Columna "Modelo" en tabla: brand + model_name (join CatalogModel)
- NewModelModal apilado sobre PrinterModal (z-60/z-70); POST /api/admin/catalog/models
- Sidebar.tsx: icono Impresoras cambiado de `Cpu` → `Printer` (lucide-react)

#### Mejoras UI admin-web (16/03/2026)
- Logo eliminado del sidebar; solo aparece en Header.tsx (h-10) con separador + título de sección
- ReportsPage: modal centrado, sin botones de revisión, galería de fotos con lightbox, firma como imagen PNG, botón "Ver PDF"
- `GET /api/admin/reports/{id}/files` → `{photos: string[], signature, pdf}` con URLs `/uploads/...`
- `main.py` monta UPLOAD_DIR en `/uploads` con `StaticFiles` de FastAPI
- DashboardPage: KPI "Impresoras en atención" usa ícono `Printer`

**Decisiones técnicas:**
- PKs como String para compatibilidad con UUIDs de Drift/Flutter
- technical_checkboxes y photo_paths como Text JSON
- Upsert manual (get → insert/update)
- Contraseñas hasheadas con PBKDF2-HMAC-SHA256 + salt (stdlib Python)
- Códigos legibles T-0001/C-0001/I-0001 generados con helper _next_code()

### ✅ Fase 5 Flutter Sync — COMPLETADA (16/03/2026)

- `SyncService` real: POST /api/reports (JSON) + POST /api/files (multipart)
- `BuildContext` async-safe en `sync_dashboard_screen.dart`
- JWT inyectado en cada request (`Authorization: Bearer {token}`)

### ✅ Tarea 5.4 — Autenticación JWT (16/03/2026)

**Backend:**
- `server/app/auth.py` — `create_access_token`, `verify_token`, `get_current_user`
- `server/app/api/routers/auth.py` — `POST /api/auth/login` (PBKDF2-HMAC-SHA256)
- sync.py — 4 endpoints protegidos: POST /reports, POST /reports/bulk, POST /files, GET /sync/status
- `main.py` — registrado `auth_router`

**Flutter:**
- `flutter_secure_storage: ^9.0.0` añadido a pubspec
- `AuthService` → `login()`, `logout()`, `getToken()`, `isLoggedIn()`, `getStoredSession()`
- `auth_provider.dart` → llama API, upserta usuario en DB local, actualiza sessionProvider
- `login_screen.dart` → campo "Contraseña" (no PIN), sin valores por defecto
- `main.dart` → `UncontrolledProviderScope` + restaura sesión desde secure storage al iniciar
- APK v5: `C:\Users\Victor\Desktop\servicios_mainpc_v5.apk` (79.6 MB)

**Pendiente:**
- [ ] Desplegar en servidor (Fase 6)

**Comandos para retomar:**
```bash
cd C:\Users\Victor\Documents\app\.claude\worktrees\eloquent-tesla\server
venv\Scripts\activate
alembic upgrade head
uvicorn app.main:app --reload --port 8000

cd ..\admin-web
npm run dev
```

---

### **Gestión de Pólizas (administración desde Web Admin)**

**Estado:** ✅ COMPLETADO — CRUD desde panel web

**Contexto:**
- Las pólizas cubren **múltiples impresoras** de un cliente
- Se crean/editan/eliminan desde **web administradora** (no desde app)
- La app solo **consulta** y muestra pólizas activas (ya implementado en UI)
- El servidor debe **sincronizar** datos de pólizas a la app

**Tareas a implementar:**

1. **BD: Relación muchos-a-muchos (Policies ↔ Printers)**
   ```sql
   CREATE TABLE policy_printers (
     policy_id UUID REFERENCES policies(id) ON DELETE CASCADE,
     printer_id UUID REFERENCES printers(id) ON DELETE CASCADE,
     PRIMARY KEY (policy_id, printer_id)
   );
   ```

2. **Backend: Endpoints de pólizas (Admin)**
   ```
   POST /api/admin/policies                  # Crear póliza
   PUT /api/admin/policies/{policy_id}       # Editar póliza
   DELETE /api/admin/policies/{policy_id}    # Eliminar póliza
   POST /api/admin/policies/{policy_id}/printers  # Asignar impresoras a póliza
   DELETE /api/admin/policies/{policy_id}/printers/{printer_id}  # Quitar impresora
   ```

3. **Backend: Sincronización de pólizas (hacia app)**
   ```
   GET /api/policies?client_id=...     # App obtiene pólizas del cliente
   ```

4. **Lógica de negocio: Validaciones**
   - Una póliza puede cubrir 1+ impresoras del mismo cliente
   - No permite asignar impresora de cliente A a póliza de cliente B
   - Calcula estado automático (Active | Expiring < 30 días | Expired)
   - Alertas en dashboard si cliente tiene impresoras sin póliza

5. **Frontend Admin: Pantalla de pólizas**
   - CRUD de pólizas
   - Selector multi-impresora para asignar cobertura
   - Vista de pólizas por cliente
   - Filtros: activas, por vencer, vencidas

**Dependencias:**
- Sprint 2.1: Backend endpoints ✅ (arriba)
- Sprint 2.2: Web admin ⏳ (pendiente)
- Sprint 2.3: Sincronización pólizas → app ⏳ (pendiente)

---

## 🔮 Preparación para modelo ML (futuro)

El modelo de estimación se ejecutará:
- ✅ Al guardar un reporte (estimar tiempo de siguiente mantenimiento)
- ✅ En dashboard admin (predicción por cliente/impresora)
- ✅ Sin impacto en sincronización (background job)

Estructura preparada:
```python
# app/services/ml_service.py
class EstimationService:
    def predict_maintenance_date(self, printer_id: str) -> datetime:
        # Carga histórico de reports para ese printer
        # Usa modelo sklearn/TensorFlow
        # Retorna fecha estimada próximo servicio
        pass

    def predict_failure_risk(self, printer_id: str) -> float:
        # Retorna % de probabilidad de falla
        pass
```

---

# Plan — Rediseño de PDF (layout completo) [COMPLETADO]

## Contexto
El PDF de reporte se generó correctamente (Pág. 1 / 1, firmas lado a lado, checkboxes con Si/No). El usuario pide un rediseño completo del layout para reorganizar la información y agregar una página de fotos.

---

## Cambios en el archivo único: `lib/features/reports/services/pdf_service.dart`

---

## CAMBIO 1 — Header: agregar tipo de servicio y fecha junto al código

**Zona afectada:** `_buildHeader()` → columna derecha

**Antes:** sólo el código R-001 (azul) bajo el título.
**Después:** bajo el título, en la columna derecha, mostrar en orden:
```
REPORTE DE SERVICIO TÉCNICO    ← título (ya existe)
R-001                          ← código azul (ya existe)
Preventivo                     ← serviceType (sólo valor, sin etiqueta)
12 Mar 2026                    ← fecha
```

Implementación:
```dart
pw.Text(report.serviceType, style: TextStyle(fontSize: 11, color: PdfColors.blueGrey600)),
pw.SizedBox(height: 2),
pw.Text(_formatDate(report.serviceDate), style: TextStyle(fontSize: 11, color: PdfColors.blueGrey600)),
```

---

## CAMBIO 2 — Sección izquierda: "INFORMACIÓN DEL CLIENTE" (reemplaza "INFORMACIÓN DEL REPORTE")

**Antes:** Código, Fecha, Tipo de Servicio, Estado, Técnico.
**Después:** datos del cliente + planta/área de la impresora.

Campos:
- Nombre: `client.name`
- RFC: `client.rfc ?? '—'`
- Dirección: `client.address ?? '—'`
- Planta: `plant.name` (cargada via `printer.plantId` → tabla `Plants`)
- Área: `area.name` (cargada via `printer.areaId` → tabla `Areas`)

Datos a cargar en `generateReportPdf()`:
```dart
Plant? plant;
Area? area;
if (printer != null) {
  if (printer.plantId != null) {
    plant = await (db.select(db.plants)..where((p) => p.id.equals(printer.plantId!))).getSingleOrNull();
  }
  if (printer.areaId != null) {
    area = await (db.select(db.areas)..where((a) => a.id.equals(printer.areaId!))).getSingleOrNull();
  }
}
```

Función renombrada: `_buildClientInfoSection(client, plant, area)` → devuelve `pw.Widget`.

---

## CAMBIO 3 — Sección derecha "DATOS DE LA IMPRESORA": agregar 3 campos

**Antes:** Código, Serie, Modelo, Cliente.
**Después:** mantener esos 4 + agregar al final:
- Contador: `'${report.linearInchesCounter} pulg.'`
- Temperatura: `report.darknessLevel != null ? '${report.darknessLevel}' : '—'`
- Etiqueta: `catalogLabelType.name ?? '—'`

Datos a cargar:
```dart
CatalogLabelType? catalogLabelType;
if (report.labelTypeId != null) {
  catalogLabelType = await (db.select(db.catalogLabelTypes)
    ..where((l) => l.id.equals(report.labelTypeId!))).getSingleOrNull();
}
```

Firma del método: `_buildPrinterSection(printer, catalogModel, client, report, catalogLabelType)`.

**Eliminar** el campo "Cliente" de Datos de la Impresora (ya está en la sección del cliente).

---

## CAMBIO 4 — Alinear firmas (espaciado técnico = cargo cliente)

En `_buildSignatureBox()` para el técnico: agregar `pw.SizedBox(height: 14)` después del `_buildInfoRow('Nombre', name)` cuando `role == null`, para que el recuadro de firma arranque al mismo nivel que el del cliente (que tiene Nombre + Cargo).

```dart
_buildInfoRow('Nombre', name),
if (role == null) pw.SizedBox(height: 14),  // alinea con la fila "Cargo" del cliente
if (role != null) _buildInfoRow('Cargo', role),
```

---

## CAMBIO 5 — Nueva página de fotos (EVIDENCIA FOTOGRÁFICA)

Al final del contenido del `build:`, agregar:
```dart
if (photoImages.isNotEmpty) ...[
  pw.NewPage(),
  _buildPhotosSection(photoImages),
]
```

Cargar las fotos en `generateReportPdf()`:
```dart
final List<String> photoPaths = List<String>.from(
  (jsonDecode(report.photoPaths ?? '[]') as List<dynamic>)
);
final List<pw.ImageProvider> photoImages = [];
for (final String path in photoPaths) {
  if (io.File(path).existsSync()) {
    try {
      final Uint8List bytes = await io.File(path).readAsBytes();
      photoImages.add(pw.MemoryImage(bytes));
    } catch (_) {}
  }
}
```

`_buildPhotosSection(List<pw.ImageProvider> images)`:
- Título: "EVIDENCIA FOTOGRÁFICA"
- Grid de 2 columnas, imágenes con `pw.BoxFit.contain`, altura 180pt cada una, con bordes y márgenes

---

## Archivos a modificar

| Archivo | Cambio |
|---------|--------|
| `lib/features/reports/services/pdf_service.dart` | Todos los cambios arriba |

---

## Verificación

- [ ] Header muestra: código azul + tipo de servicio + fecha (sin etiquetas extra)
- [ ] Sección izquierda: "INFORMACIÓN DEL CLIENTE" con Nombre, RFC, Dirección, Planta, Área
- [ ] Sección derecha: "DATOS DE LA IMPRESORA" con Contador, Temperatura, Etiqueta
- [ ] Firma del técnico alineada con la del cliente (mismo nivel en el recuadro)
- [ ] Si hay fotos → página nueva con grid de imágenes
- [ ] APK generado y en el escritorio

