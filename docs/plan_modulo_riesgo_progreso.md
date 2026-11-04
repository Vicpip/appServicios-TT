# Módulo de riesgo — progreso

## Módulo de riesgo - estado

**Fases terminadas:** A (módulo de Aurora vendorizado y corregido en `server/app/risk/`) y B (datos reales + historial + endpoints admin + diagnóstico). Sin migraciones, sin reentrenar, sin tocar Flutter, sync ni Drift. Cambios **sin commitear** (la Fase A sí quedó en el commit local `00c1a62`).
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

### Puntos abiertos
- **`modulo_riesgo/` (con el CSV real y `ejemplo_respuesta.json`) ya está en el commit local `00c1a62`.** `.gitignore` no destrackea: antes de cualquier push hay que `git rm -r --cached modulo_riesgo` y reescribir ese commit (o la rama) para que los seriales no queden en el historial. La rama aún no está en el remoto.
- **El `.joblib` NO se versiona** (decisión de Victor): queda en `server/ml_models/modelo_riesgo.joblib` (ya en `.gitignore`) y se copia a la VPS con `scp`. Las pruebas que lo cargan se omiten con mensaje claro si no existe.
- El `.joblib` conserva `metricas_referencia` viejas ("59 equipos", PR-AUC 0.607/0.436); la guardada de la corrida es 0.609 / 0.459. Decidir cuáles cita el TT.
- La VPS necesita el CSV histórico copiado a mano (no viene en git) o `RISK_HISTORICO_PATH` apuntando a él.
- Marca (`catalog_models.brand`) solo se usa vía `MODELOS_EXCLUIDOS`; no se verificó cómo está capturada en producción.
- 2 filas del CSV real tienen contador 0 (se dejan tal cual, como en el entrenamiento).
- `server/venv313` local es Python 3.13 sin scikit-learn; en la VPS es Python 3.12.3. Para las pruebas de riesgo completas hay que instalar `requirements-ml.txt` o usar un venv aparte.
- Preguntas del addendum §5: repo privado (**resuelta: es público**), `.joblib` en git (**resuelta: no se versiona**), confirmación de Aurora sobre el Excel (**resuelta**: criterio de notas, ver MODEL_CARD).

**Fase siguiente:** C (snapshots, migración 016 idempotente, botón/refresh por impresora y por póliza, job systemd). Prompt en `docs/plan_modulo_riesgo_addendum.md`, §4 "Prompt — Fase C". Requiere A y B; el refresh debe devolver 503 sin historial salvo `risk_permitir_sin_historico=true`.
