# Addendum al plan del módulo de riesgo (prevalece sobre `docs/plan_modulo_riesgo.md`)

Fecha: 2026-11-02. Presentación TT2: 2026-11-17. Este documento corrige y completa el plan con datos reales de la VPS y de producción.

## 1. Hechos verificados

| Tema | Hecho | Implicación |
|---|---|---|
| Servicio | `servicios-backend.service`, `User=root`, `WorkingDirectory=/opt/app/server`, `ExecStart=/opt/app/server/venv313/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000`, **un solo proceso** (sin `--workers`), sin `EnvironmentFile` | El README del repo (`smp-api.service`, `/opt/smp/server`, 4 workers) está desactualizado. La config se lee por `env_file=".env"` relativo al directorio de trabajo, así que **toda unidad nueva (timer/CLI) debe tener `WorkingDirectory=/opt/app/server`**. |
| Alembic | `015 (head)` en la VPS | La 016 es la siguiente. No hay riesgo de stamp. |
| Python VPS | `venv313` es **Python 3.12.3** (el nombre engaña) | `pip install --dry-run` confirma que scikit-learn 1.9.1, numpy 2.5.4, pandas 3.1.0, scipy 1.18.1 instalan en 3.12. Local es 3.13: documentarlo. |
| Recursos | 7.9 GB RAM (6 GB disponibles), 2 núcleos, 80 GB libres | Sin problema de memoria. Mantener `n_jobs=1`. |
| Estados de `reports.status` | Solo `signed` (169) y `Signed` (107); 276 en total | La lista blanca de la Fase B cubre todo. No existen `Synced` ni `pending_*` en el servidor. |
| `service_type` | Preventivo 214, Diagnóstico 31, Correctivo 27, Instalación 4 | Coinciden con las etiquetas canónicas. |
| Modelos | `model_name` y `dpi` separados; duplicados por mayúsculas (`220XI4` / `220xi4`); aparatos no Zebra en `printers` (HP LaserJet 4250n, HP LaserJet 600 M601, OfficeJet Pro 7740, DVR, Microline 691) | Normalizar a mayúsculas y **excluir lo que no sea Zebra** del cálculo. |
| Contador | 22 de 276 reportes (8 %) con `linear_inches_counter = 0`; máximo 158 188 148 | Tratar `0` como dato faltante (`NULL`). En el Excel de Aurora esos casos eran `NaN`. |
| Checklists | 0 de 276 vacíos | La derivación de daños es confiable. |
| Cobertura | 101 impresoras activas: 5 con 0 reportes, 29 con 1, 18 con 2, 49 con 3 o más | Más de la mitad tendría historial corto usando solo la app. |
| Reportes de la app | 2026-04-28 → 2026-10-30 | La app no tiene el historial 2023 → abril 2026. |
| Excel de Aurora vs base | De 59 seriales del Excel, 57 existen en la app; 43 tienen 3+ reportes en la app; la app tiene 191 reportes de esos equipos frente a 426 visitas en el Excel; en 32 equipos el Excel tiene más historia. Del Excel, 274 visitas son anteriores a 2026-04-28 y 152 posteriores | El modelo se entrenó con historial que **no está en la base**. Sin ese historial, `n_visita`, `acum_*` y `fallas_previas_acum` salen sistemáticamente bajos (desajuste de distribución) y el riesgo se subestima. |
| Umbrales 2 vs 5 semillas | Medido: ALTO real 28.9 % (cabezal) y 32.7 % (rodillo) frente al 30 % objetivo; correlación de rangos 0.999 | **No se cambia.** Se documenta como limitación. Sin reentrenar, sin `.joblib` nuevo, las métricas del TT no cambian. |

## 2. Decisiones nuevas

- **D-11. Historial anterior a la app = CSV versionado en git**, no tabla. Archivo `server/app/risk/data/historico_visitas.csv` (copia de `modulo_riesgo/datos_ejemplo/base_visitas_min.csv`). Solo lectura, 426 filas. Sin migración. Confirmar que el repositorio es privado (trae seriales de clientes).
- **D-12. Regla de combinación por impresora**: sea `corte` = fecha mínima de los reportes elegibles de la app para esa impresora. Se usan las filas del CSV con `fecha < corte - 2 días`; desde `corte` manda la app. Si la impresora no tiene reportes en la app, no se calcula (no existe en el sistema o no tiene visitas): solo se calcula para impresoras que existen en `printers`. El margen de 2 días evita duplicar una visita que está en ambos lados (`service_date` se guarda en UTC; el Excel está en fecha local).
- **D-13. Orden de visitas**: filas del CSV conservan su `fila_origen`; las de la app reciben `1_000_000 + cumcount` por equipo, así siempre van después.
- **D-14. Impresoras que no son Zebra**: no se puntúan. Primero buscar en `catalog_models` si hay marca o tipo; si no, usar una constante `MODELOS_EXCLUIDOS` (prefijos o patrones: `HP`, `LASERJET`, `OFFICEJET`, `MICROLINE`, `DVR`) en `app/risk/queries.py`, configurable, con log de lo excluido. No excluir `GC420t`, `ZD*`, `ZQ*`, `ZE500`, `105 SL PLUS`, `ZM400` (son Zebra; el modelo los trata como familia `otros`, igual que en el entrenamiento).
- **D-15. Contador `0` → `NULL`** en la consulta.
- **D-16. Nombre de modelo**: `f"{model_name.strip().upper()}-{dpi}dpi"`. `normalizar_tipo_servicio` debe reconocer variantes por prefijo (`diagn…`) porque el CSV de Aurora trae `Diagn�stico` con el carácter de reemplazo U+FFFD.
- **D-17. Supuestos por defecto** (cambiar solo si Victor lo dice): `.joblib` versionado en git; job diario a las 03:00; portal de clientes apagado (`PORTAL_RISK_ENABLED=false`); técnicos y Flutter sin cambios; sin tabla de historial de predicciones.
- **D-18. Fase C**: los endpoints de refresh son `def` (no `async def`) para que FastAPI los ejecute en un hilo y no bloqueen el único proceso de uvicorn. El lock `pg_try_advisory_xact_lock` se conserva.
- **D-19. Timer systemd** (plantillas): `User=root` (igual que el backend), `WorkingDirectory=/opt/app/server`, `ExecStart=/opt/app/server/venv313/bin/python -m app.risk.refresh --all`, `Nice=10`, `After=servicios-backend.service`, timer diario 03:00 con `Persistent=true`.

## 3. Calendario sugerido (15 días)

| Días | Fase |
|---|---|
| 1–4 | A (módulo vendorizado y corregido) |
| 4–7 | B (datos + historial + endpoints admin + diagnóstico) |
| 7–9 | C (snapshots, botón, job) y despliegue |
| 9–13 | D (pantallas admin) |
| 13–15 | Colchón, ensayo de la demo. E (portal) queda construida pero apagada |

## 4. Prompts ajustados

Todos asumen: leer primero `CLAUDE.md`, `.claude/context/project-status.md`, `docs/plan_modulo_riesgo.md` y este addendum (**si hay contradicción, manda este addendum**); no hacer commit/push ni `git stash`; no tocar `lib/` (Flutter), `app_database.dart`, sync ni Drift; no ejecutar nada contra la VPS ni producción; correr pruebas con `cd server && venv313\Scripts\python -m pytest -p no:cacheprovider tests`; actualizar los archivos de contexto al terminar.

### Prompt — Fase A
```
Fase A del módulo de riesgo. Lee docs/plan_modulo_riesgo.md (§4 Fase A, §1.1) y docs/plan_modulo_riesgo_addendum.md (manda el addendum).
Antes de escribir código: corre la suite completa del servidor con `-p no:cacheprovider` y reporta cuántas pruebas pasan/fallan (línea base). Si algo ya falla, no lo arregles; solo repórtalo.
Objetivo: vendorizar el módulo de Aurora en server/app/risk/ y corregir sus problemas, SIN integrarlo a la app y SIN reentrenar ni generar un .joblib nuevo.
1. Crea server/app/risk/{__init__,datos,modelo,entrenar_cli}.py a partir de modulo_riesgo/modulo_riesgo/*.py (NO copies api.py ni ejemplo_app.py). No modifiques la carpeta modulo_riesgo/.
2. Correcciones:
   a) preparar_visitas: pd.to_numeric(errors="coerce").fillna(0).astype(int) para piezas/sensores/mantenimiento/calibracion/falla; contador_1 numérico (NaN permitido); ValueError claro si faltan columnas; predecir() con DataFrame vacío devuelve []; los int() de acum_* no pueden fallar por NaN.
   b) normalizar_tipo_servicio(): strip + casefold + quitar acentos; mapear por prefijo (preventivo, correctivo, diagn…, instal…) a Preventivo/Correctivo/Diagnóstico/Instalación (el CSV de ejemplo trae "Diagn�stico"); usarlo en matriz_X (hoy datos.py:76 compara exacto con 'Correctivo'). También fam() debe operar sobre el modelo en mayúsculas.
   c) predecir() agrega `vigente: bool` (fecha de referencia inyectable, por defecto hoy).
   d) METRICAS_REF: deja de ser una constante con texto "59 equipos" escrito a mano; calcula lo que se pueda dentro de entrenar() y guarda en el artefacto los datos de la corrida (n equipos, n visitas, PR-AUC de validación). No cambies cómo se calculan los umbrales (SEMILLAS / [:2]): está medido que el efecto es despreciable (ALTO real 28.9 %/32.7 % vs 30 %); déjalo documentado en un comentario y en MODEL_CARD.md.
   e) Quita warnings.filterwarnings('ignore'). Al cargar el modelo, fija n_jobs=1 en cada estimador.
   f) cargar() lanza ModeloNoDisponible (con causa) si el archivo falta o joblib falla por versión.
3. server/requirements-ml.txt: numpy, pandas, scikit-learn==1.9.1, joblib (la VPS es Python 3.12.3; el entorno local puede ser 3.13). NO toques server/requirements.txt ni main.py.
4. Copia modulo_riesgo/modelos/modelo_riesgo.joblib a server/ml_models/modelo_riesgo.joblib (SE VERSIONA en git; no lo agregues a .gitignore) y crea server/ml_models/MODEL_CARD.md corto (versión, fecha de entrenamiento, sklearn 1.9.1, métricas del README del módulo, limitaciones, nota de umbrales).
5. Pruebas en server/tests/ con pytest.importorskip("sklearn") (la suite debe seguir verde sin sklearn): las 6 originales adaptadas; NaN en cabezal/rodillo de la última visita; DataFrame vacío; tipo_servicio ('correctivo', ' Correctivo ', 'CORRECTIVO', 'Diagnostico', 'Diagn�stico') con índices idénticos al canónico; vigente True/False; el artefacto cargado funciona con n_jobs=1.
6. Corre toda la suite y reporta el resultado real. Nada contra producción.
```

### Prompt — Fase B
```
Fase B del módulo de riesgo. Lee docs/plan_modulo_riesgo.md (§1.3, §4 Fase B) y docs/plan_modulo_riesgo_addendum.md (manda el addendum, sobre todo D-11 a D-16). Requiere Fase A.
Objetivo: construir el DataFrame de visitas combinando el historial anterior a la app (CSV) con los reportes reales, y exponer endpoints admin protegidos, sin persistencia ni migración.
1. Copia modulo_riesgo/datos_ejemplo/base_visitas_min.csv a server/app/risk/data/historico_visitas.csv (solo lectura). Avísame si detectas que el repo es público.
2. server/app/risk/queries.py:
   - Consulta de reportes elegibles: status IN ('signed','Signed','Synced','pending_delivery','pending_group_signature') (lista blanca; todo lo demás queda fuera), excluir reportes con supersedes_report_id apuntando a ellos, solo impresoras activas, orden determinista (serie, service_date, created_at, id). Nunca partas de pólizas.
   - Columnas COLS exactas: numero_serie=Printer.serial_number; fecha=service_date (solo fecha); modelo=f"{model_name.strip().upper()}-{dpi}dpi"; tipo_servicio normalizado; contador_1=linear_inches_counter con 0 -> NULL; mantenimiento/calibracion/rodillo/cabezal/sensor_ribbon/sensor_papel desde technical_checkboxes con json.loads defensivo y criterio `is True` (claves "Mantenimiento general", "Calibración sensores", "Rodillo dañado", "Cabezal dañado", "Sensor ribbon dañado", "Sensor papel dañado"); falla=1 si algún daño; fila_origen=1_000_000+cumcount por equipo.
   - Historial: carga el CSV una vez (lru_cache) y, por impresora, agrega las filas con fecha < (primer reporte elegible de la app - 2 días). Solo para impresoras que existan en printers. Si una impresora no tiene reportes en la app, usa el CSV completo.
   - Exclusión de no-Zebra: revisa si catalog_models tiene marca/tipo; si no, constante MODELOS_EXCLUIDOS (HP, LASERJET, OFFICEJET, MICROLINE, DVR) configurable. Registra en el log qué se excluyó. NO excluyas GC420t, ZD*, ZQ*, ZE500, 105 SL PLUS, ZM400.
3. server/app/risk/service.py: carga perezosa del modelo (imports de numpy/pandas/sklearn dentro de funciones), caché por (ruta, mtime), ModeloNoDisponible -> HTTP 503 en español; calcular(db, printer_ids|None).
4. server/app/risk/diagnostico.py (CLI de solo lectura, `python -m app.risk.diagnostico`): por impresora, nº de visitas de la app, del CSV y combinadas; lista de equipos con filas del CSV a ±3 días del primer reporte de la app (posible duplicado, para revisión manual); conteo de historial_corto; distribución de niveles ALTO/MEDIO/BAJO por pieza; y comparación con modulo_riesgo/ejemplo_respuesta.json para los equipos en común (solo informativa, las fechas de corte difieren).
5. server/app/api/routers/risk_admin.py (prefix /api/admin/risk, TODOS con Depends(require_admin), handlers `def`): GET /model/info, GET /printers (level, piece, client_id, limit), GET /printers/{printer_id}. Schemas Pydantic v2 en server/app/schemas/risk.py con vigente y aviso.
6. main.py: un solo include_router con try/except ImportError (la app arranca sin sklearn). Settings: risk_model_path: str = "" (por defecto server/ml_models/modelo_riesgo.joblib) y risk_enabled: bool = True, ambos con default; no exijas nada en .env (extra_forbidden).
7. Pruebas: (i) paridad: reportes ORM sembrados desde el CSV de Aurora, sin historial, dan los mismos índices que predecir() directo; (ii) combinación: partir el CSV en una fecha, sembrar la parte posterior en ORM y la anterior como historial -> mismos índices que con el CSV completo; (iii) sin duplicados con el margen de 2 días; (iv) contador 0 -> NULL; (v) no-Zebra excluido; (vi) 401 sin token, 403 con token de técnico y de portal; (vii) 503 sin modelo y con risk_enabled=False; (viii) la app arranca sin sklearn (monkeypatch de ImportError); (ix) una impresora en dos pólizas no duplica datos; (x) Draft/Deleted/superseded fuera. Suite completa en verde. Sin migraciones. Sin tocar lib/.
```

### Prompt — Fase C
```
Fase C del módulo de riesgo. Lee docs/plan_modulo_riesgo.md (§3 D-3 a D-6, §4 Fase C) y docs/plan_modulo_riesgo_addendum.md (manda el addendum, sobre todo D-18 y D-19). Requiere Fases A y B.
1. Modelo SQLAlchemy PrinterRiskSnapshot en server/app/models/risk.py con el esquema de D-4 (PK String UUID, UniqueConstraint(printer_id, piece)); regístralo en app/models/__init__.py.
2. Migración server/alembic/versions/016_printer_risk_snapshots.py (revision "016", down_revision "015"; la VPS está en 015 head). IDEMPOTENTE: sa.inspect(op.get_bind()).has_table(...) antes de crear tabla/índices (main.py hace create_all al arrancar). downgrade = drop_table. NO la ejecutes contra producción; pruébala solo en una BD local descartable: upgrade, downgrade, upgrade, y upgrade con la tabla ya creada por create_all.
3. server/app/risk/snapshots.py: upsert por (printer_id, piece); calcular vigente/stale/modelo_desactualizado al leer. `stale` = existe un reporte elegible posterior a last_report_id.
4. Endpoints admin (handlers `def`, NO `async def`: la VPS corre un solo proceso uvicorn y no debe bloquearse): GET lee desde snapshot (no calcula); POST /api/admin/risk/printers/{printer_id}/refresh y POST /api/admin/policies/{policy_id}/risk/refresh (impresoras vía PolicyPrinter con el policy_id dado, sin firstOrNull; valida póliza no eliminada). Síncronos; pg_try_advisory_xact_lock solo si el dialecto es postgresql (409 si ocupado); responde con los snapshots y computed_at; computed_by=id del usuario.
5. server/app/risk/refresh.py: `python -m app.risk.refresh --all | --printer <id>`; salida != 0 si falla; logging claro; no escribe en reports.
6. deploy/systemd/smp-risk-refresh.service y .timer (plantillas): User=root, WorkingDirectory=/opt/app/server (el .env se carga por ruta relativa), ExecStart=/opt/app/server/venv313/bin/python -m app.risk.refresh --all, Type=oneshot, Nice=10, After=servicios-backend.service; timer diario 03:00 con Persistent=true. No toques servicios-backend.service.
7. Pruebas: refresh por impresora y por póliza; impresora en 2 pólizas; llamada concurrente (409); job --all idempotente; sin modelo 503; migración idempotente; POST exige admin. Suite completa en verde.
8. En server/README.md corrige la sección de despliegue con los datos reales (servicios-backend.service, /opt/app/server, venv313 = Python 3.12, un solo proceso) y agrega los pasos: git pull --ff-only; pip install -r requirements-ml.txt; alembic upgrade head; systemctl restart servicios-backend; instalar timer; rollback (alembic downgrade 015, quitar variables nuevas del .env antes de volver a una versión anterior).
```

### Fases D y E
Sin cambios de fondo respecto al plan original. En D, mostrar en el detalle "Historial: N visitas de la app + M históricas" (dato que sale del snapshot/inputs) y el indicador "hay reportes más nuevos que este cálculo". E queda detrás de `PORTAL_RISK_ENABLED=false`.

## 5. Preguntas que siguen abiertas (con el supuesto por defecto de D-17)
1. ¿El repositorio es privado? (el CSV trae seriales de clientes).
2. ¿El `.joblib` entra a git? (por defecto sí).
3. ¿Aurora puede confirmar que el Excel (`base_visitas_min.csv`) es la misma fuente que alimenta su análisis del TT, y que sus 2026 corresponden a visitas que también están en la app?
