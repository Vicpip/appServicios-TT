# Servicios Main PC — Backend API

Backend de sincronización para la app móvil industrial_service_reports.

## Stack
- Python 3.10+
- FastAPI 0.111
- SQLAlchemy 2.0 + Alembic
- PostgreSQL 14+

## Instalación en Ubuntu 22.04

### 1. Dependencias del sistema
```bash
sudo apt update
sudo apt install -y python3.10 python3.10-venv python3-pip postgresql postgresql-contrib libpq-dev
```

### 2. PostgreSQL — crear base de datos
```bash
sudo -u postgres psql -c "CREATE USER smp_user WITH PASSWORD 'changeme';"
sudo -u postgres psql -c "CREATE DATABASE smp_db OWNER smp_user;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE smp_db TO smp_user;"
```

### 3. Entorno virtual e instalación
```bash
cd server/
python3.10 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

### 4. Variables de entorno
```bash
cp .env.example .env
# Editar .env con tus valores reales
nano .env
```

### 5. Directorio de uploads
```bash
sudo mkdir -p /var/smp/uploads
sudo chown $USER:$USER /var/smp/uploads
```

### 6. Migraciones
```bash
alembic upgrade head
```

### 7. Levantar el servidor
```bash
# Desarrollo
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# Producción
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4
```

## Endpoints principales

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/` | Info de la API |
| GET | `/docs` | Swagger UI |
| GET | `/api/health` | Health check |
| POST | `/api/reports` | Sincronizar un reporte |
| POST | `/api/reports/bulk` | Sincronizar múltiples reportes |
| POST | `/api/files` | Subir archivo (foto/firma) |

## Servicio systemd (producción)

Datos reales de la VPS (verificados; la versión anterior de esta sección describía `smp-api.service`, `/opt/smp` y 4 workers, y ya no aplica):

| Concepto | Valor |
|---|---|
| Unidad | `servicios-backend.service` |
| Usuario / directorio | `User=root`, `WorkingDirectory=/opt/app/server` |
| Ejecutable | `/opt/app/server/venv313/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000` |
| Procesos | **uno solo** (sin `--workers`): un endpoint lento bloquea a todos; por eso los handlers de riesgo son `def` |
| Python | `venv313` es **Python 3.12.3** (el nombre engaña); en desarrollo local es 3.13 |
| Configuración | `.env` leído por ruta **relativa** (sin `EnvironmentFile`): toda unidad nueva debe tener `WorkingDirectory=/opt/app/server` |
| Alembic | head en la VPS antes de este cambio: `015` |

```bash
sudo systemctl status servicios-backend
journalctl -u servicios-backend -n 100
```

## Módulo de riesgo de piezas — despliegue en la VPS

Archivos que **no** viajan por git (el repositorio es público): el modelo `.joblib` y el CSV histórico de visitas. Se instalan a mano.

**Orden obligatorio** (no lo alteres: las variables `RISK_*` van al final, porque `Settings` prohíbe variables desconocidas y la versión vieja del código fallaría con `extra_forbidden`):

```bash
cd /opt/app/server
# 1. Código (solo avance rápido; si falla, no hagas merge ni stash: revisa qué cambió en la VPS)
git pull --ff-only

# 2. Dependencias de ML (scikit-learn 1.9.1 en Python 3.12)
venv313/bin/pip install -r requirements-ml.txt
venv313/bin/python -c "import sklearn; print(sklearn.__version__)"     # 1.9.1

# 3. Modelo (desde tu equipo; está en server/ml_models/ y está en .gitignore)
#    scp server/ml_models/modelo_riesgo.joblib <usuario>@<vps>:/opt/app/server/ml_models/
#    El directorio debe existir: mkdir -p /opt/app/server/ml_models

# 4. CSV histórico (datos de clientes: permisos 600)
#    install -m 600 historico_visitas.csv /opt/app/server/app/risk/data/historico_visitas.csv

# 5. Migración 015 -> 016 (crea printer_risk_snapshots; es idempotente)
venv313/bin/alembic current        # debe decir 015; si no, DETENTE y revisa antes de seguir (no uses stamp a ciegas)
venv313/bin/alembic upgrade head

# 6. Reiniciar el backend y revisar el arranque
sudo systemctl restart servicios-backend
journalctl -u servicios-backend -n 100

# 7. SOLO AHORA, si hace falta, agregar variables RISK_* al .env y reiniciar otra vez (ver tabla)

# 8. Primer cálculo y timer diario
cd /opt/app/server && venv313/bin/python -m app.risk.refresh --all
sudo cp deploy/systemd/smp-risk-refresh.service deploy/systemd/smp-risk-refresh.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now smp-risk-refresh.timer
sudo systemctl start smp-risk-refresh.service && journalctl -u smp-risk-refresh -n 50
```

Todas las variables son opcionales y tienen valor por defecto: no se exige nada en `.env`.

| Variable | Defecto | Para qué |
|---|---|---|
| `RISK_ENABLED` | `true` | Apaga el módulo (los POST y `model/info` responden 503) |
| `RISK_MODEL_PATH` | vacío = `server/ml_models/modelo_riesgo.joblib` | Ruta del modelo |
| `RISK_HISTORICO_PATH` | vacío = `server/app/risk/data/historico_visitas.csv` | Ruta del CSV histórico |
| `RISK_PERMITIR_SIN_HISTORICO` | `false` | Si es `true`, calcula sin CSV (subestima el riesgo; deja un WARNING) |
| `RISK_INFERIR_DANO_EN_NOTAS` | `true` | Cabezal/rodillo también por las notas del reporte |
| `RISK_SERIES_EXCLUIDAS` | vacío | Números de serie de demo/prueba, separados por coma. Ej.: `RISK_SERIES_EXCLUIDAS=<serie1>,<serie2>` |
| `RISK_CLIENTES_EXCLUIDOS` | vacío | Nombres (como están en `clients.name`) de clientes de prueba, separados por coma. Ej.: `RISK_CLIENTES_EXCLUIDOS=<cliente de prueba>`. Solo va en `.env`, nunca en el código |

**Qué hace cada pieza**
- `GET /api/admin/risk/printers[/{id}]` **lee** snapshots; no calcula. `POST /api/admin/risk/printers/{id}/refresh` y `POST /api/admin/policies/{policy_id}/risk/refresh` recalculan y guardan (síncronos; 409 si ya hay otro refresh, 503 sin modelo o sin historial).
- `python -m app.risk.refresh --all | --printer <id>`: el mismo cálculo desde la consola. Salida `0` ok, `1` fallo, `75` otro refresh en curso. Solo escribe en `printer_risk_snapshots`.
- `deploy/systemd/smp-risk-refresh.{service,timer}`: plantillas (User=root, WorkingDirectory=/opt/app/server, Nice=10, diario 03:00, `Persistent=true`). No modifican `servicios-backend.service`.
- Tras reentrenar o reemplazar el `.joblib`, corre `refresh --all` una vez: los snapshots con otra versión salen marcados como `modelo_desactualizado`.

**Rollback**
```bash
sudo systemctl disable --now smp-risk-refresh.timer
# quitar del .env TODAS las variables RISK_* ANTES de volver a una versión anterior del código (extra_forbidden)
venv313/bin/alembic downgrade 015          # solo borra printer_risk_snapshots
git checkout <commit-anterior>             # nunca reset --hard ni stash en la VPS
sudo systemctl restart servicios-backend
```
Palanca rápida sin redeploy (solo si el código desplegado ya conoce el campo): `RISK_ENABLED=false` en `.env` y reiniciar.
