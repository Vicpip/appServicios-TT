# Módulo de riesgo — progreso

## Módulo de riesgo - estado

**Fases terminadas:** A (módulo de Aurora vendorizado y corregido en `server/app/risk/`), B (datos reales + historial + endpoints admin + diagnóstico) y C (snapshots, refresh, job; solo local, sin commit ni despliegue). Sin migraciones, sin reentrenar, sin tocar Flutter, sync ni Drift. Cambios **sin commitear** (la Fase A sí quedó en el commit local `00c1a62`).
**Rama:** `feature/modulo-riesgo` (creada desde `main`; no existe en el remoto).

**Suite (2026-11-03):** línea base 204 pasadas / 0 falladas.
- `venv313` del repo (sin scikit-learn): **218 pasadas, 5 omitidas, 0 falladas** (las 204 + 14 nuevas que no necesitan numpy).
- Python 3.12.8 + scikit-learn 1.9.1 (venv aparte, fuera del repo): **286 pasadas, 0 omitidas, 0 falladas**.

### Fase A (resumen)
`server/app/risk/{__init__,datos,modelo,entrenar_cli}.py`, `server/ml_models/{modelo_riesgo.joblib,MODEL_CARD.md}`, `server/requirements-ml.txt`, `server/tests/test_risk_modelo.py`. Imports de numpy/pandas/sklearn perezosos; `ModeloNoDisponible` en `app/risk/__init__.py`; umbrales sin tocar (documentado en `MODEL_CARD.md`).

### Fase B
**Archivos:** `server/app/risk/{queries,service,diagnostico}.py`, `server/app/api/routers/risk_admin.py`, `server/app/schemas/risk.py`, `server/tests/{test_risk_api,test_risk_datos,risk_sintetico}.py`; `config.py` (campos nuevos con default) y `main.py` (un `include_router` con `try/except ImportError`).

**Endpoints (todos `require_admin`, handlers `def`, calculan al vuelo, sin persistencia):**
`GET /api/admin/risk/model/info`, `GET /api/admin/risk/printers?level=&piece=&client_id=&limit=`, `GET /api/admin/risk/printers/{printer_id}`.

**Decisiones**
- Visita = `Report`. Lista blanca de estados: `signed, Signed, Synced, pending_delivery, pending_group_signature`; se excluyen reportes reemplazados (`supersedes_report_id`), impresoras inactivas y no Zebra (`MODELOS_EXCLUIDOS`, configurable por parámetro). Contador 0 → NaN. Modelo = `NOMBRE-MAYÚSCULAS-{dpi}dpi`.
- Historial anterior a la app (D-11/D-12): por impresora, filas del CSV con `fecha < primer reporte de la app − 2 días`; las filas de la app llevan `fila_origen = 1_000_000 + n`. Solo se puntúan impresoras que existen en `printers`.
- **El repo es público: el CSV histórico y `modulo_riesgo/` NO se versionan** (están en `.gitignore`). Ruta configurable con `RISK_HISTORICO_PATH` (vacío = `server/app/risk/data/historico_visitas.csv`).
- **Nunca se calcula en silencio sin historial:** si falta el CSV, los endpoints de cálculo responden 503 con mensaje en español (sin rutas); `model/info` sigue respondiendo con `historico_cargado=false` y `n_filas_historico=0`. `RISK_PERMITIR_SIN_HISTORICO=true` (default `false`) permite calcular sin historial y deja un WARNING en el log. El futuro refresh (Fase C) debe respetar lo mismo.
- Settings nuevos, todos con default y sin exigir nada en `.env`: `risk_enabled`, `risk_model_path`, `risk_historico_path`, `risk_permitir_sin_historico`.
- Pruebas con historial **sintético** (`SN-TEST-001…`, `tests/risk_sintetico.py`, datos inventados con semilla fija); las pruebas contra el CSV real de Aurora se omiten si el archivo no existe. Ningún serial real en archivos versionables.
- Token de portal en `/api/admin/risk/*`: `require_admin` lo rechaza con 401 (igual que todo `/api/admin`), no 403; el de técnico sí da 403.

### Mapeo por notas y decisiones (2026-11-04)
- Criterio de Aurora para cabezal/rodillo implementado en `server/app/risk/notas.py` (checklist O notas; `RISK_INFERIR_DANO_EN_NOTAS`, default true). Validación y paridad: ver `MODEL_CARD.md`.
- Las 20 visitas de la app que el Excel no trae **se conservan**. Contadores sin limpieza: Excel para el histórico, base para la app.
- `RISK_CLIENTES_EXCLUIDOS` (nombres separados por coma, solo en `.env`) saca del cálculo a los clientes de prueba; el log solo cuenta, no escribe nombres.

### Fase C (2026-11-04, local, sin commit)
**Archivos:** `server/app/models/risk.py` (`PrinterRiskSnapshot`, registrado en `models/__init__.py`), `server/alembic/versions/016_printer_risk_snapshots.py`, `server/app/risk/snapshots.py`, `server/app/risk/refresh.py`, `server/deploy/systemd/smp-risk-refresh.{service,timer}`, `server/tests/test_risk_snapshots.py`; modificados `risk_admin.py`, `schemas/risk.py`, `risk/queries.py`, `risk/service.py`, `risk/modelo.py` (parámetro opcional `con_entradas`), `tests/test_risk_api.py` y `server/README.md` (sección de despliegue reescrita con datos reales de la VPS y orden de pasos). `main.py` y `config.py` sin cambios.

**Endpoints (todos `require_admin`, handlers `def`):**
- `GET /api/admin/risk/printers` y `/printers/{id}` ahora **leen snapshots, no calculan** (cambio de comportamiento respecto a la Fase B; `model/info` igual). Nuevos campos: `vigente`, `stale`, `modelo_desactualizado`, `computed_at`, `computed_by`, `dano_detectado_en_notas` por pieza, `sin_calcular` (candidatas sin snapshot, incluye las que no tienen visitas). Leer funciona aunque el modelo no esté disponible (entonces `version_modelo=null` y `modelo_desactualizado=false`).
- `POST /api/admin/risk/printers/{id}/refresh` y `POST /api/admin/policies/{policy_id}/risk/refresh` (póliza no eliminada; impresoras vía `PolicyPrinter` del `policy_id`; cada impresora una sola vez). 409 si hay otro refresh (`pg_try_advisory_xact_lock` solo en PostgreSQL), 503 sin modelo/historial, 404 si no existe/no aplica.
- CLI: `python -m app.risk.refresh --all | --printer <id>`; salida 0 ok, 1 fallo, 75 ocupado. Solo escribe `printer_risk_snapshots`; los logs llevan conteos, no seriales ni clientes.

**Decisiones**
- `stale` = el último reporte elegible actual es distinto de `last_report_id` (incluye "hay uno posterior"; también salta si el último dejó de ser elegible). Un reporte con fecha de servicio anterior al último, sincronizado después, no lo marca.
- `inputs_json` guarda solo números: variables de la última visita que vio el modelo, `visitas_app`, `visitas_historicas` y `dano_solo_notas` {cabezal, rodillo}. Sin notas, sin serie, sin modelo/tipo en texto.
- La migración 016 es idempotente (crea tabla e índice solo si faltan); downgrade = drop_table.

**Contradicciones encontradas (mandó el prompt):**
1. Addendum: `.joblib` versionado (D-17 / Fase A) y CSV en git (D-11) → no se versionan; pruebas se omiten sin el `.joblib`.
2. Plan D-4: `inputs_json` con serie, modelo normalizado, tipo normalizado → solo variables numéricas (+ conteos de visitas e indicador de notas).
3. Addendum paso 6: plantillas en `deploy/systemd/` (raíz) → quedaron en `server/deploy/systemd/` (ruta permitida).
4. Addendum: la VPS "se cae" a 015 y `down_revision` 015; coherente. Pero D-6 del plan habla de 4 workers/`EnvironmentFile` (obsoleto): el README ya describe un solo proceso y `.env` por ruta relativa.
5. Plan §4 Fase C pide "lectura desde snapshot"; el progreso de la Fase B decía que el refresh debe respetar el 503 sin historial: se respeta (POST y job).

**Pruebas:** la migración se probó con Alembic sobre SQLite (sube, baja, sube, sube con tabla creada por `create_all`). **No** se probó contra PostgreSQL: no había una BD descartable local (el `.env` apunta a una Postgres que no es descartable, no se tocó).

### Puntos abiertos
- **`modulo_riesgo/` (con el CSV real y `ejemplo_respuesta.json`) ya está en el commit local `00c1a62`.** `.gitignore` no destrackea: antes de cualquier push hay que `git rm -r --cached modulo_riesgo` y reescribir ese commit (o la rama) para que los seriales no queden en el historial. La rama aún no está en el remoto.
- **El `.joblib` NO se versiona** (decisión de Victor): queda en `server/ml_models/modelo_riesgo.joblib` (ya en `.gitignore`) y se copia a la VPS con `scp`. Las pruebas que lo cargan se omiten con mensaje claro si no existe.
- El `.joblib` conserva `metricas_referencia` viejas ("59 equipos", PR-AUC 0.607/0.436); la guardada de la corrida es 0.609 / 0.459. Decidir cuáles cita el TT.
- La VPS necesita el CSV histórico copiado a mano (no viene en git) o `RISK_HISTORICO_PATH` apuntando a él.
- Marca (`catalog_models.brand`) solo se usa vía `MODELOS_EXCLUIDOS`; no se verificó cómo está capturada en producción.
- 2 filas del CSV real tienen contador 0 (se dejan tal cual, como en el entrenamiento).
- `server/venv313` local es Python 3.13 sin scikit-learn; en la VPS es Python 3.12.3. Para las pruebas de riesgo completas hay que instalar `requirements-ml.txt` o usar un venv aparte.
- Preguntas del addendum §5: repo privado (**resuelta: es público**), `.joblib` en git (**resuelta: no se versiona**), confirmación de Aurora sobre el Excel (**resuelta**: criterio de notas, ver MODEL_CARD).

**Fase siguiente:** despliegue de la Fase C (ver `server/README.md`, orden de pasos) y D (pantallas admin: leer `GET /api/admin/risk/printers`, botón con los POST de refresh, mostrar "Historial: N de la app + M históricas", `stale`, `modelo_desactualizado` y "daño detectado en notas").
