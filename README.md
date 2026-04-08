# Servicios Main PC — App de Reportes Técnicos

App offline-first para gestión de servicios técnicos de impresoras de código de barras (Zebra y similares). Desarrollada para **Servicios Main PC**.

---

## Stack

| Capa | Tecnología |
|------|-----------|
| Mobile | Flutter + Drift (SQLite) + Riverpod + GoRouter |
| Backend | Python 3.14 + FastAPI + SQLAlchemy + PostgreSQL + Alembic |
| Admin Web | React + TypeScript + Tailwind CSS + Vite |
| Auth | JWT (7 días para móvil) |

---

## Estructura del repositorio

```
/lib          → App Flutter (Android/iOS)
/server       → Backend FastAPI + migraciones Alembic
/admin-web    → Panel administrador React
/.claude      → Contexto, agentes, skills y commands
```

---

## Flujo de uso principal

```
1. INICIO (Dashboard)
   ├─ Ver técnicos, sincronización y pólizas activas

2. CREAR REPORTE
   ├─ Escanear QR o buscar impresora
   ├─ Completar checklist técnico (8 ítems)
   ├─ Capturar fotos del equipo
   ├─ Ingresar contador, oscuridad, tipo de etiqueta
   ├─ Firma digital técnico y cliente
   └─ Generar PDF y guardar en SQLite local

3. PÓLIZAS
   ├─ Consultar pólizas asignadas al técnico
   ├─ Ver visitas programadas y activas
   ├─ Registrar equipos visitados durante visita
   ├─ Firma global de entrega al completar visita
   └─ Generar PDF de entrega con firma embebida

4. SINCRONIZACIÓN
   ├─ Cola offline con reintentos automáticos
   ├─ JWT inyectado en cada request
   └─ Descarga pólizas, visitas e impresoras asignadas
```

---

## Arquitectura Flutter

**Offline-first:** todos los datos se guardan en SQLite local. La sincronización con el servidor es eventual y asincrónica.

```
lib/
├─ core/
│  ├─ constants.dart              # URLs de servidor (kServerBaseUrlDevice)
│  ├─ router/
│  │  ├─ app_router.dart          # GoRouter + rutas nombradas
│  │  ├─ app_routes.dart          # Constantes de rutas
│  │  └─ route_args.dart          # Args tipados (PrinterDetailArgs, etc.)
│  └─ theme/
│     └─ app_theme.dart           # Tema dark industrial (Material 3)
├─ data/
│  └─ local/
│     └─ app_database.dart        # Schema Drift (SQLite, v9)
└─ features/
   ├─ auth/                       # Login + JWT + flutter_secure_storage
   ├─ policies/
   │  ├─ presentation/
   │  │  ├─ policy_dashboard_screen.dart       # Dashboard pólizas
   │  │  ├─ policy_delivery_screen.dart        # Flujo entrega visita
   │  │  ├─ policy_delivery_signature_screen.dart  # Firma global
   │  │  ├─ policy_delivery_success_screen.dart    # Confirmación entrega
   │  │  └─ visit_summary_screen.dart          # Resumen visita
   │  └─ providers/
   │     ├─ pending_delivery_provider.dart
   │     ├─ policy_assignment_provider.dart
   │     └─ policy_visit_provider.dart
   ├─ printers/
   │  ├─ printer_confirmation_screen.dart  # Confirma equipo + banner visita activa
   │  └─ quick_add_printer_screen.dart
   ├─ reports/
   │  ├─ presentation/
   │  │  ├─ express_capture_screen.dart    # Captura rápida de reporte
   │  │  └─ report_summary_screen.dart     # Resumen antes de firmar
   │  ├─ providers/
   │  │  └─ capture_provider.dart          # Estado del reporte en curso
   │  └─ services/
   │     └─ pdf_service.dart               # PDF completo con firma embebida
   ├─ signature/
   │  └─ signature_screen.dart             # Canvas firma + lógica pending_delivery
   └─ sync/
      └─ services/
         └─ sync_service.dart              # Upload + download bidireccional
```

### Base de datos local (Drift SQLite v9)

Tablas: `Users`, `Clients`, `Plants`, `Areas`, `Printers`, `Reports`, `Policies`, `PolicyPrinters`, `PolicyVisits`, `SyncQueue`

### Lógica de firma / entrega

| Condición | Resultado |
|-----------|-----------|
| Sin póliza | `Signed` — firma individual |
| Póliza sin visita `in_progress` | `Signed` — firma individual |
| Póliza CON visita `in_progress` | `pending_delivery` — firma global al completar visita |

---

## Backend FastAPI

```
server/
├─ app/
│  ├─ main.py              # Punto de entrada, monta /uploads como StaticFiles
│  ├─ config.py            # .env: DATABASE_URL, JWT_SECRET, UPLOAD_DIR
│  ├─ auth.py              # JWT: create / verify token
│  ├─ database.py          # Conexión SQLAlchemy
│  ├─ models/
│  │  ├─ user.py           # User + password_hash
│  │  ├─ client.py
│  │  ├─ printer.py
│  │  ├─ report.py
│  │  └─ policy.py         # Policy + PolicyPrinter + PolicyVisit
│  ├─ schemas/
│  │  └─ admin.py          # Pydantic schemas (validación entrada/salida)
│  └─ api/routers/
│     ├─ auth.py           # POST /api/auth/login
│     ├─ sync.py           # POST /api/reports, /files, GET /sync/status, /sync/download
│     └─ admin.py          # CRUD completo de todas las entidades
└─ alembic/versions/
   ├─ 000_initial_schema.py
   ├─ 001_drop_report_fk_constraints.py
   ├─ 002_add_crud_fields.py          # password_hash en users
   ├─ 003_policy_printer_assignments.py
   ├─ 004_add_frequency_maintenance.py
   └─ 005_add_policy_visits.py
```

### Endpoints principales

#### Autenticación
```
POST /api/auth/login          → JWT token (7 días)
```

#### Sincronización (app → servidor)
```
POST /api/reports             → Subir reporte (camelCase aceptado)
POST /api/reports/bulk        → Subir múltiples reportes
POST /api/files               → Subir foto o firma (multipart)
GET  /api/sync/status         → Contadores pending/synced/failed
GET  /api/sync/download       → Descarga pólizas, visitas e impresoras asignadas
```

#### Admin — Reportes
```
GET  /api/admin/reports                    → Lista paginada (filtros: client, tech, status)
GET  /api/admin/reports/{id}               → Detalle + fotos + firma + PDF
GET  /api/admin/reports/{id}/files         → URLs de archivos asociados
POST /api/admin/reports/{id}/review        → Aprobar / rechazar reporte
```

#### Admin — CRUD entidades
```
GET/POST/PUT/DELETE /api/admin/clients
GET/POST/PUT/DELETE /api/admin/technicians
GET/POST/PUT/DELETE /api/admin/printers
GET/POST            /api/admin/plants
GET/POST            /api/admin/areas
GET/POST/PUT/DELETE /api/admin/catalog/models
```

#### Admin — Pólizas
```
GET/POST/PUT/DELETE /api/admin/policies
POST/DELETE         /api/admin/policies/{id}/printers
GET                 /api/admin/policies/{id}/visits
POST                /api/admin/policies/{id}/visits/generate   → Distribuye fechas
PATCH               /api/admin/policies/{id}/visits/{visit_id} → Activa visita
```

#### Admin — Sync
```
GET /api/admin/sync/history   → Historial paginado con filtros
```

### Modelo de datos PostgreSQL (resumen)

```sql
users          id(UUID), code(T-0001), name, email, role, password_hash, signature_path
clients        id(UUID), code(C-0001), name, rfc, address, is_active
plants         id(UUID), client_id, name, contact_name, contact_phone
areas          id(UUID), plant_id, name
printers       id(UUID), code(I-0001), serial_number, qr_uuid, client_id, plant_id, area_id, model_id
reports        id(UUID), code(R-0001), printer_id, tech_id, service_type, status, technical_checkboxes(JSON)
policies       id(UUID), code(P-0001), client_id, start_date, end_date, coverage_type, frequency, status
policy_printers  (policy_id, printer_id)  — muchos a muchos
policy_visits  id(UUID), policy_id, scheduled_date, status, visited_printers_json, completed_at
sync_queue     id(UUID), entity_type, entity_id, method_http, endpoint, payload_json, request_status
```

### Decisiones técnicas
- PKs como `String` (UUID) — compatibilidad Drift/Flutter
- `technical_checkboxes` y `photo_paths` como `Text` JSON
- Contraseñas con PBKDF2-HMAC-SHA256 + salt (stdlib Python, sin dependencias)
- Códigos legibles generados con `_next_code()`: T-0001, C-0001, I-0001, R-0001, P-0001
- `UPLOAD_DIR=./uploads` (relativo, se crea automáticamente)

---

## Panel Admin Web (React)

```
admin-web/src/
├─ api/
│  └─ endpoints.ts          # Axios: todas las llamadas al backend
├─ components/
│  ├─ Header.tsx             # Logo + título de sección
│  ├─ Sidebar.tsx            # Navegación lateral (navy)
│  └─ Layout.tsx
├─ pages/
│  ├─ DashboardPage.tsx      # 4 KPIs + tabla sync en tiempo real
│  ├─ ReportsPage.tsx        # Tabla paginada + filtros + panel lateral + lightbox fotos
│  ├─ ClientsPage.tsx        # Tabla + modal crear/editar/desactivar
│  ├─ TechniciansPage.tsx    # Grid de cards + modal + perfil
│  ├─ TechnicianProfilePage.tsx  # Perfil detallado de técnico
│  ├─ PrintersPage.tsx       # Tabla + modal (selectores client→plant→area→model) + búsqueda
│  ├─ PoliciesPage.tsx       # CRUD pólizas + asignación impresoras + gestión visitas
│  └─ SyncPage.tsx           # Contadores + historial paginado con filtros
└─ router.tsx                # React Router con todas las rutas
```

### Funcionalidades del panel
- **Dashboard:** KPIs de reportes, técnicos, impresoras en atención, pólizas activas
- **Reportes:** galería de fotos con lightbox, firma como imagen PNG, botón "Ver PDF"
- **Impresoras:** búsqueda con debounce 350ms, columna Modelo (brand + model_name), modal para crear modelo inline
- **Pólizas:** CRUD completo + asignación multi-impresora + generación/activación de visitas

---

## Cómo levantar el proyecto

### Backend (Windows)
```bash
cd server
venv\Scripts\activate
alembic upgrade head
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Backend (Linux/Mac)
```bash
cd server
source venv/bin/activate
alembic upgrade head
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Panel Admin Web
```bash
cd admin-web
npm install
npm run dev
# Acceder: http://localhost:5173
```

### Flutter
```bash
# 1. Editar IP del servidor en lib/core/constants.dart
#    kServerBaseUrlDevice = 'http://TU_IP_LOCAL:8000'

# 2. Instalar dependencias y generar código
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# 3. Ejecutar
flutter run
```

### Variables de entorno (server/.env)
```env
DATABASE_URL=postgresql://usuario:contraseña@localhost:5432/servicios_mainpc
JWT_SECRET=clave_secreta_larga
UPLOAD_DIR=./uploads
```

---

## APKs generados

| Versión | Cambios principales |
|---------|-------------------|
| v1 | Build inicial |
| v2 | Área como texto libre en QuickAdd |
| v3 | Tasks 2/3/4/5/10 + DB v5 |
| v4 | PDF rediseñado (layout dos columnas, fotos, firmas) |
| v5 | Auth JWT + flutter_secure_storage |

---

## Estado del proyecto (Sprints)

| Sprint | Estado | Descripción |
|--------|--------|-------------|
| Sprint 1 | ✅ Completado | App Flutter base: reportes, PDF, firma, QR, historial |
| Sprint 2 | ✅ Completado | Backend FastAPI + panel Admin Web + sync bidireccional + JWT |
| Sprint 3 | ✅ Completado | Módulo pólizas completo: visitas, entrega, firma global, PDF entrega |

### Sprint 3 — detalle

- **Flutter:** pantallas de entrega de visita (`policy_delivery_screen`, `policy_delivery_signature_screen`, `policy_delivery_success_screen`, `visit_summary_screen`)
- **Flutter:** providers de visitas (`policy_visit_provider`, `policy_assignment_provider`, `pending_delivery_provider`)
- **Flutter:** `pdf_service.dart` con firma embebida en PDF
- **Flutter:** `sync_service.dart` descarga y persiste `policyVisits` e impresoras asignadas
- **Flutter:** `signature_screen.dart` activa flujo `pending_delivery` si hay visita activa
- **Flutter:** `printer_confirmation_screen.dart` muestra banner "Visita X/N en curso"
- **Backend:** migración `005_add_policy_visits.py` + modelo `PolicyVisit`
- **Backend:** endpoints de visitas (generate, list, activate)
- **Admin Web:** `PoliciesPage` con gestión de visitas (generar, activar, ver progreso)
- **Admin Web:** `TechnicianProfilePage` con perfil detallado

---

## Pendiente

- [ ] Fase 6: Despliegue en servidor de producción (VPS/cloud)
- [ ] Modelo ML para estimación de mantenimiento (preparación hecha en backend)
