# Plan de integración — módulo de riesgo de piezas (cabezal y rodillo)

> Documento de investigación y plan. **No se modificó ningún archivo de código, no se corrieron migraciones, no se hicieron commits y no se tocó la VPS ni la base de producción.**
> Única verificación ejecutable: las pruebas y sondas del módulo de Aurora se corrieron sobre una **copia** de `modulo_riesgo/` en un venv desechable (Python 3.13.13, scikit-learn 1.9.1, pandas 3.1.0, numpy 2.5.4) ubicado en el scratchpad de la sesión, fuera del repo.
> Fecha: 2026-10-29. Rama: `main`. Último commit: `92482bf`.
> Notación de citas: `ruta:línea`. Cuando algo no pude confirmarlo en el código lo marco **[NO VERIFICADO]** y queda listado en la sección 6.

---

## 0. Resumen ejecutivo

1. El módulo de Aurora funciona (6/6 pruebas pasan, predecir 59 equipos ≈ 0.45 s, 1.8 s de import, ~180 MB RSS por proceso), pero **no es integrable tal cual**: no tiene auth, lee datos con un `Depends` pensado para CSV, y tiene los 6 problemas que listaste (todos confirmados, con matices en §1.1).
2. **De las 13 columnas, 12 se pueden obtener hoy** de `reports` + `printers` + `catalog_models`; `falla` hay que **derivarla** (se verificó sobre el CSV de Aurora que `falla == 1` ⇔ alguno de los 4 daños = 1, en 426/426 filas). **No existe `fila_origen`** (hay que fabricar un orden estable) y **`Report` no tiene `visit_id`**: una "visita de impresora" para el modelo = un `Report`, no un `PolicyVisit`.
3. Recomendación de persistencia: **tabla de snapshot** (una fila por impresora+pieza, upsert), no cálculo al vuelo. Migración Alembic `016` **idempotente** (ver riesgo `create_all` en §2).
4. Recomendación de disparadores: botón **síncrono** (≈0.5–0.7 s) que recalcula **solo las impresoras afectadas** (la predicción es por equipo; se verificó que `predecir(subconjunto) == predecir(todo)`); actualización periódica con **systemd timer + comando CLI**, no APScheduler (el servicio corre con `--workers 4`, `server/README.md:59,89`).
5. Plan en **5 fases desplegables por separado** (A correcciones, B datos+endpoint admin, C persistencia+botón+job, D pantallas admin, E portal). Cada una trae su prompt listo para pegar (§5). Quedan **preguntas abiertas** al final (§7); las tres que más cambian el plan: ¿se muestra el riesgo al cliente en v1?, ¿los reportes sin firmar cuentan?, ¿cómo se llama/dónde está el servicio real en la VPS?

---

## 1. Hallazgos de la investigación

### 1.1 Verificación de los 6 problemas (módulo de Aurora)

Ruta base: `modulo_riesgo/modulo_riesgo/` (el paquete está **sin trackear** en git: `git status` → `?? modulo_riesgo/`; `.gitignore` no tiene regla para `*.joblib`).

| # | Tu afirmación | Resultado | Evidencia |
|---|---|---|---|
| 0 | 6 pruebas pasan | **Confirmado** (6 passed, 5.2 s, copia en scratchpad) | `modulo_riesgo/tests/test_modulo.py` |
| 0 | predecir ~60 equipos < 1 s | **Confirmado**: 0.45 s (59 equipos); subconjunto de 2 equipos 0.7 s (primera llamada, incluye arranque de hilos) | sonda propia |
| 1 | NaN en `cabezal`/`rodillo` truena | **Confirmado, con matiz**: solo truena si el NaN está en la **última** visita del equipo (`ValueError: cannot convert float NaN to integer`). En visitas anteriores el `cumsum` lo salta y no falla. Causa: `modelo.py:84` `int(r['acum_'+pz] - ...)`. NaN en `mantenimiento`, `sensor_*` o `falla` **no** truena (cambia el resultado en silencio). | sonda propia |
| 1 | DataFrame vacío → 500 | **Confirmado**: `ValueError: Found array with 0 sample(s)` desde `modelo.py:75` (`_puntuar`). `api.py` no tiene manejo de excepciones → 500. Además `cabezal` como texto `'0'/'1'` truena en `cumsum` (`TypeError`); como `bool` funciona. | sonda propia |
| 2 | `tipo_servicio` exacto `'Correctivo'` | **Confirmado**: `datos.py:76` `(F.tipo_servicio == 'Correctivo')`. Con `'correctivo'`, `'CORRECTIVO'` o `'Correctivo '` cambian los índices de **11 de 59 equipos** (9 de 59 en el índice de *cabezal* — coincide con tu cifra — y 11 si cuentas cabezal o rodillo), sin error. | sonda propia |
| 3 | Sin autenticación, devuelve todos los clientes | **Confirmado**: `api.py:17` `APIRouter(prefix='/riesgo')` sin dependencias de seguridad; `api.py:72-83` y `85-90` devuelven cualquier equipo. | lectura |
| 4a | `obtener_visitas` lee toda la tabla en cada request | **Confirmado por diseño**: `Depends(obtener_visitas)` en `api.py:76` y `:86` se resuelve antes de entrar a `_predicciones`; la caché (`api.py:59-66`) solo evita `predecir`, no la lectura. | lectura |
| 4b | Caché global de un slot | **Confirmado**: `_cache = {}` con la clave `'p'` (`api.py:58-66`). Con filtros por cliente/impresora se pisaría. | lectura |
| 4c | No detecta ediciones de visitas existentes | **Confirmado**: la clave es `(version, len(V), fecha.max())` (`api.py:60`); editar un reporte (el sync hace upsert, `server/app/api/routers/sync.py:77-137`) no cambia ni el conteo ni la fecha máxima → sirve datos viejos hasta 5 min (`TTL_SEGUNDOS=300`, `api.py:16`). | lectura |
| 5 | `vigente_hasta` vencido en ~17/59 | **Confirmado**: 17 de 59 con fecha de referencia 2026-10-29. No existe campo `vigente` (`modelo.py:77-79`). | sonda propia |
| 6a | `METRICAS_REF` fija, dice "59 equipos" | **Confirmado**: `entrenar_cli.py:26-32` (texto en `:31`), y se inyecta tal cual en el artefacto (`entrenar_cli.py:14`). Los números (PR-AUC 0.607, etc.) se quedarían de un entrenamiento anterior. | lectura |
| 6b | Umbrales con 2 semillas, modelo con 5 | **Confirmado**: `SEMILLAS = 5` (`modelo.py:14`), pero `oof_scores` usa `_ajustar(...)[:2]` (`modelo.py:36`) → los percentiles `umbral_alto/medio` (`modelo.py:54`) salen de un ensamble de 2 y se aplican a uno de 5 (`modelo.py:75`, `_puntuar` con todos). Efecto: los puntajes del ensamble de 5 están ligeramente más concentrados que los del de 2, así que el "30 % ALTO" real no será exactamente 30 %. El artefacto actual sí trae 5 modelos por pieza. | sonda + lectura |

**Hallazgos adicionales sobre el módulo (no estaban en tu lista):**

- `modelo.py:21-22`: `RandomForestClassifier(..., n_jobs=-1)` y el artefacto se guarda con `n_jobs=-1` (verificado). Con `uvicorn --workers 4` cada worker usaría todos los núcleos en cada `predict_proba`. Mitigar fijando `n_jobs=1` al cargar (`m.set_params(n_jobs=1)`).
- `modelo.py:4` `warnings.filterwarnings('ignore')` global al importar: silencia warnings de **toda** la app (incluidos DeprecationWarning de SQLAlchemy/Pydantic) en cuanto se importa el módulo. Quitarlo o acotarlo.
- `modelo.py:56`: la `version` es `sha1(entrenado_en + n_filas)[:8]`; cambia en cada reentrenamiento aunque los datos sean iguales. Sirve como llave de invalidación de snapshots.
- `api.py:42-49`: `lru_cache` por `(ruta, mtime)` — recarga si cambia el archivo; bien, pero **no atrapa** el error de `joblib.load` (versión de sklearn distinta) → 500 con traza en lugar de 503 con mensaje claro.
- `datos.py:35`: `cargar_visitas` con `.xlsx` lee la hoja `base_visitas`. El servidor **no** debería leer Excel/CSV: se reemplaza por consulta SQL (§1.3). `openpyxl` ya está en `server/requirements.txt` pero no hace falta para esto.
- El CSV de ejemplo tiene el texto `Diagnóstico` **corrupto** (`Diagn�stico`, 16 filas): el archivo ya trae el carácter de reemplazo U+FFFD. No afecta al modelo (solo compara contra `'Correctivo'`), pero confirma que la normalización de texto debe ser robusta.
- Datos de entrenamiento (CSV): 426 visitas, 59 equipos, 2023-03-31 → 2026-10-06; **12 visitas del mismo equipo en el mismo día**; `contador_1` con 30 NaN. Hoy el servidor **no puede producir NaN** en el contador (`Report.linear_inches_counter` es `Integer, nullable=False`, `server/app/models/report.py:19`), pero sí puede producir `0` — **[NO VERIFICADO]** si `0` significa "no capturado".
- El `.joblib` (5.3 MB) **no referencia** el paquete `modulo_riesgo` (0 coincidencias binarias) y solo contiene `dict/list/str/int` más objetos de sklearn → se puede **mover/renombrar el paquete** sin romper el unpickle. Esto permite integrarlo como `server/app/risk/`.
- Recursos medidos (Windows, Python 3.13): import de pandas+sklearn+módulo 1.8 s y +153 MB RSS; cargar el modelo +25 MB; total ≈ 180 MB por proceso. Con 4 workers y carga ansiosa serían ≈ 720 MB; con carga perezosa solo se paga en el worker que atienda la petición. **[NO VERIFICADO]** la RAM libre de la VPS.

### 1.2 Backend (`server/`)

- **Stack real**: `server/requirements.txt:1-15` fija `fastapi==0.111.0`, `pydantic==2.7.1`, `pydantic-settings==2.2.1`, `sqlalchemy==2.0.30`, `alembic==1.13.1`. **Pero el `venv313` local tiene `fastapi 0.100.0`, `starlette 0.27.0`, `pydantic 2.11.4`, `pydantic-settings 2.0.3`** (`pip list`) → el venv local no coincide con el archivo de requisitos; **[NO VERIFICADO]** cómo es el de la VPS. (CLAUDE.md dice "Python 3.14 requiere pydantic==1.10.21"; está desactualizado respecto a `requirements.txt` que usa Pydantic 2.)
- **Dependencias nuevas** (`pip install --dry-run` contra `server/venv313`, sin instalar): agregaría `numpy 2.5.4, pandas 3.1.0, scikit-learn 1.9.1, scipy 1.18.1, joblib 1.6.0, threadpoolctl, cloudpickle, narwhals, python-dateutil, tzdata`. **No cambia ningún paquete existente** y `pip check` del venv actual está limpio. Riesgo de choque: bajo. Riesgo real: tamaño (~300–400 MB en disco entre numpy/scipy/pandas/sklearn, **[NO VERIFICADO]** exacto) y RAM.
- **`ml_service.py` no existe.** Solo es un bloque de ejemplo en `.claude/context/project-status.md:933-955` ("Preparación para modelo ML (futuro)"), con `EstimationService.predict_maintenance_date` / `predict_failure_risk`. Nada en `server/` lo importa (`grep -r ml_service` → solo ese .md). Ese bloque dice que el modelo correría "al guardar un reporte" — **este plan lo descarta** (§3, D-6).
- **Arranque**: `server/app/main.py:29-30` hace `Base.metadata.create_all(bind=engine)` en cada arranque → **cualquier modelo nuevo importado en `app/models/__init__.py` se crea solo si no existe**, aunque Alembic no haya corrido. Ver riesgo R-2.
- **Routers** (`main.py:59-65`): `auth`, `sync`, `reports`, `admin`, `portal`, `public`, `files`. No hay scheduler, ni APScheduler, ni `BackgroundTasks` en uso significativo (**[NO VERIFICADO]** exhaustivamente; `grep` de `apscheduler|BackgroundTasks|Thread` no se corrió en todo el árbol — ver §6).
- **Auth/roles**: `server/app/auth.py:66-96` `get_current_active_user` (revisa BD, `is_active`, `token_version`); `:100` `require_internal`; `:103-110` `require_admin` (`role == "admin"`). Roles internos observados: `admin` y `technician` (`server/tests/conftest.py:148-157`). El login web exige admin (`server/app/api/routers/auth.py:106`). **Todos** los endpoints de `admin.py` usan `Depends(require_admin)` (`admin.py:81` router `/api/admin`).
- **Portal**: JWT con `role == "portal_client"`, `client_id`, `plant_id` (`server/app/api/routers/portal.py:122-136`, `portal_auth.py:20-36`). **Scoping existente (reusar)**: `portal.py:141-155` `_scoped_printers_query(portal_user, db, *entities)` — filtra `Printer.client_id == portal_user.client_id`, `Printer.is_active`, y `plant_id` si el usuario está restringido a una planta; `portal.py:158` `_get_printer_ids_in_scope`; `portal.py:187` `_resolve_portal_user`. El detalle por impresora responde 404 si es de otro cliente y **403** si es de otra planta (`portal.py:725-728`) — para riesgo conviene responder 404 en ambos casos para no filtrar existencia.
- **Config**: `server/app/config.py:10-11` `class Settings(BaseSettings)` con `model_config = SettingsConfigDict(env_file=".env")` y **sin `extra=`** → comportamiento por defecto de pydantic-settings: variables desconocidas en `.env` provocan `extra_forbidden` (tu incidente previo). Implicación en rollback: ver R-3.
- **Migraciones**: `server/alembic/versions/` llega a `015_policy_delivery_email_fields.py` (`revision="015"`, `down_revision="014"`, líneas 11-13). La siguiente es **`016`**. El `env.py` importa `app.models` (por eso un modelo nuevo debe registrarse en `app/models/__init__.py`). **Tú mencionas que en la VPS se estampó la `010`** → las `011`–`015` pueden no estar aplicadas allá; **[NO VERIFICADO]** (requiere `alembic current` en la VPS). Ver R-2.
- **Despliegue documentado** (`server/README.md:59`, `:73-95`): unidad `smp-api.service`, `WorkingDirectory=/opt/smp/server`, `.../venv/bin/uvicorn ... --workers 4`, `EnvironmentFile=/opt/smp/server/.env`. **Tú hablas de `servicios-backend.service` y `venv313`** → la documentación del repo y tu VPS no coinciden; hay que confirmar nombre de unidad, ruta y usuario antes de la fase C (§7).

### 1.3 De dónde sale cada columna de `COLS`

Una "visita" para el modelo = **un `Report`** (`server/app/models/report.py:10-35`). `Report` **no tiene `visit_id`**; `PolicyVisit` solo se vincula a reportes vía `PolicyDelivery.visit_id` → `PolicyDeliveryReport` (`server/app/models/policy.py:72`, `:93-108`; `server/app/services/visit_service.py:34-48`). Por eso el estado `in_progress` de un `PolicyVisit` **no** debe filtrar datos de entrada.

| Columna `COLS` | Fuente en el servidor | ¿Existe hoy? | Derivación |
|---|---|---|---|
| `numero_serie` | `Printer.serial_number` (`models/printer.py:14`, `unique=True`) | Sí | `Report.printer_id → Printer.id` (sin FK a nivel BD, `report.py:13-14`; inner join descarta huérfanos) |
| `fila_origen` | — | **No** | Fabricar `ROW_NUMBER() OVER (PARTITION BY printer ORDER BY service_date, created_at, id)`. Aurora ordena por `(fecha, fila_origen)` (`datos.py:32`); en la base hay 12 casos de mismo día |
| `fecha` | `Report.service_date` (`report.py:18`) | Sí | `DateTime`; el modelo usa solo la fecha (`datos.py:31`) → normalizar a fecha |
| `modelo` | `CatalogModel.model_name` + `dpi` (`models/catalog.py:12-13`) vía `Printer.model_id` | Parcial | CSV usa `ZT610-300dpi`; construir `f"{model_name}-{dpi}dpi"`. `fam()` (`datos.py:11-17`) compara por prefijo y es sensible a mayúsculas → normalizar `.upper()`. **[NO VERIFICADO]** el formato real de `model_name` en producción (los tests usan `"ZT411"`, `conftest.py:158-160`); si es `"110Xi4"` caería en `'otros'` sin normalizar |
| `tipo_servicio` | `Report.service_type` (`report.py:16`) | Sí | Valores de la app: `Preventivo, Correctivo, Diagnóstico, Instalación` (`lib/features/reports/providers/capture_provider.dart:4-9`); además aparece sin acento (`printer_detail_screen.dart:751` `'Diagnostico'`) y el admin compara en minúsculas (`admin.py:442-446`). Normalizar (strip + casefold + sin acentos) y mapear a las etiquetas canónicas |
| `contador_1` | `Report.linear_inches_counter` (`report.py:19`) | Sí | **[NO VERIFICADO]** que la unidad (pulgadas lineales) coincida con la columna "contador 1" del Excel de Aurora; es un riesgo de *drift* de distribución |
| `mantenimiento` | `technical_checkboxes["Mantenimiento general"]` | Sí (JSON en `Text`, `report.py:22-24`) | `json.loads`; `is True` → 1; clave ausente → 0 (**ojo**: en entrenamiento 95 % de las filas tienen 1, `conftest` crea reportes con `"{}"`; reportes con checklist vacío serán "mantenimiento=0" y sesgarán) |
| `calibracion` | `technical_checkboxes["Calibración sensores"]` | Sí | ídem |
| `rodillo` | `technical_checkboxes["Rodillo dañado"]` | Sí | ídem. También existe `ReportPart.was_damaged` (`models/report_detail.py:23-38`) pero la app móvil escribe el checklist; **[NO VERIFICADO]** si `ReportPart` se llena en producción |
| `cabezal` | `technical_checkboxes["Cabezal dañado"]` | Sí | ídem |
| `sensor_ribbon` | `technical_checkboxes["Sensor ribbon dañado"]` | Sí | ídem |
| `sensor_papel` | `technical_checkboxes["Sensor papel dañado"]` | Sí | ídem |
| `falla` | — | **No (derivar)** | `1` si alguno de los 4 daños es `True`, si no `0`. Verificado en el CSV: `falla==1 ⇔ rodillo|cabezal|sensor_ribbon|sensor_papel`, 426/426 filas (crosstab sin celdas fuera de diagonal). Coincide con `_DAMAGE_KEYS` de `admin.py:84` y `portal.py:103` |

Claves exactas del checklist: `capture_provider.dart:17-26` → `Mantenimiento general`, `Calibración sensores`, `Rodillo dañado`, `Cabezal dañado`, `Sensor ribbon dañado`, `Sensor papel dañado`, `Pruebas`, `Otros`. El backend ya las consume con `cb.get(k) is True` (`admin.py:106-118`, `portal.py:671-690`) — reutilizar ese mismo criterio.

**Estados de `Report.status`** (no hay enum en el servidor; `report.py:17` es `String`): observados en código — `pending_delivery`, `pending_group_signature`, `signed`/`Signed`, `Synced`, `Draft`, `Deleted` (`reports_screen.dart:80-96`, `visit_service.py:15`, `sync.py:672` excluye `Deleted`). **[NO VERIFICADO]** si `Draft` llega alguna vez al servidor.

**Consulta propuesta (SQLAlchemy 2.0; no ejecutada):**

```python
# app/risk/queries.py  (propuesta)
from sqlalchemy import select, exists, func
from sqlalchemy.orm import aliased

ESTADOS_ELEGIBLES = ("pending_delivery", "pending_group_signature", "signed", "Signed", "Synced")  # lista blanca

def visitas_para_modelo(db, printer_ids: list[str] | None = None):
    Sup = aliased(Report)  # reporte que reemplaza a otro
    q = (
        select(
            Printer.id.label("printer_id"),
            Printer.serial_number.label("numero_serie"),
            Report.id.label("report_id"),
            Report.service_date, Report.created_at,
            Report.service_type, Report.linear_inches_counter,
            Report.technical_checkboxes,
            CatalogModel.model_name, CatalogModel.dpi,
        )
        .join(Printer, Printer.id == Report.printer_id)
        .join(CatalogModel, CatalogModel.id == Printer.model_id)
        .where(
            Printer.is_active.is_(True),
            Report.status.in_(ESTADOS_ELEGIBLES),
            ~exists().where(Sup.supersedes_report_id == Report.id),   # excluir reportes reemplazados
        )
        .order_by(Printer.serial_number, Report.service_date, Report.created_at, Report.id)
    )
    if printer_ids is not None:
        q = q.where(Printer.id.in_(printer_ids))
    return db.execute(q).all()
```

Luego, en Python (no en SQL, porque `technical_checkboxes` es `Text` y las pruebas corren en SQLite): `json.loads` defensivo (`except (JSONDecodeError, TypeError)` como en `admin.py:114-118`), `fila_origen = cumcount()+1` por equipo (el `ORDER BY` ya garantiza orden determinista) y construcción del `DataFrame` con **exactamente** `datos.COLS`.

**Cómo tratar los casos que pediste:**

- **Visitas parciales / split visits**: no hay vínculo directo reporte→visita, así que no se filtra por `PolicyVisit`. Cada `Report` es una visita del equipo; si una póliza se atiende en varias entregas, cada impresora tiene sus propios reportes y el modelo los ve en orden de fecha. Lo único que importa es no contar el mismo servicio dos veces (`supersedes_report_id`, `report.py:29`; el sync lo guarda en `sync.py:104`; **[NO VERIFICADO]** que la app lo use hoy).
- **Visita `in_progress`**: irrelevante para la entrada (es estado de `PolicyVisit`, no de `Report`). Un reporte capturado durante una visita en curso sí cuenta una vez sincronizado.
- **Borradores**: lista blanca de estados excluye `Draft` y `Deleted`; cualquier estado desconocido nuevo queda fuera por defecto (falla cerrada).
- **Sin firmar** (`pending_delivery`, `pending_group_signature`): **se proponen incluidos** porque la observación técnica ya existe aunque el cliente no haya firmado; alternativa (excluirlos) retrasa el riesgo hasta la entrega. **Decisión pendiente tuya** (§7-P3).
- **Una impresora en varias pólizas**: la consulta de datos **no depende de pólizas**. Solo el botón por póliza las usa, y entonces se parte de `policy_id` explícito → `PolicyPrinter` (`models/policy.py:39-54`, helper `visit_service.policy_printer_ids`, `visit_service.py:19-24`), nunca de "la póliza de la impresora". Prohibido `firstOrNull`/`.first()` sobre pólizas. Para "póliza vigente" usar `policy_status.vigente()` (`services/policy_status.py:36-38`, excluye `Deleted` y exige `end_date >= now`). Nota: en Flutter existen varios `firstOrNull` sobre pólizas (`policy_dashboard_screen.dart:484,1582,1966`); este plan no los toca.

### 1.4 Frontend

**admin-web** (React 18 + TS + Vite + Tailwind 3 + TanStack Query 5 + axios + lucide-react + recharts; `admin-web/package.json`):
- Rutas: `admin-web/src/router.tsx:29-41` (hijos de `AppLayout` bajo `ProtectedRoute`). Navegación: `components/layout/Sidebar.tsx:20-27` (array `NAV_ITEMS` con `path, icon, label`).
- Cliente HTTP: `src/api/client.ts:47-55` (axios con `VITE_API_URL`, token por interceptor, `401` → evento `auth:unauthorized`); URLs centralizadas en `src/api/endpoints.ts` (objeto `API`).
- Patrón de datos: `useQuery` con `queryKey` por recurso y `useMutation` + `invalidateQueries` (`PolicyDetailPage.tsx:420-426` visitas; `:482-505` mutaciones; `PrinterDetailPage.tsx:65-97`). `errDetail(err, fallback)` se usa en `PolicyDetailPage.tsx` (definición local; hay que reutilizar/extraer, **[NO VERIFICADO]** dónde está declarada).
- Punto de inserción del botón por visita: bloque de visitas `PolicyDetailPage.tsx:975-1065` (botones `Activar` y `Cerrar visita` en `:1050-1062`).
- Candidatos de componente base para tablero/filtros: `PrintersPage.tsx` (1003 líneas, lista con filtros) y el widget "printers-attention" de `DashboardPage.tsx` (consume `GET /api/admin/dashboard/printers-attention`, `admin.py:2837`). **[NO VERIFICADO]** el detalle de componentes reutilizables (no revisé línea por línea esas páginas).
- No hay tests de frontend (no hay script `test` en `package.json`); `npm run build` = `tsc && vite build`.

**clients** (portal; React 18 **JSX sin TypeScript**, Vite, Tailwind, TanStack Query, axios, jwt-decode):
- Rutas: `clients/src/App.jsx:24-37`; navegación: `components/Layout.jsx:17-22` (`NAV_ITEMS`: Dashboard, Mis Impresoras, Reportes, Mis Pólizas, Configuración). Cliente HTTP: `src/api/axios.js` (token en `localStorage('portal_token')`, `401` → `/login`). Patrón: `useQuery({queryKey:['portal','printers'], ...})` (`pages/Impresoras.jsx:34-35`). Existe `components/StatusBadge.jsx` y `Skeleton.jsx`/`EmptyState.jsx` para reutilizar.
- El estado de impresora actual del portal ("Correcto" / "En Atención" / "Sin Historial") se calcula en el servidor con los mismos checkboxes (`portal.py:671-690`); el semáforo de riesgo debe vivir **junto a**, no reemplazar, ese estado.

### 1.5 Pruebas existentes en las zonas que se tocarían

`server/tests/` (≈165 funciones `test_*` en 17 archivos; **no ejecutadas** en esta investigación porque pytest escribe `.pytest_cache` en el repo): `conftest.py:61-85` (engine SQLite en memoria + `StaticPool`, fixtures `db`, `client`), `World` (`conftest.py:143-217`: cliente, 3 impresoras, póliza, 2 visitas, admin y técnico), `admin_headers`/`tech_headers` (`:230-238`), `portal_helpers.py:11-30` (`make_portal_user`, `portal_headers`) y `:39-60` (`add_plant_b_printer`). Cubren el scoping: `test_portal_scope.py`, `test_portal_policy_scope.py`, `test_portal_printer_detail.py`; visitas: `test_visits.py` (36); impresoras admin: `test_admin_printers.py`; sync/upsert: `test_admin_data.py`, `test_e2e_policy.py`. Sirven de molde para las pruebas nuevas.
- Aviso: `.claude/context/project-status.md:1198` dice "52 pruebas"; está desactualizado.

---

## 2. Riesgos de romper algo existente y mitigación

| ID | Riesgo | Por qué es real (evidencia) | Mitigación |
|---|---|---|---|
| R-1 | Dependencias pesadas rompen el arranque o agotan RAM/disco | numpy+pandas+sklearn ≈ +150 MB RSS por proceso (medido); `--workers 4` (`server/README.md:59`) | Import **perezoso** dentro de `app/risk/` (nunca a nivel de módulo en `main.py`); `RISK_ENABLED` por defecto activo pero tolerante a ausencia de librerías (si `ImportError` → endpoints responden 503, la app arranca igual); `n_jobs=1`; requisitos ML en archivo aparte `requirements-ml.txt` |
| R-2 | **`create_all` + Alembic**: al arrancar, `main.py:30` crea la tabla nueva si ya está registrada en `app.models`, y luego `alembic upgrade` falla con "relation already exists". Además, si la VPS está estampada en `010`, `upgrade head` intentaría `011…015` | `main.py:29-30`; `alembic/versions/011…015`; tu nota del stamp 010 | Orden de despliegue fijo: **pull → `alembic current` (solo lectura) → `alembic upgrade head` → reiniciar servicio**. La `016` se escribe **idempotente** (`inspector.has_table` / `has_index`). **Prohibido `alembic stamp` sin revisar `alembic current` y comparar el esquema real**. Hacer `pg_dump` antes (§G) |
| R-3 | Variables nuevas en `.env` + rollback → `extra_forbidden` al arrancar el código viejo | `config.py:11` sin `extra=`; incidente previo | Los campos nuevos de `Settings` llevan **valor por defecto** y **no se exige ninguna en `.env`** en el primer despliegue. Si se agregan al `.env`, el procedimiento de rollback incluye **quitarlas antes** de reiniciar la versión anterior |
| R-4 | El modelo no carga (versión de sklearn distinta, archivo ausente/corrupto) y tumba endpoints o el job | `api.py:42-49` no atrapa excepciones; el `.joblib` exige sklearn 1.9.1 (`README.md:50` del módulo) | `cargar_modelo()` captura `Exception`, registra, y responde `503 {"detail":"Modelo de riesgo no disponible"}`; el resto de la app no se entera. Se fija `scikit-learn==1.9.1` en `requirements-ml.txt` y se valida versión en el artefacto |
| R-5 | El job periódico compite con el sync móvil (CPU/BD) | Sync en `sync.py` usa la misma BD | El job lee con una sola consulta, corre fuera del proceso web (timer), prioridad baja (`Nice=10`), nunca escribe en `reports`, y solo escribe en la tabla nueva |
| R-6 | El módulo de Aurora reescribe warnings globales | `modelo.py:4` | Eliminar `filterwarnings('ignore')` al vendorizar |
| R-7 | Filtración de datos entre clientes | `api.py` sin auth y sin filtro | Endpoint admin protegido con `require_admin`; endpoint portal **siempre** parte de `_scoped_printers_query`; prueba de aislamiento obligatoria (Fase E) |
| R-8 | Derivación de datos distinta al Excel de Aurora (drift) → predicciones poco fiables | unidades de contador, formato de modelo, checklist vacío (§1.3) | Fase B incluye una **prueba de paridad** con el CSV de Aurora y un reporte comparativo antes de exponer nada |
| R-9 | `clients/node_modules` está **trackeado** en git (10 039 archivos) | `git ls-files clients/node_modules` | No es parte de este plan, pero cualquier cambio en `clients/` va a ensuciar el diff. Recomendación: ignorar y `git rm --cached` en un commit aparte |
| R-10 | Rodillo se interpreta como recomendación firme | PR-AUC 0.44 débil (`README` del módulo `:41`) | Regla de producto en el DTO: para el portal el rodillo **nunca** lleva nivel, solo "En monitoreo"; en admin se muestra con etiqueta "en monitoreo" fija y tooltip de limitación |
| R-11 | Doble clic / peticiones concurrentes | botón síncrono | Botón deshabilitado en `isPending`; `409` si ya hay un recálculo en curso (lock advisory en PostgreSQL); upsert idempotente |
| R-12 | El `.joblib` en git engorda el repo | 5.3 MB por versión | No versionar el binario en git (§3 D-7); sí versionar su metadato |

---

## 3. Decisiones recomendadas (con alternativas descartadas)

**D-1. Dónde corre**: en el servidor FastAPI, como paquete interno `server/app/risk/` (no un paquete top-level `modulo_riesgo`). *Motivo*: `WorkingDirectory` de la unidad es `server/` (`server/README.md:78`), un paquete en la raíz del repo no estaría en el `sys.path`; y el `.joblib` no referencia el paquete (0 coincidencias). *Descartado*: copiar `modulo_riesgo/` a la raíz del servidor y usar su `api.py` (sin auth, caché global); correr el modelo en Flutter (sklearn no existe allí, rompería el modelo offline-first y habría que portar RF).

**D-2. Router**: se **desecha** `modulo_riesgo/api.py` y se escriben routers propios (`/api/admin/risk/...`, `/api/portal/risk/...`) que reutilicen solo `datos.py` y `modelo.py` (con las correcciones de la Fase A). *Descartado*: `include_router(modulo.router)` + `dependency_overrides` (como propone el README): deja el prefijo `/riesgo` sin auth, y `dependency_overrides` es global a la app.

**D-3. Persistencia: tabla snapshot** (opción b), con una fila por `(printer_id, pieza)`, upsert.
- *A favor*: la lectura en admin y portal es una consulta indexada trivial (sin cargar pandas/sklearn en la ruta de lectura); permite `calculado_en`, `vigente_hasta`, versión del modelo y "datos de entrada usados" para auditar; permite que el portal funcione aunque el modelo esté caído (muestra el último snapshot marcado como antiguo); el costo de cómputo (≈0.5 s) se paga en el botón y el job, no en cada pantalla.
- *Descartado (a) al vuelo*: cada vista del tablero cargaría pandas/sklearn y leería todo el historial (el problema 4 de tu lista); sin historial de qué se mostró; con 4 workers, 4 cargas del modelo.
- *Descartado*: tabla append-only con historial completo (no pedida; crece sin control y complica la UI). Se deja `computed_at` + `model_version` y, si más adelante quieres tendencia, se agrega una tabla de historial aparte.

**D-4. Esquema** (modelo SQLAlchemy `PrinterRiskSnapshot`, tabla `printer_risk_snapshots`; PKs `String` UUID por regla de CLAUDE.md):

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `String` PK | UUID |
| `printer_id` | `String`, FK `printers.id`, index | |
| `piece` | `String(16)` | `'cabezal'` \| `'rodillo'` |
| `level` | `String(8)` | `ALTO/MEDIO/BAJO` (se guarda crudo; el portal lo traduce) |
| `risk_index` | `Float` | percentil 0–100, **no probabilidad** |
| `damaged_last_visit` | `Boolean` | |
| `previous_damages` | `Integer` | |
| `visits_count` | `Integer` | |
| `short_history` | `Boolean` | `visits < 3` |
| `last_visit_date` | `Date` | |
| `valid_until` | `Date` | `last_visit_date + 90 d` |
| `last_report_id` | `String` | último `Report.id` usado → detecta "snapshot desactualizado" sin recalcular |
| `model_version` | `String(16)` | `art['version']` |
| `inputs_json` | `Text` | fila de entrada de la última visita + resumen (serial, modelo normalizado, contador, tipo normalizado) |
| `computed_at` | `DateTime` | UTC naive (como el resto: `_now_utc()`) |
| `computed_by` | `String`, nullable | `users.id` del admin o `NULL` si fue el job |
| Restricción | `UniqueConstraint(printer_id, piece)` | |

`vigente` no se guarda: se calcula al leer (`valid_until >= hoy`). `stale` = existe un reporte elegible posterior a `last_report_id` (o `model_version` ≠ versión cargada).

**D-5. Cambio de versión del modelo**: al cargar, si `snapshot.model_version != art['version']`, la API marca `modelo_desactualizado=true` y la UI admin muestra "calculado con modelo anterior"; el portal oculta esas filas hasta recalcular. Tras un reentrenamiento manual el procedimiento incluye **correr el job completo una vez** (`python -m app.risk.refresh --all`). No se borran snapshots antiguos (se sobrescriben en el upsert).

**D-6. Disparadores**
- *Botón*: **síncrono** (0.5–0.7 s medidos, 59 equipos 0.45 s). Se recalculan **solo las impresoras afectadas**: la predicción es independiente por equipo (`features_visitas` agrupa por `numero_serie`, `datos.py:38-55`; verificado `predecir(subconjunto)==predecir(todo)`). Dos endpoints: por impresora y por póliza (`policy_id` → `PolicyPrinter`; en el detalle de póliza el botón vive en el encabezado de la sección de visitas y también por fila de visita, ambos actúan sobre las impresoras de la **póliza de esa visita**). Concurrencia: `pg_try_advisory_xact_lock` (solo en PostgreSQL; en SQLite de pruebas se omite) → `409` si ya está corriendo; botón deshabilitado en pendiente.
- *Periódico*: **systemd timer + comando CLI** (`python -m app.risk.refresh --all`), diario ~03:00. *Descartado*: APScheduler en proceso (con `--workers 4` se ejecutaría 4 veces o requeriría elección de líder); cron (funciona, pero systemd da logs en `journalctl`, `EnvironmentFile` compartido y `OnFailure`). El timer **no toca** el servicio web: es una unidad `oneshot` independiente que usa el mismo venv y el mismo `.env`.
- *Descartado*: recalcular "al guardar un reporte" (propuesta de `project-status.md:933-940`): acopla el sync con sklearn y puede degradar la sincronización offline-first.

**D-7. Modelo y reentrenamiento**: el `.joblib` vive **fuera de git** en la VPS (propuesta `server/ml_models/modelo_riesgo.joblib`, ruta configurable). En git se versiona un `MODEL_CARD.md` pequeño (versión, fecha, sklearn, métricas). Reentrenamiento **solo manual** (`python -m app.risk.entrenar_cli`), con exportación previa de la base (`python -m app.risk.export_visitas`), copia `.bak` antes de reemplazar (el CLI ya lo hace, `entrenar_cli.py:23`) y respaldo del `.joblib` actual + `pg_dump` antes de cambiar. Si el modelo no carga por versión de sklearn: el servicio responde 503 claro; se reentrena en la VPS con la misma versión o se fija `scikit-learn==1.9.1`.
- Además la Fase A corrige `METRICAS_REF` (se calcula del propio entrenamiento y se guarda en el artefacto) y los umbrales (mismo ensamble de 5).

**D-8. Seguridad y alcance**
- **Admin**: ver y actualizar → `require_admin` (`auth.py:103`). Técnicos: sin acceso en v1 (no hay requisito, y el JWT móvil de técnico no debe poder disparar cómputo). *Alternativa*: `require_internal` para lectura de técnicos — descartada por ahora.
- **Portal**: solo lectura, siempre filtrando por `_scoped_printers_query` (cliente + planta). El cliente **nunca** recibe: `risk_index`, `model_version`, `inputs_json`, `computed_by`, `visits_count`, `previous_damages`. Recibe: por impresora `cabezal.estado` ∈ {`atencion`, `vigilar`, `sin_alerta`, `desactualizado`, `sin_datos`} (derivado de `level` y `vigente`), `rodillo.estado = "en_monitoreo"` fijo, `fecha_estimacion` (= `computed_at`), `vigente_hasta`, `informacion_limitada` (bool) y el `aviso`. Etiquetas propuestas: ALTO → "Revisión recomendada", MEDIO → "Vigilar", BAJO → "Sin señales de riesgo elevado" (se evita "sin riesgo"), vencida → gris "Estimación desactualizada".
- Texto de aviso (del README del módulo, ajustado): *"Estimación estadística del riesgo de que la pieza aparezca dañada en los próximos 90 días. No es una fecha de falla ni una garantía. Se basa en el historial de reportes y mejora conforme se acumulan más. El rodillo se muestra solo como seguimiento."*

**D-9. Alcance del admin web**: "Actualizar riesgo" cuenta como **acción administrativa de mantenimiento de datos derivados** (recalcula una caché; no modifica reportes, visitas, pólizas ni nada que sincronice). Es el mismo tipo de acción que `regenerate-pdf` o `regenerate-links` (`admin.py:1840,1901`). La lógica del cálculo está en el backend. **Flutter: no se requiere nada** — no hay referencias a "riesgo" en `lib/` (única coincidencia del repo: `project-status.md`), el modelo no se descarga al dispositivo, no se toca `app_database.dart`, no se agrega tabla Drift ni se cambia el payload de `/api/sync` (`schemas/sync.py`). La regla "admin web solo lectura" **no está escrita en CLAUDE.md ni en el código** (el admin ya tiene muchas mutaciones: crear póliza, cerrar visita, etc.); la trato como tu criterio de producto y la respeto limitando la escritura a este único endpoint derivado.

**D-10. Convenciones**: nombres de API en inglés bajo `/api/admin/risk` y `/api/portal/risk` (como `/api/admin/printers`), mensajes de error en español (como `admin.py`/`portal.py`).

---

## 4. Plan por fases (cada una desplegable por separado)

Principio: **cada fase termina con la app existente intacta y con `pytest` completo en verde**. Las fases A–B no crean tablas ni cambian el comportamiento de ninguna ruta existente.

### Fase A — Vendorizar el módulo y corregir los 6 problemas (sin integrar)
- **Archivos a crear**: `server/app/risk/__init__.py`, `datos.py`, `modelo.py`, `entrenar_cli.py` (derivados de `modulo_riesgo/modulo_riesgo/*`); `server/requirements-ml.txt`; `server/tests/risk/` (o `server/tests/test_risk_*.py`) con el CSV de ejemplo como fixture en `server/tests/fixtures/base_visitas_min.csv`. **No** se importa desde `main.py`; **no** se agrega nada a `requirements.txt`.
- **Correcciones**: (1) sanear tipos en `preparar_visitas`: `pd.to_numeric(...).fillna(0).astype(int)` para piezas/sensores/mantenimiento/calibración/falla y rechazo explícito (`ValueError` de dominio) si falta alguna columna; `predecir` con `V.empty` devuelve `[]`; `int()` de `acum_*` seguro; (2) `normalizar_tipo_servicio()` (strip, casefold, quitar acentos) con mapa `{'correctivo':'Correctivo', 'preventivo':'Preventivo', 'diagnostico':'Diagnóstico', 'instalacion':'Instalación'}` y comparación sobre el valor normalizado en `matriz_X`; (3) el módulo deja de exponer router (no se copia `api.py`); (4) sin caché global: no se copia; (5) `predecir` devuelve además `vigente: bool` (según `date.today()` inyectable para pruebas); (6) `METRICAS_REF` se calcula en `entrenar()` (no constante) y los umbrales usan el **mismo** ensamble de 5 (`oof_scores` sin `[:2]`, o se documenta y cambia `SEMILLAS` en validación — decisión de Aurora, ver §7-P8); quitar `warnings.filterwarnings('ignore')`; `n_jobs=1` al cargar.
- **Terminado cuando**: las 6 pruebas originales pasan en la copia; hay pruebas nuevas verdes para NaN, vacío, `tipo_servicio` ('correctivo', ' Correctivo ', 'CORRECTIVO', 'Diagnostico'), `vigente`, y métricas/umbral coherentes; **toda la suite del servidor sigue verde** sin instalar sklearn (las pruebas de riesgo se saltan con `pytest.importorskip("sklearn")`).
- **Cómo revertir**: borrar `server/app/risk/`, `requirements-ml.txt` y las pruebas nuevas. Cero impacto en producción (nada importa el paquete).

### Fase B — Mapeo de datos + endpoint admin protegido (solo lectura, sin persistencia)
- **Archivos**: `server/app/risk/queries.py` (consulta §1.3 + construcción del `DataFrame`), `server/app/risk/service.py` (carga perezosa del modelo, `calcular(db, printer_ids)`), `server/app/api/routers/risk_admin.py`, `server/app/schemas/risk.py`; **una línea** en `server/app/main.py` (`app.include_router(...)`, import tolerante); campos nuevos en `server/app/config.py` con defaults (`risk_model_path: str = ""`, `risk_enabled: bool = True`).
- **Endpoints** (todos `Depends(require_admin)`): `GET /api/admin/risk/model/info`; `GET /api/admin/risk/printers?level=&piece=&client_id=&limit=` (calcula al vuelo en esta fase); `GET /api/admin/risk/printers/{printer_id}`.
- **Terminado cuando**: respuesta correcta con datos sembrados (World + reportes con checklist), `401` sin token, `403` con token de técnico y con token de portal, `503` si falta el modelo o `RISK_ENABLED=false`, la app **arranca igual sin numpy/pandas/sklearn** (prueba que simula `ImportError`), y la **prueba de paridad** con el CSV de Aurora pasa (índices idénticos al calcular desde filas ORM construidas del CSV).
- **Cómo revertir**: quitar el `include_router` de `main.py` (o `RISK_ENABLED=false`, que además es la palanca rápida sin redeploy) y revertir el commit; no hay migración.

### Fase C — Persistencia + botón (backend) + job periódico
- **Archivos**: `server/app/models/risk.py` (+ registro en `server/app/models/__init__.py`), `server/alembic/versions/016_printer_risk_snapshots.py` (**idempotente**, `down_revision="015"`; `downgrade()` hace `drop_table`), `server/app/risk/snapshots.py` (upsert, `stale`, `vigente`), `server/app/risk/refresh.py` (CLI `--all` / `--printer`), modificaciones en `risk_admin.py` (lectura desde snapshot + `POST /api/admin/risk/printers/{id}/refresh` + `POST /api/admin/policies/{policy_id}/risk/refresh`), `deploy/systemd/smp-risk-refresh.service` y `.timer` (plantillas dentro del repo; **nombres y rutas a confirmar**, §7-P1), `server/README.md` (sección).
- **Terminado cuando**: la migración sube y baja en PostgreSQL local y es no-op si la tabla ya existe; `refresh` por impresora y por póliza actualiza snapshots, con una impresora en 2 pólizas se actualiza una sola vez; segundo clic concurrente → `409`; sin modelo → `503`; el job `--all` corre dos veces seguidas sin duplicar filas; **la suite completa sigue verde**.
- **Cómo revertir**: `systemctl disable --now` del timer; `alembic downgrade 015` (borra solo `printer_risk_snapshots`); revertir commit. El rollback del código es seguro porque los campos nuevos de `Settings` tienen defaults (R-3).

### Fase D — Pantallas admin (React/TS)
- **Archivos**: `admin-web/src/api/endpoints.ts` (bloque `risk`), `admin-web/src/pages/RiskPage.tsx` (tablero), `admin-web/src/components/risk/RiskBadge.tsx`, `RefreshRiskButton.tsx`, `RiskPieceCard.tsx`; `admin-web/src/router.tsx` (rutas `risk` y, si se decide, `risk/:printerId`); `admin-web/src/components/layout/Sidebar.tsx` (ítem "Riesgo de piezas"); inserciones puntuales en `PrinterDetailPage.tsx` (tarjeta "Riesgo de piezas") y `PolicyDetailPage.tsx:975-1065` (botón "Actualizar riesgo" en la sección Visitas).
- **Pantallas**: tablero (tabla con filtros nivel/pieza/cliente, orden por riesgo, columna "calculado", chips `Vencida` e `Historial corto`, rodillo siempre con etiqueta "En monitoreo"), detalle por impresora (las dos piezas, índice con la leyenda "percentil, no probabilidad", historial corto/vigencia, fecha de último cálculo, botón actualizar con spinner y deshabilitado en pendiente, aviso estadístico).
- **Terminado cuando**: `npm run build` (`tsc && vite build`) sin errores; verificación manual en navegador del flujo (carga, filtro, actualizar, error 503 con mensaje, 409 con mensaje); no se alteran las demás pantallas.
- **Cómo revertir**: revertir el commit del front (no hay cambios de datos); el backend sigue funcionando.

### Fase E — Portal de clientes
- **Archivos**: `server/app/api/routers/risk_portal.py`, `server/app/schemas/risk_portal.py` (DTO **sin** índice numérico), `server/tests/test_portal_risk.py`; en `main.py` otro `include_router`; front: `clients/src/pages/Riesgo.jsx` (o tarjeta dentro de `ImpresoraDetalle.jsx` + columna en `Impresoras.jsx`), `clients/src/App.jsx` (ruta), `clients/src/components/Layout.jsx:17-22` (ítem), `clients/src/components/RiskSemaphore.jsx`.
- **Endpoints**: `GET /api/portal/risk/printers` y `GET /api/portal/risk/printers/{printer_id}` (`get_current_portal_user`; `_scoped_printers_query`; `404` si no está en alcance).
- **Terminado cuando**: pruebas de aislamiento (otro cliente → 404 y no aparece en lista; usuario restringido a planta A no ve planta B; token interno → 403; sin token → 401/403 según `HTTPBearer`), el JSON **no contiene** ninguno de los campos prohibidos (prueba que recorre las llaves), rodillo siempre `en_monitoreo`, snapshots con modelo antiguo o vencidos aparecen como `desactualizado`; `npm run build` del portal ok.
- **Cómo revertir**: quitar el `include_router` y la ruta/ítem del front; o apagar con un flag `portal_risk_enabled` (default `False` hasta tu aprobación, §7-P2).

---

## 5. Prompts de implementación (listos para pegar en Claude Code)

> Todos asumen: leer primero `CLAUDE.md` y `.claude/context/project-status.md`; trabajar desde la raíz del worktree; **no** hacer commit/push ni `git stash`; **no** tocar `lib/` (Flutter), `app_database.dart`, sync ni Drift; y actualizar los archivos de contexto al terminar. Las pruebas del servidor se corren con `cd server && venv313\Scripts\python -m pytest tests`.

### Prompt — Fase A
```
Fase A del módulo de riesgo (ver docs/plan_modulo_riesgo.md, §4 Fase A y §1.1).
Objetivo: vendorizar el módulo de Aurora en server/app/risk/ y corregir sus 6 problemas, SIN integrarlo a la app.
1. Crea server/app/risk/{__init__,datos,modelo,entrenar_cli}.py a partir de modulo_riesgo/modulo_riesgo/*.py (NO copies api.py ni ejemplo_app.py). No modifiques la carpeta modulo_riesgo/.
2. Correcciones en el código nuevo:
   a) preparar_visitas: convertir piezas/sensores/mantenimiento/calibracion/falla con pd.to_numeric(errors="coerce").fillna(0).astype(int); contador_1 numérico (NaN permitido); lanzar ValueError con mensaje claro si faltan columnas; predecir() con DataFrame vacío devuelve [] y los int() de acum_* no pueden fallar por NaN.
   b) normalizar_tipo_servicio(): strip + casefold + quitar acentos, mapa a Preventivo/Correctivo/Diagnóstico/Instalación; usar el valor normalizado en matriz_X (hoy datos.py:76 compara exacto con 'Correctivo').
   c) predecir() agrega vigente: bool (fecha de referencia inyectable, por defecto hoy).
   d) METRICAS_REF deja de ser constante: calcúlala dentro de entrenar() y guárdala en el artefacto (no escribas "59 equipos" a mano).
   e) Los umbrales ALTO/MEDIO deben salir del mismo ensamble (nº de semillas) con el que se predice (hoy oof_scores usa [:2] y se predice con 5).
   f) Quita warnings.filterwarnings('ignore') y fija n_jobs=1 al cargar los modelos.
   g) cargar() debe lanzar una excepción propia ModeloNoDisponible (con causa) si el archivo falta o joblib falla por versión.
3. Agrega server/requirements-ml.txt (numpy, pandas, scikit-learn==1.9.1, joblib). NO toques server/requirements.txt ni main.py.
4. Pruebas en server/tests/ (usa pytest.importorskip("sklearn") para que la suite siga verde sin sklearn): las 6 originales adaptadas, más NaN en cabezal/rodillo de la última visita, DataFrame vacío, tipo_servicio ('correctivo', ' Correctivo ', 'CORRECTIVO', 'Diagnostico') dando índices idénticos a 'Correctivo', vigente True/False, umbrales coherentes. Copia datos_ejemplo/base_visitas_min.csv y modelos/modelo_riesgo.joblib como fixtures SOLO si la ruta del modelo es configurable por variable; el .joblib no debe quedar versionado (añade la regla a .gitignore).
5. Corre toda la suite del servidor y reporta el resultado real. No ejecutes nada contra producción.
```

### Prompt — Fase B
```
Fase B del módulo de riesgo (docs/plan_modulo_riesgo.md, §1.3 y §4 Fase B). Requiere Fase A.
Objetivo: mapear datos reales a las 13 columnas de COLS y exponer endpoints admin protegidos, sin persistencia.
1. server/app/risk/queries.py: implementa la consulta de §1.3 (lista blanca de estados, excluir reportes con supersedes, solo impresoras activas, orden determinista) y una función que construye el DataFrame con EXACTAMENTE datos.COLS: numero_serie=Printer.serial_number, fecha=service_date (solo fecha), modelo=f"{model_name}-{dpi}dpi" en mayúsculas, tipo_servicio normalizado, contador_1=linear_inches_counter, checkboxes con json.loads defensivo y criterio `is True`, falla=1 si algún daño, fila_origen=cumcount+1 por equipo. Nunca uses pólizas para esto.
2. server/app/risk/service.py: carga perezosa del modelo (import de numpy/pandas/sklearn dentro de funciones), caché del modelo por (ruta, mtime), error ModeloNoDisponible -> HTTP 503 con mensaje en español. calcular(db, printer_ids|None).
3. server/app/api/routers/risk_admin.py (prefix /api/admin/risk, TODOS con Depends(require_admin)): GET /model/info, GET /printers (filtros level, piece, client_id, limit), GET /printers/{printer_id}. Schemas Pydantic v2 en server/app/schemas/risk.py. Incluye vigente y los textos de aviso.
4. main.py: un solo include_router, con try/except ImportError para que la app arranque sin sklearn. Settings: risk_model_path: str = "" y risk_enabled: bool = True (con defaults; NO exijas nada en .env; recuerda extra_forbidden).
5. Pruebas: paridad con el CSV de Aurora (construye reportes ORM desde el CSV y compara índices), 401/403 (técnico y portal), 503 sin modelo y con risk_enabled=False, app arranca sin sklearn (simula ImportError con monkeypatch), una impresora en dos pólizas no duplica ni altera datos, reportes Draft/Deleted/superseded/pending_delivery tratados según §1.3.
6. Suite completa del servidor en verde. Sin migraciones. Sin tocar lib/.
```

### Prompt — Fase C
```
Fase C del módulo de riesgo (docs/plan_modulo_riesgo.md, §3 D-3..D-6 y §4 Fase C). Requiere Fases A y B.
1. Modelo SQLAlchemy PrinterRiskSnapshot en server/app/models/risk.py con el esquema de D-4 (PK String UUID, UniqueConstraint(printer_id, piece)); regístralo en app/models/__init__.py.
2. Migración server/alembic/versions/016_printer_risk_snapshots.py (revision "016", down_revision "015"). Debe ser IDEMPOTENTE: usa sa.inspect(op.get_bind()).has_table(...) antes de crear tabla/índices (main.py:30 hace create_all al arrancar). downgrade = drop_table. NO la ejecutes contra ninguna BD de producción; pruébala solo en una BD local descartable (upgrade, downgrade, upgrade, y upgrade con la tabla ya creada por create_all).
3. server/app/risk/snapshots.py: upsert por (printer_id, piece), calcular vigente/stale/modelo_desactualizado al leer.
4. Endpoints admin: GET lee desde snapshot (no calcula); POST /api/admin/risk/printers/{printer_id}/refresh y POST /api/admin/policies/{policy_id}/risk/refresh (imprime impresoras vía PolicyPrinter con el policy_id dado, sin firstOrNull; valida póliza no eliminada). Síncronos; lock con pg_try_advisory_xact_lock solo si el dialecto es postgresql (409 si ocupado); respuesta con los snapshots actualizados y computed_at. Registra computed_by=user id.
5. server/app/risk/refresh.py: CLI `python -m app.risk.refresh --all | --printer <id>`; código de salida distinto de 0 si falla; logging claro; no escribe en reports.
6. deploy/systemd/: plantillas smp-risk-refresh.service (Type=oneshot, Nice=10, mismo EnvironmentFile y venv que el backend) y .timer (diario 03:00). Deja marcados con TODO los nombres de unidad, rutas y usuario reales de la VPS (confirmar con el usuario). No toques el servicio web.
7. Pruebas: refresh por impresora y por póliza, impresora en 2 pólizas, doble llamada concurrente (409), job --all idempotente, sin modelo 503, migración idempotente, y que POST requiere admin. Suite completa en verde.
```

### Prompt — Fase D
```
Fase D del módulo de riesgo (docs/plan_modulo_riesgo.md, §1.4 y §4 Fase D). Requiere Fase C desplegada o corriendo en local.
Objetivo: pantallas del admin web (React + TS + Tailwind + TanStack Query), reutilizando los patrones existentes.
1. admin-web/src/api/endpoints.ts: agrega el bloque `risk` (list, detail, refreshPrinter, refreshPolicy, modelInfo).
2. Nueva página admin-web/src/pages/RiskPage.tsx (ruta /risk) modelada sobre PrintersPage.tsx (tabla y filtros): filtros nivel, pieza y cliente; ordenar por riesgo; columnas cabezal/rodillo con RiskBadge; chips "Vencida" e "Historial corto"; "Calculado el …" por fila; rodillo SIEMPRE con la etiqueta "En monitoreo". Ítem "Riesgo de piezas" en Sidebar.tsx (NAV_ITEMS) y ruta en router.tsx.
3. Detalle: tarjeta "Riesgo de piezas" en PrinterDetailPage.tsx (dos piezas, índice con leyenda "percentil relativo, no es una probabilidad", fecha de último cálculo, aviso estadístico, estado vencida/historial corto) con RefreshRiskButton (spinner, deshabilitado mientras isPending, mensajes en español para 409 y 503).
4. Botón "Actualizar riesgo" en la sección de Visitas de PolicyDetailPage.tsx (cerca de las líneas 975–1065, junto a "Activar"/"Cerrar visita") que llama al endpoint por póliza; al terminar invalida las queries de riesgo.
5. Componentes en admin-web/src/components/risk/ (RiskBadge, RefreshRiskButton, RiskPieceCard). Sin dependencias nuevas.
6. Valida con `cd admin-web && npm run build` y verificación manual en el navegador contra el backend local (carga, filtros, actualizar, error 503 y 409). No cambies otras pantallas.
```

### Prompt — Fase E
```
Fase E del módulo de riesgo (docs/plan_modulo_riesgo.md, §3 D-8 y §4 Fase E). Requiere Fase C.
Backend:
1. server/app/schemas/risk_portal.py: DTO sin índice numérico. Por impresora: id, serial_number, modelo, planta, cabezal {estado: atencion|vigilar|sin_alerta|desactualizado|sin_datos}, rodillo {estado: "en_monitoreo", danado_en_ultima_visita}, fecha_estimacion, vigente_hasta, informacion_limitada, aviso. PROHIBIDO exponer risk_index, level crudo, model_version, inputs_json, computed_by, visits_count, previous_damages.
2. server/app/api/routers/risk_portal.py (/api/portal/risk): GET /printers y GET /printers/{printer_id}, ambos con get_current_portal_user y construidos desde portal._scoped_printers_query (cliente + planta); impresora fuera de alcance => 404 (no 403). Snapshots con modelo distinto al vigente o vencidos => estado "desactualizado". Flag portal_risk_enabled (default False) en Settings con default; 404/503 si está apagado.
3. Pruebas (server/tests/test_portal_risk.py, usa portal_helpers): aislamiento entre clientes, usuario restringido a planta, token interno => 403, sin token => 401/403, el JSON no contiene llaves prohibidas (recorrido recursivo), rodillo siempre en_monitoreo, mapeo ALTO/MEDIO/BAJO, vencida, historial corto.
Frontend (clients/, JSX): página Riesgo.jsx (o tarjeta en ImpresoraDetalle.jsx + columna en Impresoras.jsx) con semáforo simple por equipo usando StatusBadge/Skeleton/EmptyState existentes, texto de aviso visible y rodillo "En monitoreo"; ruta en App.jsx e ítem en Layout.jsx. Sin mostrar números. Valida con `cd clients && npm run build`.
Suite completa del servidor en verde. No toques lib/.
```

---

## 6. Despliegue, rollback y pruebas

### G. Despliegue (laptop → GitHub → pull en la VPS; **nunca `git stash` en la VPS**)

Para cada fase con backend (B, C, E), en este orden:

1. **Laptop**: pruebas verdes → commit → `git push` → (opcional) tag `riesgo-fase-X`.
2. **VPS — antes de tocar nada** (solo lectura y respaldo): `git status` limpio (si no lo está, **parar y revisar**; no stash), `sudo -u <usuario> pg_dump` de la BD a un archivo con fecha, copia del `.env` y del `.joblib` vigente, `alembic current` y `alembic heads` (comparar con `015`).
3. `git pull --ff-only`.
4. Dependencias (solo Fase B en adelante, una vez): `venv313/bin/pip install -r requirements-ml.txt`; verificar `python -c "import sklearn; print(sklearn.__version__)"` = `1.9.1`; `pip check`.
5. Modelo: copiar `modelo_riesgo.joblib` a la ruta acordada (fuera de git), con permisos de lectura para el usuario del servicio; `python -c "from app.risk.modelo import cargar; cargar('<ruta>')"`.
6. **Fase C**: `alembic upgrade head` **antes** de reiniciar (R-2). Si `alembic current` no es `015`, **no continuar**: resolver primero qué esquema hay (`\d` de las tablas de 011–015) y decidir con el usuario; **no** usar `stamp` a ciegas.
7. `sudo systemctl restart <servicio-backend>` y revisar `journalctl -u <servicio-backend> -n 100`. Humo: `GET /` y un endpoint admin existente, luego `GET /api/admin/risk/model/info`.
8. Timer (Fase C): copiar las unidades, `systemctl daemon-reload`, `systemctl enable --now <timer>`, probar `systemctl start <servicio-refresh>` una vez y revisar `journalctl`.
9. Front: `npm run build` en `admin-web/` y `clients/` y publicar `dist/` como hoy se haga (**[NO VERIFICADO]** el mecanismo de publicación del front).

**Rollback**: (1) si hay timer, `systemctl disable --now`; (2) quitar de `.env` cualquier variable `RISK_*`/`PORTAL_RISK_*` que se haya agregado (R-3); (3) `git checkout <commit-anterior>` (o `git revert`), nunca `git reset --hard` ni stash en la VPS; (4) `alembic downgrade 015` solo si se aplicó la 016 (solo elimina `printer_risk_snapshots`); (5) `restart`; (6) restaurar `.joblib` anterior si se cambió. La palanca más rápida sin redeploy es `RISK_ENABLED=false` en el `.env` **solo si el código desplegado ya conoce el campo**.

**Settings/variables nuevas (checklist)** — todas con default en `Settings`; ninguna obligatoria en `.env`:

| Variable | Default | Fase |
|---|---|---|
| `RISK_ENABLED` | `true` | B |
| `RISK_MODEL_PATH` | `""` (→ `server/ml_models/modelo_riesgo.joblib`) | B |
| `PORTAL_RISK_ENABLED` | `false` | E |

Recordatorios: agregar el campo a `Settings` **y desplegar** antes de escribirlo en el `.env`; `server/.env` está ignorado por git (`.gitignore`), así que no viaja con el pull.

### H. Pruebas nuevas necesarias (resumen)

| Zona | Prueba | Fase |
|---|---|---|
| Problema 1 | NaN en `cabezal`/`rodillo` de la última visita; DataFrame vacío; valores como texto/bool | A |
| Problema 2 | `tipo_servicio` en variantes de mayúsculas/espacios/acentos produce índices idénticos | A |
| Problema 3 | `401` sin token, `403` técnico, `403` token de portal, `200` admin | B |
| Problema 4 | refresh de un solo equipo ≠ lectura de toda la tabla; un reporte editado cambia `last_report_id`→ snapshot `stale`; sin caché global | B/C |
| Problema 5 | `vigente` True/False con fecha inyectada | A |
| Problema 6 | `METRICAS_REF` calculada, umbrales con mismo ensamble | A |
| Paridad | CSV de Aurora → ORM → índices iguales a `predecir` directo | B |
| Datos | Draft/Deleted/superseded/pending_delivery; una impresora en 2 pólizas; checklist `"{}"`; JSON inválido | B |
| Portal | aislamiento entre clientes y plantas; llaves prohibidas ausentes; rodillo siempre `en_monitoreo` | E |
| Arranque | la app arranca igual si falta el módulo (`ImportError`) o el modelo; `RISK_ENABLED=false` | B |
| Migración | `016` upgrade/downgrade/idempotente | C |
| Concurrencia | segundo POST simultáneo → `409`; job `--all` idempotente | C |

---

## 7. Supuestos que no pude verificar

1. **Nombre de la unidad y rutas reales en la VPS**: el repo documenta `smp-api.service`, `/opt/smp/server`, `venv/` y `--workers 4` (`server/README.md:73-95`); tú mencionas `servicios-backend.service` y `venv313`. No pude inspeccionar la VPS.
2. **Estado de Alembic en la VPS**: sólo sé que se estampó la `010`; no sé si `011`–`015` se aplicaron ni si las tablas/columnas de esas migraciones ya existen por `create_all`.
3. **RAM/CPU/disco libres en la VPS** y **cuántos workers** corren realmente.
4. **Versiones instaladas en el `venv313` de la VPS** (el local difiere de `requirements.txt`: fastapi 0.100.0 vs 0.111.0; starlette 0.27.0; pydantic-settings 2.0.3 vs 2.2.1). La verificación del `dry-run` fue contra el venv local.
5. **Formato real de `CatalogModel.model_name`** en producción (afecta `fam()`); **unidad real de `linear_inches_counter`** frente a `contador_1`; si `0` significa "no capturado".
6. **Qué estados de `Report.status` llegan realmente al servidor** (¿`Draft`?); si `supersedes_report_id` se usa en producción; si `ReportPart` se llena (el plan usa solo el checklist JSON).
7. **Cuántos reportes y equipos hay en la BD de producción** y si cubren un historial comparable al Excel de Aurora (59 equipos / 426 visitas desde 2023): posible *drift* o historial más corto → más equipos con `historial_corto`.
8. Que la decisión de umbrales con 2 vs 5 semillas la quiera cambiar Aurora (afecta métricas ya reportadas en el TT).
9. Que `sklearn 1.9.1` tenga rueda para el Python y SO de la VPS (en mi máquina Windows/3.13 se instaló; en Linux no lo probé).
10. **Que no exista ya un scheduler/`BackgroundTasks`** en `server/`: no hice un `grep` exhaustivo de `apscheduler|BackgroundTasks|threading` en todo `server/app`; solo revisé `main.py`, `config.py`, `database.py`, `auth.py` y los routers por nombre.
11. Detalle de componentes reutilizables en `PrintersPage.tsx`, `DashboardPage.tsx`, `Impresoras.jsx`, y dónde está declarado `errDetail` (solo revisé las partes citadas).
12. Mecanismo de publicación de los `dist/` de admin-web y clients en la VPS.
13. Que la suite de pruebas existente esté hoy 100 % verde (no la ejecuté para no escribir en el repo).
14. Que `pydantic-settings` en la versión desplegada rechace variables extra en `.env` (infiero `extra_forbidden` por `config.py:11` sin `extra=` y por tu incidente previo; no lo probé).
15. Aspectos legales/comerciales de mostrar al cliente un riesgo de falla de pieza (no es técnico; ver P2).

---

## 8. Preguntas abiertas

- **P1.** ¿Cómo se llama realmente la unidad systemd del backend en la VPS (`servicios-backend.service` vs `smp-api.service`), con qué usuario corre, dónde está el repo y el venv, y cuántos workers usa? ¿Puedes pegar `systemctl cat <unidad>`, `alembic current` y `free -m` (solo lectura)?
- **P2.** ¿Quieres mostrar el riesgo al **cliente** ya en la v1? Hay implicación comercial (decirle a un cliente "revisión recomendada del cabezal" puede generar expectativa/reclamo en pólizas). Mi propuesta: Fase E detrás de `PORTAL_RISK_ENABLED=false` hasta que tú y Servicios Main PC aprueben textos y etiquetas.
- **P3.** ¿Los reportes **sin firmar** (`pending_delivery`, `pending_group_signature`) deben contar como entrada del modelo? Propongo que sí.
- **P4.** ¿Los técnicos deben ver el riesgo (por ejemplo en Flutter antes de visitar un equipo)? El plan asume que no y que Flutter no cambia.
- **P5.** Frecuencia del job: ¿diario a las 03:00 está bien, o prefieres semanal / tras cada cierre de visita?
- **P6.** ¿Cuál es el formato real de `model_name` en `catalog_models` (por ejemplo `ZT411`, `ZT411-300dpi`, `110Xi4`)? ¿Y el contador se captura en pulgadas lineales igual que "contador 1" del Excel? Puedo pedírtelo como consulta `SELECT DISTINCT` de solo lectura para que la corras tú.
- **P7.** ¿El `.joblib` entra a git (5.3 MB por versión, comodidad de despliegue) o se queda fuera como propongo? ¿Dónde guardarás los respaldos?
- **P8.** ¿Aurora acepta que los umbrales ALTO/MEDIO se recalculen con el ensamble de 5 modelos? Cambiaría ligeramente los porcentajes citados en el TT.
- **P9.** ¿Ignoramos `clients/node_modules` (10 039 archivos trackeados) con un commit aparte antes de la Fase E?
- **P10.** ¿Quieres historial de predicciones (tendencia) en el futuro? Si sí, conviene decidirlo antes de la Fase C para diseñar la tabla de historial desde el inicio.
