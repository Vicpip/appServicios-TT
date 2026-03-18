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

```bash
sudo nano /etc/systemd/system/smp-api.service
```

```ini
[Unit]
Description=Servicios Main PC API
After=network.target postgresql.service

[Service]
User=ubuntu
WorkingDirectory=/opt/smp/server
Environment="PATH=/opt/smp/server/venv/bin"
EnvironmentFile=/opt/smp/server/.env
ExecStart=/opt/smp/server/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable smp-api
sudo systemctl start smp-api
sudo systemctl status smp-api
```
