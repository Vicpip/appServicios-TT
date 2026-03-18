# industrial_service_reports — Contexto para Claude Code

## Proyecto
App Flutter offline-first para reportes de servicio técnico de impresoras Zebra.
Cliente: Servicios Main PC

## Worktree activo
El proyecto usa git worktrees. Siempre trabajar desde la carpeta raíz del worktree actual.

## Stack
- Mobile: Flutter + Drift (SQLite) + Riverpod + GoRouter
- Backend: Python 3.14 + FastAPI + SQLAlchemy + PostgreSQL + Alembic
- Admin Web: React + TypeScript + Tailwind CSS + Vite
- Auth: JWT (7 días para móvil)

## Estructura del proyecto
/lib          → App Flutter
/server       → Backend FastAPI
/admin-web    → Panel administrador React
/.claude      → Contexto, agentes, skills y commands

## Archivos de contexto
- .claude/context/project-status.md → Estado completo del proyecto
- .claude/context/sprint2-plan.md → Plan Sprint 2 con tareas pendientes

## Cómo trabajar
1. Leer SIEMPRE .claude/context/project-status.md antes de cualquier tarea
2. Usar los agentes disponibles en .claude/agents/ según la tarea
3. Usar los skills disponibles en .claude/skills/ para mejor calidad
4. Al terminar una tarea, actualizar ambos archivos de contexto
5. No hardcodear IPs — usar constants.dart en Flutter y .env en el servidor

## Comandos para levantar el proyecto
### Backend (Windows)
cd server
venv\Scripts\activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

### Backend (Linux/Mac)
cd server
source venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

### Admin Web
cd admin-web
npm install
npm run dev

### Flutter
Cambiar kServerBaseUrlDevice en lib/core/constants.dart a la IP local de tu PC

## IP del servidor
- Desarrollo: IP local de tu PC (ver con ipconfig en Windows o ifconfig en Mac/Linux)
- Producción: pendiente (ver sprint2-plan.md Fase 6)

## Reglas importantes
- PKs como String (UUIDs) en todos los modelos — compatibilidad con Drift/Flutter
- UPLOAD_DIR=./uploads (relativo, se crea automáticamente)
- Python 3.14 requiere pydantic==1.10.21 y pydantic-settings por separado
- No usar Docker en desarrollo — PostgreSQL nativo
