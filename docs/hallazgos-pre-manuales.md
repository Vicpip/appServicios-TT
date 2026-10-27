# Hallazgos previos a los manuales (admin-web y portal de clientes)

Origen: lectura de código (sin ejecutar la app) hecha el 2026-10-27 sobre la rama `feat/sesion-visitas-ligas`.
Alcance: `admin-web/`, `clients/`, `server/app/`, y referencias a `lib/` (Flutter) y documentación del repo.
Todo estado nace **Pendiente**. Nada de este documento se ha corregido.

Convenciones:
- Rutas relativas a la raíz del repo (`C:\Proyectos\AppTT\appServicios-TT`).
- `$API` = URL base del backend (producción: `https://api.mainservicepc.com`). `$ADMIN_TOKEN` = JWT de un usuario `role=admin`; `$TECH_TOKEN` = JWT de un `technician`; `$PORTAL_TOKEN` = JWT de un usuario del portal.
- Pruebas del backend: `cd server && venv313\Scripts\python -m pytest tests` (existen `test_auth.py`, `test_visits.py`, `test_e2e_policy.py`, etc.; hay 52 pruebas según `project-status.md`).
- Frontends: `cd admin-web && npx tsc --noEmit`; `cd clients && npm install && npm run build` (el `node_modules` de `clients/` estaba incompleto según `project-status.md`).

## Resumen por severidad

| Severidad | Cantidad | IDs |
|---|---|---|
| Crítica | 1 | H-01 |
| Alta | 5 | H-02, H-08, H-09, H-19, H-27 |
| Media | 13 | H-03, H-04, H-05, H-06, H-07, H-11, H-12, H-13, H-14, H-15, H-17, H-23, H-24 |
| Baja | 8 | H-10, H-16, H-18, H-20, H-21, H-22, H-25, H-26 |
| **Total** | **27** | |

---

## H-01 — Endpoints `/api/admin/*` sin autenticación (y correos de contacto abiertos al portal)

- **Severidad:** Crítica
- **Área:** backend (con cambio asociado en clients y flutter)
- **Dónde:**
  - `server/app/api/routers/admin.py:78` — `router = APIRouter(prefix="/api/admin", tags=["admin"])` sin `dependencies=`.
  - `server/app/main.py:58-63` — no hay dependencia ni middleware global de auth.
  - `server/app/auth.py:48` (`get_current_user`, solo decodifica el JWT) y `:55` (`get_current_active_user`, además valida usuario activo y `token_version`).
  - `clients/src/pages/Configuracion.jsx:28, 48, 67` — el portal llama a `/api/admin/clients/${clientId}/contact-emails` (GET/POST/DELETE).
- **Qué pasa hoy:**
  De unos 77 handlers en `admin.py`, **solo 7 exigen token**:

  | Línea | Endpoint | Dependencia |
  |---|---|---|
  | 511 | `PATCH /clients/{id}/logo` | `get_current_user` |
  | 552 | `DELETE /clients/{id}/logo` | `get_current_user` |
  | 1816 | `POST /policy-deliveries/{id}/regenerate-pdf` | `get_current_user` |
  | 1842 | `POST /policy-deliveries/{id}/send-email` | `get_current_active_user` |
  | 1879 | `POST /policy-deliveries/{id}/regenerate-links` | `get_current_active_user` |
  | 2616 | `GET /policies/{pid}/visits/{vid}/close-summary` | `get_current_active_user` |
  | 2629 | `POST /policies/{pid}/visits/{vid}/close` | `get_current_active_user` + `role == "admin"` (línea ~2640, único chequeo de rol) |

  **Sin ninguna autenticación** (línea de la definición `@router.*`): GET `/reports` 118, GET `/reports/{id}` 183, POST `/reports/{id}/review` 240, GET `/reports/{id}/files` 266, GET `/clients` 304, GET `/clients/{id}/detail` 368, GET `/technicians` 572, `/technicians/{id}` 617, `/technicians/{id}/reports` 637, GET `/printers` 675, `/printers/template/download` 778, POST `/printers/bulk-upload` 847, GET `/printers/{id}` 1005, `/printers/{id}/reports` 1037, `/printers/{id}/stats` 1072, GET `/policies` 1143, GET `/sync/history` 1214, POST `/policies` 1357, GET `/policies/next-folio` 1391, GET `/policies/{id}` 1414, PUT 1427, DELETE 1470, POST/DELETE `/policies/{id}/printers` 1488/1534, `/policies/{id}/assignments` 1559/1587/1646, `/policies/{id}/deliveries` 1716, `/policy-deliveries/{id}/detail` 1758, POST `/policies/{id}/deliveries` 1804, **POST `/technicians` 1907**, PUT 1938, DELETE 1978, **POST `/technicians/{id}/revoke-tokens` 1993**, POST/PUT/DELETE `/clients` 2012/2037/2075, contact-emails (GET 2093, POST 2109, PATCH 2131, DELETE 2153), `/plants` 2169/2183/2205, `/areas` 2222/2236, `/catalog/models` 2253/2266, POST/PUT/DELETE `/printers` 2286/2335/2397, `/policies/{id}/visits` (GET 2470, POST generate 2486, PATCH 2549, DELETE todas 2674, DELETE una 2694), `/dashboard/*` 2717/2758/2821.

  Fuera de `admin.py` también:
  - `server/app/api/routers/reports.py`: `GET /api/reports/{id}` (~línea 100) no tiene auth (el PATCH y el send-email sí).
  - `server/app/api/routers/sync.py:830` `GET /api/policies` no tiene `Depends` de auth (el resto de `sync.py` sí: 157, 200, 275, 413, 558, 702, 731, 875).
  - Sí exigen token interno: `portal.py:204` (invite), `:1100` (lista de usuarios del portal) y `:1148` (toggle-active), todas con `get_current_user` (sin chequeo de rol ni de estado activo).
  - Legítimamente públicos: `/api/auth/login`, `/api/health`, `/api/portal/{client-logo,invite/info,register,login,forgot-password,reset-password}`, `/api/public/files/{token}`.

  Consecuencias encadenadas: `POST /api/admin/technicians` sin auth permite crear un usuario `role=admin` y entrar; `revoke-tokens` y `DELETE /technicians/{id}` permiten sabotear sesiones; los contact-emails permiten redirigir los correos de un cliente ajeno; `GET /clients/{id}/detail`, reportes y PDFs filtran datos de todos los clientes.
  El portal (`Configuracion.jsx`) usa esos mismos endpoints con el `client_id` sacado del JWT en el cliente; el servidor no verifica que el `client_id` de la URL pertenezca al usuario, así que cualquiera puede operar sobre otro `client_id`.
- **Impacto:** exposición total de datos y de operaciones administrativas a Internet; escalada trivial a administrador; manipulación de destinatarios de correos con PDFs de clientes.
- **Arreglo propuesto (mínimo):**
  1. En `server/app/auth.py` añadir `require_admin(payload=Depends(get_current_active_user))` que devuelva 403 si `payload["role"] != "admin"`, y `require_internal` = `get_current_active_user` (cualquier usuario interno activo).
  2. En `admin.py:78` cambiar a `APIRouter(prefix="/api/admin", tags=["admin"], dependencies=[Depends(require_admin)])`. Quitar los `Depends(get_current_user)` sueltos de 511/552/1816 (quedan cubiertos). Cambiar `get_current_user` a `get_current_active_user` en `portal.py:204, 1100, 1148` y añadir `require_admin` en los de gestión de usuarios del portal (1100, 1148); `invite` (204) también admin.
  3. **Excepción obligatoria:** la app Flutter hace `GET /api/admin/clients/{id}/contact-emails` con token de técnico (`lib/features/reports/presentation/report_view_screen.dart:383`, `lib/features/signature/widgets/email_delivery_section.dart:35`, `lib/features/sync/services/sync_service.dart:1079`). Con `require_admin` global la app dejaría de ver esos correos. Opciones: (a) sacar ese `GET` a un router propio `/api/clients/{id}/contact-emails` con `require_internal` y apuntar la app ahí (requiere versión nueva de la app); o (b) dejar el router admin con `require_admin` salvo ese `GET` (poner la dependencia por endpoint en lugar de a nivel de router). Recomendado (b) para no romper la app instalada; luego migrar.
  4. Portal: crear endpoints propios en `portal.py` — `GET/POST/DELETE /api/portal/contact-emails[/{id}]` con `Depends(get_current_portal_user)` y `_resolve_portal_user`; el `client_id` **sale del token/BD, nunca de la URL**; el `DELETE` debe validar `email.client_id == portal_user.client_id`. Cambiar `Configuracion.jsx` (líneas 28, 48, 67) a esas rutas. No tocar `ClientDetailPage.tsx` (admin) ni los esquemas `ClientContactEmail*`.
  5. `reports.py` `GET /{report_id}`: añadir `get_current_active_user`. `sync.py:830` `GET /policies`: añadir `get_current_active_user` (verificar antes que la app lo llama con token).
  6. Añadir pruebas en `server/tests/test_auth.py`: cada familia de rutas admin devuelve 401 sin token, 403 con token de técnico, 200 con admin.
- **Cómo verificar:**
  - `curl -i $API/api/admin/clients` → debe ser 401 (hoy 200).
  - `curl -i -H "Authorization: Bearer $TECH_TOKEN" $API/api/admin/technicians` → 403.
  - `curl -i -X POST $API/api/admin/technicians -H "Content-Type: application/json" -d '{"name":"x","email":"x@x.com","password":"Abc!defghij1","role":"admin"}'` → 401.
  - Con `$TECH_TOKEN`: `GET $API/api/admin/clients/<id>/contact-emails` sigue 200 (la app lo necesita) y el `POST` da 403.
  - Con `$PORTAL_TOKEN` de cliente A: `GET $API/api/portal/contact-emails` solo muestra los de A; `DELETE` de un id de cliente B → 404/403.
  - Pruebas pytest nuevas en verde.
- **Afecta al manual:** Sí. Sección de roles/permisos del admin: pasar de "no se valida rol" a "solo `admin` accede". Sección Configuración del portal: cambia solo internamente (no el texto de pantalla).
- **Estado:** Corregido en rama `fix/auth-admin` (sin desplegar)

## H-02 — El login no valida rol; el admin web acepta a cualquier usuario con contraseña

- **Severidad:** Alta
- **Área:** backend + admin-web
- **Dónde:** `server/app/api/routers/auth.py:81-113` (no revisa `user.role`); `admin-web/src/components/ProtectedRoute.tsx` (solo comprueba que haya token); `admin-web/src/pages/LoginPage.tsx:58-76` (guarda el token sin leer el rol); `admin-web/src/auth/AuthContext.tsx`.
- **Qué pasa hoy:** `POST /api/auth/login` devuelve token para técnico o admin. El front del admin entra en ambos casos. El `LoginResponse` incluye `user.role`, pero `LoginPage` lo descarta. Además un 403 (usuario desactivado) se muestra como "Credenciales inválidas" (el `catch` no distingue).
- **Impacto:** un técnico puede abrir el panel admin y (hoy) operar todo; aun después de H-01 ve pantallas que no debe y recibe 403 sin explicación.
- **Arreglo propuesto:**
  1. `auth.py`: conservar el login único (la app móvil lo usa con `client_type=mobile`). Si `client_type == "web"` y `user.role != "admin"` → 403 "Acceso restringido a administradores".
  2. `LoginPage.tsx`: al 403 mostrar el mensaje del servidor ("Acceso restringido…" / "Usuario desactivado") en vez de "Credenciales inválidas"; mantener "Credenciales inválidas" solo para 401.
  3. `AuthContext.tsx`/`authToken.ts`: opcionalmente decodificar el JWT y guardar `role` para ocultar menú si no es admin. **No tocar** `lib/` (Flutter) ni `portal.py`.
- **Cómo verificar:** `curl -X POST $API/api/auth/login -d '{"email":"<técnico>","password":"…","client_type":"web"}' -H "Content-Type: application/json"` → 403; mismo usuario con `client_type":"mobile"` → 200. En pantalla: técnico en `/login` ve el mensaje de acceso restringido; usuario desactivado ve "Usuario desactivado".
- **Afecta al manual:** Sí. Sección Login del admin ("Credenciales inválidas" cubre solo 401; nuevo mensaje de acceso restringido) y sección de roles.
- **Estado:** Corregido en rama `fix/auth-admin` (sin desplegar)

## H-03 — Pantalla Sincronización: contadores y filtros de fecha no funcionan

- **Severidad:** Media
- **Área:** admin-web + backend
- **Dónde:** `admin-web/src/pages/SyncPage.tsx:22-26` (interfaz `SyncStatusData`: `synced`, `pending`, `failed`), `:110-118` (query), `:175, :187, :199` (render), `:125-126` (envía `date_from`/`date_to`); `server/app/api/routers/sync.py:872-889` (devuelve `synced_total`, `failed`, `pending_reports`); `server/app/api/routers/admin.py:1214-1220` (`sync_history` solo acepta `status`, `entity_type`, `offset`, `limit`).
- **Qué pasa hoy:** "Sincronizados" y "Pendientes" siempre muestran 0 (claves distintas); solo "Con error" funciona. Los campos Desde/Hasta se envían, pero el backend los ignora, así que no filtran. El `GET /api/sync/status` cuenta `SyncLog` global y además hardcodea `pending_reports: 0` (el servidor no tiene cola pendiente).
- **Impacto:** el administrador ve cifras falsas y cree que filtra por fecha cuando no.
- **Arreglo propuesto:**
  1. `SyncPage.tsx`: mapear a las claves reales (`synced_total`, `failed`) y **eliminar la tarjeta "Pendientes"** (o renombrarla; el servidor no la conoce). No cambiar `sync.py:872` (lo consume la app: `lib/features/sync/...`).
  2. `admin.py:1214`: añadir `date_from: datetime | None` y `date_to: datetime | None` y filtrar `SyncLog.synced_at`.
  3. Opcional: endpoint admin dedicado `GET /api/admin/sync/summary` para no depender del de la app.
- **Cómo verificar:** con registros en `SyncLog`, la pantalla debe mostrar el mismo número que `curl -H "Authorization: Bearer $ADMIN_TOKEN" $API/api/sync/status`. `curl "$API/api/admin/sync/history?date_from=2026-10-01T00:00:00&date_to=2026-10-02T23:59:59"` devuelve solo filas de ese rango. Prueba pytest: crear 3 `SyncLog` con fechas distintas y comprobar filtrado.
- **Afecta al manual:** Sí. Sección Sincronización: quitar la mención de "Pendientes" y confirmar que Desde/Hasta funcionan.
- **Estado:** Pendiente

## H-04 — Portal, detalle de impresora: estadísticas calculadas en el navegador con estados inexistentes

- **Severidad:** Media
- **Área:** clients
- **Dónde:** `clients/src/pages/ImpresoraDetalle.jsx:60-73` (cálculo), `:164-176` (KPI "Total reportes", "Tipo frecuente", "Completados", "Pendientes"), `:209-214` ("Estado general").
- **Qué pasa hoy:** `completados` cuenta `status === 'completado'` y `pendientes` cuenta `'pendiente'`; esos estados no existen (los reales son `Signed`, `pending_delivery`, etc.). Siempre dan 0 y "Estado general" casi siempre muestra "Al día". "Total reportes" y "Tipo frecuente" se calculan sobre `reports`, que es la página actual (10 filas) filtrada a 30 días.
- **Impacto:** el cliente ve datos incorrectos de su equipo.
- **Arreglo propuesto:** mover el cálculo al backend. En `portal.py:579` (`get_printer`) añadir al `PortalPrinterDetail` (`server/app/schemas/portal.py`) `reports_last_30d: int`, `most_frequent_service_type: str | None`, `pending_delivery_count: int`. En `ImpresoraDetalle.jsx` mostrar esos campos y **eliminar** "Completados", "Pendientes" y "Estado general" (o reemplazar "Estado general" por `printer.printer_status`, que ya viene del servidor). No tocar `admin.py` ni `PrinterDetailPage.tsx`.
- **Cómo verificar:** impresora con 15 reportes en 30 días y página de 10: "Total reportes" debe decir 15. `curl -H "Authorization: Bearer $PORTAL_TOKEN" $API/api/portal/printers/<id>` incluye los campos nuevos. Ya no aparecen "Completados"/"Pendientes".
- **Afecta al manual:** Sí. Sección Detalle de impresora del portal: quitar las tres tarjetas y describir las que quedan.
- **Estado:** Pendiente

## H-05 — Portal, dashboard: cifras y gráficas sobre los 100 reportes más recientes

- **Severidad:** Media
- **Área:** clients + backend
- **Dónde:** `clients/src/pages/Dashboard.jsx:101-107` (query con `limit: 100`), `:123-127` (`reportsThisYear`, `monthlyData`, `pieData`); `server/app/api/routers/portal.py:713-720` (`limit` máximo 100 → `le=100`).
- **Qué pasa hoy:** la tarjeta "Reportes {año}", la gráfica "Reportes por mes — últimos 12 meses" y "Por tipo de servicio" se calculan con a lo sumo 100 reportes (los más recientes). Con más de 100, los meses viejos y el total del año salen truncados sin aviso.
- **Impacto:** cifras subestimadas para clientes con muchos reportes.
- **Arreglo propuesto:** nuevo endpoint `GET /api/portal/dashboard` en `portal.py` (con `get_current_portal_user`, mismo alcance que `_get_printer_ids_in_scope`) que devuelva `{reports_year, reports_by_month[12], reports_by_type, printers_count, active_policies}` calculado con `GROUP BY`. `Dashboard.jsx`: usar ese endpoint para tarjetas y gráficas; conservar la query `limit:5` para "Reportes recientes". No subir el `le=100` de `/reports`.
- **Cómo verificar:** cliente con >100 reportes: la suma de la gráfica de 12 meses coincide con `SELECT count(*) …` por rango. `curl -H "Authorization: Bearer $PORTAL_TOKEN" $API/api/portal/dashboard`.
- **Afecta al manual:** Sí. Sección Dashboard del portal: quitar cualquier advertencia de "solo los últimos 100" (si se documentó) o no incluirla.
- **Estado:** Pendiente

## H-06 — Portal, Reportes: filtros de texto y fechas solo sobre la página cargada

- **Severidad:** Media
- **Área:** clients + backend
- **Dónde:** `clients/src/pages/Reportes.jsx:34-35` (solo `printer_id` va al servidor), `:57-72` (filtros por fecha y texto en el navegador sobre `allItems`, 20 filas), `:82-85` (contador "N reportes en total" ignora los filtros); `server/app/api/routers/portal.py:713` (`list_reports` solo acepta `printer_id`, `limit`, `offset`).
- **Qué pasa hoy:** buscar o filtrar por fecha solo afecta a las 20 filas de la página actual; resultados de otras páginas no aparecen y la paginación sigue contando todo.
- **Impacto:** el cliente cree que no existen reportes que sí existen.
- **Arreglo propuesto:** añadir a `list_reports` los parámetros `date_from`, `date_to`, `q` (serie, código, tipo, modelo; con `ilike` y join a `Printer`/`CatalogModel`). `Reportes.jsx`: enviarlos en `params` (con debounce de 350 ms para `q`), poner `setOffset(0)` al cambiarlos y eliminar el filtrado local. No tocar `Dashboard.jsx`.
- **Cómo verificar:** buscar un código que está en la página 3: aparece. `curl "$API/api/portal/reports?q=R-0012&date_from=2026-01-01"` filtra en servidor y `total` refleja el filtro.
- **Afecta al manual:** Sí. Sección Reportes del portal: los filtros aplican a todo el historial.
- **Estado:** Pendiente

## H-07 — Admin: filtros de Estado en Impresoras y Pólizas se aplican después de paginar; KPI con `limit=200`

- **Severidad:** Media
- **Área:** backend + admin-web
- **Dónde:** `server/app/api/routers/admin.py:740-741` (filtro `printer_status` dentro del bucle, tras `offset/limit` en 735-737 y con `total` calculado antes) y `:1177-1178` (`status` de pólizas, mismo patrón; `total` en 1174). `admin-web/src/pages/DashboardPage.tsx:147-159` (KPI "Impresoras en atención" con `limit: 200` y `items.length`) y `:161-173` (KPI "Pólizas por vencer").
- **Qué pasa hoy:** al filtrar por "En Atención" o "Por vencer", la página puede salir parcial/vacía y `Página X de Y` no corresponde al filtro. Los KPI cuentan solo dentro de los primeros 200 registros ordenados, sin contar los demás.
- **Impacto:** listas y KPI incorrectos en cuanto hay más de una página o más de 200 elementos.
- **Arreglo propuesto:** mover el filtro a SQL antes de `offset/limit`:
  - Pólizas: `Expired` → `end_date < now`; `Expiring` → `now <= end_date < now+30d`; `Active` → `end_date >= now+30d`; excluir `Deleted` (ver H-08). Calcular `total` con el mismo filtro.
  - Impresoras: calcular el estado en SQL con la subconsulta del último reporte (evaluar `technical_checkboxes` con `LIKE '%"Rodillo dañado": true%'` o añadir una columna/vista; si no es viable, aplicar el filtro antes de paginar en Python y paginar la lista resultante).
  - Dashboard: reutilizar `GET /api/admin/dashboard/*` (existe `printers-attention` y `policies-expiring`) o devolver `total` correcto; no usar `items.length` con `limit=200`.
  - No tocar `sync.py` ni el portal.
- **Cómo verificar:** con 25 impresoras de las que 3 "En Atención" repartidas en distintas páginas, `curl "$API/api/admin/printers?printer_status=En%20Atenci%C3%B3n&limit=20"` devuelve las 3 y `total=3`. En pantalla, el chip "En Atención" muestra las 3 y la paginación no aparece. KPI = conteo real SQL.
- **Afecta al manual:** Sí. Secciones Impresoras y Pólizas (filtros) y Dashboard (KPI): ya no hay salvedades.
- **Estado:** Pendiente

## H-08 — "Eliminar póliza" marca `Deleted` pero el listado y el detalle del admin la siguen mostrando

- **Severidad:** Alta
- **Área:** backend + admin-web
- **Dónde:** `server/app/api/routers/admin.py:1470-1481` (`status = "Deleted"`), `:1143-1182` (listado sin filtro `Deleted`), `:1414-1421` y `_policy_detail` (~1297-1330; devuelve el estado calculado por `end_date`); sí se excluye en `:2833` (dashboard); `admin-web/src/pages/PoliciesPage.tsx:532-582` (diálogo "Esta acción no se puede deshacer.").
- **Qué pasa hoy:** tras eliminar, la póliza sigue en la tabla del admin, con estado "Activa/Por vencer/Vencida" calculado por fecha. Solo se oculta en el portal, el dashboard y la app. El texto del diálogo promete una acción irreversible cuando es baja lógica.
- **Impacto:** el administrador cree que borró algo que sigue ahí; puede seguir asignando técnicos o generando visitas sobre una póliza dada de baja.
- **Arreglo propuesto:** en `list_policies` añadir `.filter(Policy.status != "Deleted")` (antes del `total`); `get_policy`/`update_policy`/`assign_*`/`visits` deben responder 404 si `status == "Deleted"`. Verificar que `sync.py:/sync/download` también las excluya. Ajustar el texto del diálogo si se mantiene la baja lógica. No cambiar el valor `"Deleted"` (lo usa `dashboard_policies_expiring`).
- **Cómo verificar:** `DELETE /api/admin/policies/{id}` → luego `GET /api/admin/policies` no la incluye y `GET /api/admin/policies/{id}` → 404. Prueba pytest en `test_e2e_policy.py`.
- **Afecta al manual:** Sí. Sección Pólizas: "Eliminar" la quita del listado.
- **Estado:** Corregido en rama `fix/datos-admin` (sin desplegar). La póliza `Deleted` sale del listado admin y responde 404 en detalle, edición, asignación de impresoras/técnicos, entregas y visitas; `/api/sync/download` ya la excluía (sin cambios). Texto del diálogo: "dejará de mostrarse (baja lógica)".

## H-09 — Estado de póliza calculado de dos maneras (admin en vivo vs. portal por estado guardado)

- **Severidad:** Alta
- **Área:** backend + clients
- **Dónde:** `server/app/api/routers/admin.py:84-95` (`_policy_status` por `end_date`, usado en 1177/1345), `:1379` y `:1457` (se guarda en `policy.status` solo al crear/editar); `server/app/api/routers/portal.py:892-896` (`Policy.status.in_(["active","Active","Activa"])`); `admin.py:313-317` (contador `active_policy_count` filtra `Policy.status == "Active"`). No hay job periódico (única referencia a `policy.status` fuera de `admin.py` es `portal.py:1004`).
- **Qué pasa hoy:** una póliza guardada como `Active` que ya venció sigue apareciendo en el portal como "Activa" (y cuenta en "Pólizas activas" del dashboard del portal y en el chip "pólizas" de Clientes). Una póliza creada con menos de 30 días de vigencia se guarda como `Expiring` y **no aparece** en el portal. El admin muestra el estado calculado en vivo, así que ambos discrepan.
- **Impacto:** el cliente ve pólizas vencidas como vigentes u oculta pólizas vigentes.
- **Arreglo propuesto:** dejar una sola fuente: calcular siempre por `end_date` y `status != "Deleted"`.
  1. Extraer `_policy_status` a `server/app/services/policy_status.py` y usarlo en admin y portal.
  2. `portal.py:892`: filtrar por `Policy.status != "Deleted"` y devolver el estado calculado (permitir ver las vencidas con etiqueta "Vencida", o excluirlas explícitamente según negocio).
  3. `admin.py:313`: contar activas con `end_date >= now` y `status != "Deleted"`.
  4. Decidir si se sigue guardando `policy.status` (Flutter lo descarga en `/sync/download`; revisar `lib/` antes de eliminarlo) o se migra con Alembic.
- **Cómo verificar:** crear póliza con `end_date` ayer → portal la muestra "Vencida" (o no la lista, según la decisión) y admin igual. Crear otra con `end_date` en 10 días → aparece en el portal como "Por vencer". Prueba pytest comparando ambos endpoints.
- **Afecta al manual:** Sí. Portal, "Mis Pólizas": criterio de qué pólizas aparecen y qué etiquetas existen; admin, "Estado" de póliza (reglas 30 días).
- **Estado:** Pendiente

## H-10 — Portal: `pending_delivery` y `Reviewed-*` salen en crudo

- **Severidad:** Baja
- **Área:** clients
- **Dónde:** `clients/src/components/StatusBadge.jsx:1-25` (mapa `STATUS_MAP` sin esas claves; el fallback imprime el valor original).
- **Qué pasa hoy:** un reporte `pending_delivery` muestra el texto literal "pending_delivery"; `Reviewed-Approved/Rejected` igual. `signed`/`synced` se muestran como "Correcto".
- **Impacto:** texto técnico visible al cliente.
- **Arreglo propuesto:** añadir en `STATUS_MAP`: `pending_delivery` → "Pendiente de entrega", `reviewed-approved` → "Aprobado", `reviewed-rejected` → "Rechazado". Eliminar claves que el sistema no genera (`completado`, `pendiente`, `cancelado`) cuando se corrija H-04. No tocar `PolizaDetalle.jsx` (tiene su propio mapa).
- **Cómo verificar:** reporte con `status='pending_delivery'` en BD → badge "Pendiente de entrega" en Dashboard, Reportes e Historial.
- **Afecta al manual:** Sí. Tabla de estados del portal.
- **Estado:** Pendiente

## H-11 — Portal: Registro y Reset sin mensaje de éxito; reglas de contraseña solo en el front

- **Severidad:** Media
- **Área:** clients + backend
- **Dónde:** `clients/src/pages/Registro.jsx:78` (`navigate('/login', { state: { registered: true } })`), `clients/src/pages/Login.jsx` (nunca lee `location.state`), `clients/src/pages/ResetPassword.jsx:53` (navega sin estado); `server/app/schemas/portal.py:38-42` (`RegisterRequest.password: str`) y `:80-82` (`ResetPasswordRequest.new_password: str`) sin validación.
- **Qué pasa hoy:** tras registrarse o restablecer, el usuario cae en el login sin confirmación. El backend acepta cualquier contraseña (la regla "8 caracteres + mayúscula + número + especial `!@#$%^&*-`" solo se aplica en el navegador).
- **Impacto:** confusión del usuario; contraseñas débiles posibles llamando a la API directo.
- **Arreglo propuesto:** `Login.jsx`: `useLocation()` y mostrar banner "Cuenta creada. Inicia sesión." / "Contraseña actualizada. Inicia sesión." (pasar `state: { reset: true }` desde `ResetPassword.jsx:53`). `schemas/portal.py`: `field_validator` para ambas contraseñas con las mismas reglas (mensaje en español, 422). Alinear el conjunto de caracteres especiales de front y back. Considerar que `Login.jsx` exige `password.length < 8` (línea ~54) coherente con la regla.
- **Cómo verificar:** registrar usuario → el login muestra el banner. `curl -X POST $API/api/portal/register -d '{"token":"…","name":"x","password":"abc"}'` → 422. Prueba pytest para ambos endpoints.
- **Afecta al manual:** Sí. Flujos de registro y recuperación: añadir el mensaje de confirmación y las reglas validadas por el servidor.
- **Estado:** Pendiente

## H-12 — Portal, detalle de póliza: no filtra por planta cuando el usuario está restringido

- **Severidad:** Media
- **Área:** backend (clients sin cambio)
- **Dónde:** `server/app/api/routers/portal.py:928-1016` (`get_policy`: solo `policy.client_id != portal_user.client_id`), `:1019-1090` (`get_policy_delivery`), `:882-925` (`list_policies`); contraste con `_get_printer_ids_in_scope` en `:98-107`.
- **Qué pasa hoy:** un usuario invitado a una planta ve en la póliza **todas** las impresoras del cliente, y todas las entregas (con reportes de otras plantas) y los PDFs de esas entregas.
- **Impacto:** fuga de información entre plantas del mismo cliente.
- **Arreglo propuesto:** en `get_policy`, si `portal_user.plant_id`, filtrar `printers` a las de su planta (`_get_printer_ids_in_scope`); en entregas, mostrar solo reportes cuya impresora esté en alcance y ocultar entregas sin ninguno; `report_count` y `printer_count` recalculados. Confirmar con negocio si la póliza completa debe ser visible (decisión de producto) antes de implementar. `list_policies` puede quedar por cliente.
- **Cómo verificar:** usuario con `plant_id=A`, póliza con impresoras en A y B: `GET /api/portal/policies/{id}` solo devuelve las de A; `GET …/deliveries/{d}` no lista reportes de B.
- **Afecta al manual:** Sí. Portal, Detalle de póliza y la sección de alcance por planta.
- **Estado:** Pendiente

## H-13 — Admin, Detalle de cliente: invitación "enviada" aunque falle el SMTP; correo desactivado desaparece al recargar

- **Severidad:** Media
- **Área:** backend + admin-web
- **Dónde:**
  - Invitación: `server/app/api/routers/portal.py:254-256` (envío "non-blocking", errores solo en log) y `server/app/services/email_service.py` (`_send` captura y registra); `admin-web/src/pages/ClientDetailPage.tsx:183-192` (banner `Invitación enviada a …`).
  - Correos de contacto: `server/app/api/routers/admin.py:2093-2106` (`GET` filtra `is_active.is_(True)`); `ClientDetailPage.tsx:307-309` y `:337-355` (la UI mantiene la fila inactiva solo en memoria).
- **Qué pasa hoy:** si el SMTP falla, el banner dice "Invitación enviada a …" y la invitación queda "pending" sin que nadie se entere. Un correo desactivado con el toggle se ve "Inactivo" hasta recargar; después desaparece y no hay forma de reactivarlo.
- **Impacto:** invitaciones perdidas sin aviso; correos que no se pueden reactivar.
- **Arreglo propuesto:**
  1. `send_invitation_email` debe devolver `bool`; `invite_client` responde `email_sent: bool` en `InviteResponse` (`schemas/portal.py`); `ClientDetailPage.tsx` muestra aviso ámbar "Invitación creada pero no se pudo enviar el correo" si es `false`. Lo mismo para `forgot-password` solo en log (no cambiar la respuesta pública, por enumeración).
  2. `GET /clients/{id}/contact-emails`: aceptar `include_inactive=true`; `ClientDetailPage.tsx` lo pide en su query. La app Flutter y el portal siguen sin el parámetro (solo activos). No tocar el envío de correos (ya filtra activos).
- **Cómo verificar:** con `SMTP_HOST` inválido, invitar → el banner indica fallo. Desactivar un correo, recargar → sigue visible como "Inactivo" y se puede reactivar. `curl "$API/api/admin/clients/<id>/contact-emails?include_inactive=true"`.
- **Afecta al manual:** Sí. Invitar usuarios (mensaje de fallo) y Correos de contacto (los inactivos se conservan).
- **Estado:** Pendiente

## H-14 — Admin, visitas: "Regenerar" y eliminar visita sin confirmación; el servidor permite borrar en cualquier estado

- **Severidad:** Media
- **Área:** admin-web + backend
- **Dónde:** `admin-web/src/pages/PolicyDetailPage.tsx:943-952` (botón "Regenerar"), `:1042-1048` (X de cada visita); `server/app/api/routers/admin.py:2674-2691` (`DELETE /policies/{id}/visits`, borra todas) y `:2694-2711` (`DELETE …/visits/{id}`, "regardless of status"; incluye `print` de depuración en 2688/2700-2702 y en 2495-2497).
- **Qué pasa hoy:** un clic borra o regenera visitas, incluso la visita En curso o Completada (se pierde su `closed_reason` y el vínculo con entregas por `visit_id`). El botón "Regenerar" solo se oculta si hay alguna Completada, pero la X de una visita no.
- **Impacto:** pérdida de datos auditables por un clic accidental.
- **Arreglo propuesto:** (a) backend: rechazar con 409 el borrado de visitas `in_progress` o `completed`, o que tengan entregas con `visit_id`; (b) `PolicyDetailPage.tsx`: modal de confirmación para "Regenerar" y para eliminar ("Esto eliminará la visita N. ¿Continuar?"), deshabilitar la X en visitas En curso/Completadas; (c) quitar los `print(...)`. No tocar la lógica de cierre (`visit_service.py`).
- **Cómo verificar:** `curl -X DELETE -H "Authorization: Bearer $ADMIN_TOKEN" $API/api/admin/policies/<pid>/visits/<vid>` sobre visita `in_progress` → 409. En pantalla aparece el diálogo de confirmación. Pytest en `server/tests/test_visits.py`.
- **Afecta al manual:** Sí. Sección Visitas: confirmación al regenerar/eliminar y restricciones por estado.
- **Estado:** Pendiente

## H-15 — Impresoras: "Desactivar" no valida reportes; la inactiva sigue en el listado; "Eliminar" valida solo en el front

- **Severidad:** Media
- **Área:** admin-web + backend
- **Dónde:** `server/app/api/routers/admin.py:2397-2410` (`delete_printer`: solo `is_active=False`); `:675-745` (`list_printers` sin filtro `is_active`); `admin-web/src/pages/PrintersPage.tsx:677-711` (diálogo "Desactivar impresora", sin validación); `admin-web/src/pages/PrinterDetailPage.tsx:111-120` (valida `reportsData.total > 0` solo con la primera página cargada) y `:372-375` (texto "Solo es posible si no tiene reportes asociados").
- **Qué pasa hoy:** desde la lista, la impresora se desactiva aunque tenga reportes o pertenezca a una póliza; sigue visible sin etiqueta "Inactiva" (la lista no la muestra). Desde el detalle la regla "sin reportes" es solo del navegador. El portal oculta las inactivas.
- **Impacto:** inconsistencias entre admin y portal; la regla anunciada no se cumple por API.
- **Arreglo propuesto:** decidir una regla única (recomendado: desactivar siempre permitido si no está en una póliza vigente; "eliminar" no existe). Backend: validar en `delete_printer` (409 si pertenece a una póliza no vencida) y no mentir en el texto. `list_printers`: añadir `is_active` a `PrinterListItem` y `include_inactive` (por defecto ocultar inactivas); `PrintersPage.tsx`: badge "Inactiva" y chip para verlas. Unificar el texto de ambos diálogos ("Desactivar"). No tocar `bulk-upload`.
- **Cómo verificar:** `curl -X DELETE …/api/admin/printers/<id>` de una impresora en póliza vigente → 409. La lista no muestra inactivas por defecto; con el filtro, las muestra con badge.
- **Afecta al manual:** Sí. Impresoras: terminología (Desactivar), listado de inactivas y restricciones.
- **Estado:** Pendiente

## H-16 — Perfil de técnico: URL de firma con `hostname:8000` fijo y estados sin traducir

- **Severidad:** Baja
- **Área:** admin-web
- **Dónde:** `admin-web/src/pages/TechnicianProfilePage.tsx:127` (`${window.location.protocol}//${window.location.hostname}:8000`) usado en `:148`; `:55-59` y `:269-271` (muestra `r.status` crudo: Synced/Signed/Draft/pending_delivery). Mismo patrón crudo en `PrinterDetailPage.tsx:55-59, 325-327`.
- **Qué pasa hoy:** en producción (`app.mainservicepc.com`, sin puerto 8000) la imagen de la firma apunta a `https://app.mainservicepc.com:8000/uploads/...` y no carga. Los estados se muestran en inglés/crudo, a diferencia de `ReportsPage.tsx`.
- **Impacto:** firma rota; inconsistencia visual.
- **Arreglo propuesto:** usar `import.meta.env.VITE_API_URL` (como `ReportsPage.tsx:78`). Extraer el mapa `STATUS` de `ReportsPage.tsx` a `admin-web/src/lib/reportStatus.ts` y reutilizarlo en las tres pantallas. No tocar el backend.
- **Cómo verificar:** en producción el perfil del técnico muestra la firma; los estados se ven "Firmado", "Pendiente entrega", etc.
- **Afecta al manual:** Sí. Perfil de técnico y detalle de impresora: etiquetas de estado.
- **Estado:** Pendiente

## H-17 — Técnicos: administradores invisibles en la lista y técnicos inactivos sin indicación

- **Severidad:** Media
- **Área:** backend + admin-web
- **Dónde:** `server/app/api/routers/admin.py:591` (`.filter(User.role == "technician")` en el listado) y `:619` (detalle); `admin-web/src/pages/TechniciansPage.tsx:420-455` (tarjetas sin badge de estado); `:206-212` (selector de rol Técnico/Administrador); `PolicyDetailPage.tsx:371` (filtra `role === 'technician'` pero no `is_active`).
- **Qué pasa hoy:** al crear un usuario con rol "Administrador" desaparece de la lista: no se puede editar, cambiar contraseña ni desactivar desde la UI. Los técnicos inactivos siguen apareciendo igual que los activos y se pueden asignar a impresoras.
- **Impacto:** administración de usuarios incompleta; asignaciones a técnicos dados de baja.
- **Arreglo propuesto:** `list_technicians`: aceptar `role` (`technician|admin|all`) y devolver `is_active`; el front muestra badge "Inactivo" y un filtro de rol; el selector de asignación solo lista `is_active`. Añadir `is_active` a `TechnicianListItem` (`server/app/schemas/admin.py`). No cambiar el nombre de la ruta `/technicians` (la usa el front y quizá el sync).
- **Cómo verificar:** crear un admin desde el modal → aparece con filtro "Administradores". Desactivar un técnico → tarjeta con "Inactivo" y ya no está en el selector de asignación de pólizas.
- **Afecta al manual:** Sí. Técnicos: roles visibles, estado en tarjeta.
- **Estado:** Pendiente

## H-18 — Funciones solo por API (sin UI): decisión de alcance

- **Severidad:** Baja
- **Área:** admin-web + backend
- **Dónde y recomendación:**

  | Función | Endpoint / evidencia | ¿Construir UI? |
  |---|---|---|
  | Reactivar cliente / técnico / impresora | No existe endpoint de reactivación (`DELETE` hace baja lógica en `admin.py:2075, 1978, 2397`; `PUT` no acepta `is_active`) | **Sí, la más útil.** Añadir `is_active` a `ClientUpdate`, `TechnicianUpdate`, `PrinterUpdate` y un toggle en cada modal. |
  | Editar planta / contacto | `PUT /api/admin/plants/{id}` existe (`admin.py:2205`), `endpoints.ts:43` lo define; ninguna pantalla lo usa | Sí, bajo costo: edición en `ClientDetailPage.tsx` (tarjeta de plantas). |
  | Editar o desactivar modelos del catálogo | Solo `GET/POST /catalog/models` (`admin.py:2253, 2266`) | Fuera de alcance por ahora; los modelos se crean ad hoc. |
  | Revocar tokens de un técnico | `POST /api/admin/technicians/{id}/revoke-tokens` (`admin.py:1993`) | Sí, un botón en `TechnicianProfilePage.tsx` ("Cerrar sesiones"). Útil si se pierde un teléfono. Depende de H-01. |
  | Aprobar / rechazar reportes | `POST /api/admin/reports/{id}/review` (`admin.py:240`); estados `Reviewed-*` | Fuera de alcance salvo que el negocio quiera un flujo de revisión; si no, **quitar** del filtro de `ReportsPage.tsx:451` y del mapa de estados. |
  | `regenerate-links` sin envío | `admin.py:1875`, sin botón | Fuera de alcance (ya existe "Regenerar liga y reenviar"). |

- **Qué pasa hoy:** esas acciones solo se pueden hacer con curl/Swagger.
- **Impacto:** tareas operativas diarias (baja por error de un cliente) sin salida desde la UI.
- **Arreglo propuesto:** ver tabla. Implementar primero reactivar + revocar tokens; documentar el resto como "no disponible".
- **Cómo verificar:** reactivar un cliente desde la UI y verlo "Activo"; botón de cierre de sesiones invalida el token (`curl -H "Authorization: Bearer <token viejo>" $API/api/sync/status` → 401 "Sesión revocada").
- **Afecta al manual:** Sí. Cada función construida se documenta; las que se dejan fuera se listan como "no disponibles".
- **Estado:** Pendiente

## H-19 — PDFs, fotos y firmas servidos por `/uploads/...` sin token ni vencimiento

- **Severidad:** Alta
- **Área:** backend + admin-web + clients
- **Dónde:** `server/app/main.py:64-68` (`app.mount("/uploads", StaticFiles(...))`); URLs construidas en `admin.py:266-300`, `portal.py:820-880` (`get_report_files`), `portal.py:1060+` y `admin-web/src/pages/PolicyDetailPage.tsx:702` / `clients/src/pages/PolizaDetalle.jsx:228` (`pdf_path` directo), `ReportsPage.tsx:243`, `ReporteModal.jsx:109`. Nombre del PDF de entrega: `{folio}_{cliente}_{fecha}_V{n}-{total}.pdf` (`server/app/services/delivery_pdf_service.py`), predecible.
- **Qué pasa hoy:** cualquier persona con la URL descarga reportes, entregas, fotos, firmas y logos sin iniciar sesión, sin caducidad y sin revocación. Las ligas del correo (30 días, revocables, `/api/public/files/{token}`) sí protegen, pero el mismo archivo sigue disponible por `/uploads/...`. El nombre de los PDFs de entrega se puede adivinar (folio + cliente + fecha); los de reporte [VERIFICAR] dependen del nombre que suba la app.
- **Impacto:** las ligas con vencimiento son decorativas; fuga de documentos de clientes por URL adivinada o compartida; sin trazabilidad (`access_count` solo existe en ligas).
- **Arreglo propuesto (por fases):**
  1. Nginx/servidor: bloquear `/uploads/` salvo `/uploads/logos/` (el encabezado del portal usa `client-logo`).
  2. Backend: endpoints autenticados `GET /api/admin/files/{kind}/{id}` y `GET /api/portal/files/{kind}/{id}` que validen alcance (cliente/planta) y sirvan con `FileResponse`. Cambiar `get_report_files` (admin y portal) para devolver esas URLs; `fileUrl()` en los frontends debe enviar el token (usar `fetch` con `Authorization` y `blob:` o URLs firmadas de corta vida).
  3. Mantener `/api/public/files/{token}` para los correos. La app Flutter descarga firmas/fotos/PDFs vía `/uploads`? [VERIFICAR con `grep -rn "uploads" lib/`] antes de bloquear.
  4. Mientras tanto: agregar sufijo aleatorio al nombre de los PDFs nuevos de entrega.
- **Cómo verificar:** `curl -I $API/uploads/deliveries/<nombre>.pdf` → 404/403 sin token; con token de admin o portal con alcance → 200; con token del portal de otro cliente → 403. El enlace del correo sigue funcionando hasta su vencimiento y deja de funcionar al "Regenerar liga".
- **Afecta al manual:** Sí. "Ver PDF" / "Descargar PDF" requieren sesión; solo las ligas de correo son públicas con 30 días de vigencia.
- **Estado:** Implementado en la rama `fix/uploads-firmadas` (pendiente de deploy y de validar en producción).
- **Implementación (decisión: URLs firmadas HMAC, sin cambios en Flutter/APK):**
  - **Etapa 2a** (compatible; `/uploads` seguía montado): `GET /api/files/signed?p=<ruta relativa a UPLOAD_DIR>&e=<epoch>&s=<HMAC-SHA256>` (`server/app/api/routers/files.py`, `server/app/services/file_signing_service.py`). Firma inválida, vencida o ruta insegura → 403 con cuerpo idéntico; archivo inexistente → 404. Se firma `ruta
exp` y se compara con `hmac.compare_digest`; la ruta se resuelve con `Path.resolve()` y debe quedar dentro de `UPLOAD_DIR` (rechaza `..`, absolutas, backslash, NUL y symlinks que salgan). Vigencia `FILE_URL_TTL_SECONDS` (3600 s). `FILE_SIGNING_SECRET` es obligatorio con `APP_ENV=production` (≥ 32 caracteres, distinto del ejemplo) o la API no arranca.
  - Emisores que ahora devuelven URLs firmadas (formato relativo `/api/files/signed?...`, así `API_BASE + path` sigue valiendo): `admin.py` (`get_report_files`, firma de técnico, logo del cliente, entregas), `portal.py` (`get_report_files` con validación de alcance por cliente/planta, entregas) y `reports.py` (`_build_report_response`). Las entregas agregan `pdf_url` firmado y conservan `pdf_path`.
  - Normalización de rutas guardadas en BD (formatos reales de producción): `uploads/report/...` (`files.storage_path` es **relativa con prefijo `uploads/`**, no absoluta), `uploads/signature/...`, `uploads/delivery_pdf/...`, `uploads/deliveries/...`, `logos/...`; las rutas locales del teléfono (`/data/user/0/...`, 55 reportes en `reports.signature_image_path`) no existen en el servidor y se omiten.
  - `sync.py` (`POST /api/files`): `filename` reducido a basename seguro (≤ 120 caracteres), `entity_type`/`entity_id`/`file_category` validados (`^[A-Za-z0-9_.-]{1,128}$`) y verificación de que el destino resuelto esté dentro de `UPLOAD_DIR`.
  - **Etapa 2b** (commit aparte): se quita `app.mount("/uploads")` de `main.py` (`/static` intacto) y `GET /api/portal/client-logo` sirve el logo directo con `FileResponse` (solo bajo `logos/`) en vez de redirigir a `/uploads`.
  - Frontends: `PolicyDetailPage.tsx` y `PolizaDetalle.jsx` descargan el PDF de entrega con `pdf_url`; `TechnicianProfilePage.tsx` usa `VITE_API_URL` (antes `hostname:8000`, ver H-16). El resto ya usaba `API_BASE + url`.
  - Límite conocido: las URLs son compartibles mientras no venzan (1 h) y una página admin/portal abierta más de 1 h sin recargar muestra 403 al abrir un PDF; se resuelve recargando. Los correos siguen usando `/api/public/files/{token}` (sin cambios).
  - Pendiente (hallazgo aparte): `GET/PATCH /api/reports/{id}` y `POST /api/reports/{id}/send-email` aceptan a cualquier usuario interno activo sin comprobar autoría; coincide con que `/api/sync/download` entrega a todo técnico los reportes de los últimos 90 días.

## H-20 — Documentación del proyecto desactualizada

- **Severidad:** Baja
- **Área:** docs
- **Dónde:**
  - `CLAUDE.md` (estructura, ~línea 18-22): lista `/lib`, `/server`, `/admin-web` y omite `/clients` (portal).
  - `CLAUDE.md:14` — "Auth: JWT (7 días para móvil)"; el código usa 365 días con renovación en cada sync (`server/app/config.py:14`, `auth.py` `/refresh`); web/portal usan `access_token_expire_minutes` (`config.py:11`, default 60; `.env` local `ACCESS_TOKEN_EXPIRE_MINUTES=10080`).
  - `CLAUDE.md:58` — `UPLOAD_DIR=./uploads (relativo…)` vs `config.py:15` (`/var/smp/uploads`).
  - `.claude/context/project-status.md:1` ("Sprint 1 — Estado de Avance"), `:6` (worktree `eloquent-tesla` inexistente), `:106`; las secciones vigentes están al final (líneas ~1174-1199) y dicen "SIN commit / SIN deploy", ya contradichas por `git log` (b49cb92, 90153ed, d0571f0).
- **Qué pasa hoy:** quien abra una sesión nueva recibe contexto equivocado (por ejemplo, ignora el portal `clients/`).
- **Impacto:** trabajo duplicado y decisiones erróneas.
- **Arreglo propuesto:** editar `CLAUDE.md` (añadir `/clients` — React + Vite, `clientes.mainservicepc.com`; corregir sesión y `UPLOAD_DIR`); reordenar `project-status.md` con un bloque "Estado vigente" arriba (visitas, ligas, correo único, cierre de visita, estado de deploy) y mover Sprint 1 a "Histórico"; actualizar `.claude/context/sprint2-plan.md` si cita lo mismo. No tocar `docs/manual-tecnico.md`.
- **Cómo verificar:** `grep -n "clients" CLAUDE.md` muestra la carpeta; las duraciones coinciden con `config.py`; la primera sección de `project-status.md` es el estado vigente.
- **Afecta al manual:** No (indirecto: evita que se escriban manuales con datos viejos).
- **Estado:** Pendiente

## H-21 — Tooling: el hook `cbm-code-discovery-gate` falla y Glob/Grep dejan de usar codebase-memory-mcp

- **Severidad:** Baja
- **Área:** tooling
- **Dónde:** `C:\Users\Victor Caballero\.claude\settings.json:106` (`"command": "~/.claude/hooks/cbm-code-discovery-gate"`); script en `~/.claude/hooks/cbm-code-discovery-gate` (bash; el segundo hook `cbm-session-reminder` está en la misma carpeta).
- **Qué pasa hoy:** `~` se expande a `/c/Users/Victor Caballero`, la ruta contiene un espacio y al no estar entre comillas bash intenta ejecutar `/c/Users/Victor` (que es otro archivo) y falla con `syntax error near unexpected token '('`. Los PreToolUse de `Glob` y `Grep` devuelven error y se pierde el enriquecimiento de codebase-memory-mcp (verificado en esta sesión).
- **Impacto:** Glob/Grep muestran un error en cada llamada y hay que usar Bash como alternativa.
- **Arreglo propuesto:** en `settings.json:106` poner el comando entre comillas: `"command": "\"$HOME/.claude/hooks/cbm-code-discovery-gate\""` (revisar también la entrada de `cbm-session-reminder`). Alternativa: mover el repo/hook a una ruta sin espacios. No modificar el script del hook.
- **Cómo verificar:** en Claude Code, `Glob` y `Grep` ya no muestran `hook error`; `bash -c '"$HOME/.claude/hooks/cbm-code-discovery-gate" < /dev/null; echo $?'` devuelve 0.
- **Afecta al manual:** No.
- **Estado:** Pendiente

## H-22 — Admin, Reportes: no existe filtro "Pendiente entrega"

- **Severidad:** Baja
- **Área:** admin-web
- **Dónde:** `admin-web/src/pages/ReportsPage.tsx:451` (`STATUS_OPTIONS = ['Draft','Signed','Synced','Reviewed-Approved','Reviewed-Rejected']`); el mapa `STATUS` (línea 105-113) sí tiene `pending_delivery` ("Pendiente entrega").
- **Qué pasa hoy:** el estado `pending_delivery` aparece en la tabla pero no se puede filtrar; las opciones `Draft`, `Synced` y `Reviewed-*` casi no existen en datos reales (el servidor nunca asigna `Synced`; no hay UI de revisión).
- **Impacto:** no se puede listar lo pendiente de entrega, que es lo que bloquea cerrar visitas.
- **Arreglo propuesto:** cambiar `STATUS_OPTIONS` a `['Signed','pending_delivery']` (+ el resto si el negocio confirma que existen). Backend sin cambios (`admin.py:118` filtra por igualdad).
- **Cómo verificar:** el filtro muestra "Pendiente entrega" y devuelve solo esos reportes (`curl "$API/api/admin/reports?status=pending_delivery"`).
- **Afecta al manual:** Sí. Reportes: lista de estados del filtro.
- **Estado:** Pendiente

## H-23 — Admin, Pólizas: la fecha fin se recalcula sola según la frecuencia (posible regla incorrecta)

- **Severidad:** Media
- **Área:** admin-web (decisión de negocio)
- **Dónde:** `admin-web/src/pages/PoliciesPage.tsx:153-182` (`setField`): Anual +1 año, Semestral +6 meses, Trimestral +3, Bimestral +2, Mensual +1 mes; se vuelve a pisar cada vez que cambia el inicio o la frecuencia. Los números de visitas por frecuencia están en `admin.py:2440-2446` (`_FREQUENCY_VISIT_COUNT`: 12/6/4/2/1).
- **Qué pasa hoy:** "Mensual (12 visitas)" fija una vigencia de **1 mes** y "Trimestral (4 visitas)" de 3 meses; con esas fechas, "Generar visitas" reparte 12 visitas en 1 mes. Lo coherente parece ser vigencia de 12 meses para todas.
- **Impacto:** pólizas con vigencia equivocada y calendarios de visitas absurdos si el usuario no corrige la fecha.
- **Arreglo propuesto:** confirmar con negocio. Si la vigencia por defecto debe ser un año: fijar `end_date = start + 1 año − 1 día` en ambos cambios, sin pisar si el usuario ya la editó (guardar un flag `endDateTouched`). Si es intencional, documentarlo en el manual. Backend sin cambios.
- **Cómo verificar:** elegir inicio 2026-01-01 y "Mensual": fecha fin = 2026-12-31 (o lo acordado), y editarla a mano no se pierde al cambiar la frecuencia.
- **Afecta al manual:** Sí. Pólizas, campo "Fecha fin".
- **Estado:** Pendiente

## H-24 — Admin, visitas: "X/N equipos atendidos" cuenta reportes pendientes de entrega

- **Severidad:** Media
- **Área:** backend
- **Dónde:** `server/app/api/routers/admin.py:2448-2467` (`_build_visit_item`: `attended_count` = reportes `pending_delivery` de las impresoras de la póliza, sin relación con la visita); mostrado en `PolicyDetailPage.tsx:995-998, 1013-1017`.
- **Qué pasa hoy:** el contador baja a 0 cuando se firma la entrega (los reportes pasan a `Signed`) y no distingue visitas. Un reporte `pending_delivery` de una visita anterior suma en la actual.
- **Impacto:** el progreso mostrado no refleja el avance real de la visita; contradice el resumen de cierre (`visit_service.delivered_printer_ids`).
- **Arreglo propuesto:** reutilizar `visit_service`: para visitas `in_progress` devolver `attended_count = len(delivered_printers ∪ pending_printers)` filtrando `service_date >= visit.started_at`; para completadas, el conteo al cierre. Añadir campo `delivered_count` si se quiere ambos números. No tocar la regla de cierre automática.
- **Cómo verificar:** póliza con 3 equipos: tras reportar 2 (sin firmar) → "2/3"; tras firmar la entrega parcial → sigue "2/3" (hoy baja a "0/3"). Pytest en `test_visits.py`.
- **Afecta al manual:** Sí. Visitas: significado de "equipos atendidos".
- **Relacionado:** H-27 (el filtro `service_date >= started_at` que H-24 propone reutilizar tiene un defecto de zona horaria; corregir H-24 sin H-27 heredaría el error).
- **Estado:** Corregido en rama `fix/visitas-entregas` (sin desplegar). Servidor: `attended_count` = entregados ∪ `pending_delivery` (en curso) y nuevo `delivered_count`; badge usa `delivered_count`.

## H-25 — Portal: cuenta desactivada se muestra como credenciales inválidas; "Reenviar" invitación a usuario ya registrado

- **Severidad:** Baja
- **Área:** clients + admin-web
- **Dónde:** `clients/src/pages/Login.jsx:79-91` (cualquier error → "Credenciales inválidas…"; el backend devuelve 403 "Cuenta desactivada" en `portal.py:352-356`); `admin-web/src/pages/ClientDetailPage.tsx:643-648` (botón "Reenviar" en usuarios ya registrados) y `portal.py:200-260` (no revisa si el correo ya tiene `PortalUser`; el registro devuelve 409 en `:318-322`).
- **Qué pasa hoy:** el usuario desactivado cree que escribió mal la contraseña. El admin pulsa "Reenviar" sobre un usuario registrado, se manda una invitación que no se puede usar.
- **Impacto:** soporte innecesario.
- **Arreglo propuesto:** `Login.jsx`: si `err.response?.status === 403`, mostrar "Tu cuenta está desactivada. Contacta a tu proveedor." (sin revelar más). `ClientDetailPage.tsx`: quitar "Reenviar" de usuarios registrados (o cambiarlo por "Enviar enlace de recuperación" que llame a `/api/portal/forgot-password`); `invite_client` devolver 409 si el correo ya existe como `PortalUser`.
- **Cómo verificar:** desactivar usuario del portal y entrar → mensaje de cuenta desactivada. `POST /api/portal/invite` con un correo registrado → 409.
- **Afecta al manual:** Sí. Login del portal (mensajes) y gestión de usuarios (acción "Reenviar").
- **Estado:** Pendiente

## H-26 — Admin: "Clientes activos" cuenta también inactivos; clientes inactivos sin reactivar

- **Severidad:** Baja
- **Área:** backend + admin-web
- **Dónde:** `admin-web/src/pages/DashboardPage.tsx:133-145` (usa `res.data.total` de `/api/admin/clients`); `server/app/api/routers/admin.py:304-345` (sin filtro `is_active`); `admin-web/src/pages/ClientsPage.tsx:339-347` (badge Activo/Inactivo).
- **Qué pasa hoy:** la tarjeta del dashboard "Clientes activos" suma todos los clientes, inactivos incluidos.
- **Impacto:** KPI inflado.
- **Arreglo propuesto:** añadir `is_active: bool | None` al listado y que el dashboard pida `is_active=true`; mantener el listado completo por defecto. Reactivar: ver H-18.
- **Cómo verificar:** desactivar un cliente → la tarjeta baja en 1; `curl "$API/api/admin/clients?is_active=true&limit=1"` da el total correcto.
- **Afecta al manual:** Sí. Dashboard: definición de "Clientes activos".
- **Estado:** Pendiente

## H-27 — Visitas: "reporte de esta visita" compara `service_date` (hora local CDMX) con `started_at` (UTC); equipos entregados salen "Sin reporte" y la visita no se completa

- **Severidad:** Alta
- **Área:** backend + app Flutter (misma regla duplicada en ambos)
- **Relacionado:** H-24 (contador "X/N equipos atendidos"; este hallazgo es independiente y se suma a él). Caso observado: póliza POL-2026-009 (Vibra), visita 1/4 En curso.
- **Dónde:**
  - `server/app/services/visit_service.py:26-38` (`delivered_printer_ids`): `Report.service_date >= visit.started_at` (línea 37). Lo usan `auto_complete_if_all_delivered` (`:53-68`, línea 64) y `visit_close_summary` (`:84-112`, línea 87).
  - `server/app/api/routers/admin.py:2587` — `visit.started_at = _now_utc()` (`:84-85`: UTC sin tzinfo). Columnas `DateTime` sin zona: `server/app/models/policy.py:123`, `server/app/models/report.py:18`.
  - `server/app/api/routers/sync.py:673` — la visita viaja a la app como `started_at.isoformat()` **sin `Z`**; `lib/features/sync/services/sync_service.dart:718-722` la lee con `DateTime.parse`, que sin `Z` la interpreta como hora local.
  - Origen de `service_date`: la app lo crea con `DateTime.now()` (hora local del teléfono) y lo envía con `toIso8601String()` sin desfase (`lib/features/signature/presentation/signature_screen.dart:209, 237, 612, 789, 819`); el servidor lo guarda tal cual (`sync.py:93, 118`).
  - Misma comparación en la app: `policy_delivery_signature_screen.dart:177-180` (auto-completar local y decide `visit_id`), `policy_delivery_screen.dart:80-82`, `policy_dashboard_screen.dart:1651-1652, 1700-1703`, `reports_screen.dart:526-553`.
  - Asignación de `visit_id`: `policy_delivery_signature_screen.dart:158-169` (visita `in_progress` local de la póliza, siempre, aunque la entrega sea parcial; si no hay visita activa queda `null`); `sync.py:746` lo guarda sin validar. `report_ids` de la entrega = `args.reportIds` (`policy_delivery_screen.dart:107`, todos los reportes de la lista de entrega), y `sync.py:753-764` marca **todos** como `signed` sin mirar fechas. La relación entrega→reportes (`policy_delivery_reports`) sí queda guardada, pero `delivered_printer_ids` no la consulta.
- **Qué pasa hoy:**
  - Se comparan dos relojes distintos como si fueran el mismo: `started_at` es UTC y `service_date` es hora local (CDMX = UTC−6). Un reporte hecho **en las 6 horas siguientes a la activación** tiene un número de reloj menor que `started_at` y se descarta como "anterior a la visita", aunque sea posterior. Ejemplo del caso: activación 04:15 UTC del 27-oct (= 22:15 del 26-oct en CDMX); el ZT410 con `service_date` 26-oct 22:15–23:59 (local) es menor que `2026-10-27 04:15` y queda fuera; el ZT610 del 27-oct (hora local ≥ 04:15) entra.
  - El reporte descartado ya está `signed` (la entrega lo firmó), así que no es `pending_delivery`; el resumen lo clasifica `without_report` (`visit_service.py:93-99`) → "Sin reporte", y `delivered_count` = 1 de 2. Al faltar un equipo, `auto_complete_if_all_delivered` no completa la visita (`sync.py:790`).
  - Con una activación en horario laboral el efecto es peor: activación 10:00 CDMX (= 16:00 UTC) descarta todo reporte hecho entre 10:00 y 16:00 locales del mismo día.
  - "0/2 equipos atendidos" es el defecto de H-24 (`admin.py:2437-2445` solo cuenta `pending_delivery`, ya firmados no cuentan); no depende de la zona horaria. "1 entrega registrada" es correcto: es 1 entrega con 2 reportes.
  - Si el ZT410 se reportó **antes** de las 22:15 locales del 26-oct, la exclusión sería legítima (reporte previo a la activación); la hipótesis solo se confirma con los datos (consulta 2 de abajo).
- **Impacto:** visitas que no se completan solas, resumen de cierre que muestra "Sin reporte" para equipos ya entregados (el admin puede cerrar manualmente con un motivo falso o repetir trabajo); la app y el servidor pueden discrepar entre sí porque cada uno interpreta `started_at` con una zona distinta.
- **Arreglo propuesto:** **no definido todavía** (solo diagnóstico). Dirección a evaluar: definir "equipo entregado en la visita" por la relación `policy_deliveries.visit_id` → `policy_delivery_reports` → `reports` en vez de comparar fechas (cambiaría `visit_service.delivered_printer_ids`, `visit_close_summary`, el contador de H-24 y las 4 pantallas de la app que repiten el filtro), con decisión pendiente sobre entregas con `visit_id` nulo y reportes firmados antes de la visita.
- **Cómo verificar (diagnóstico, solo lectura en el VPS):** correr las consultas de abajo y comparar `service_date` contra `started_at` en ambos relojes.

  ```sql
  -- 1) Póliza y visita
  SELECT p.id AS policy_id, p.folio, v.id AS visit_id, v.visit_number, v.status,
         v.started_at AS started_at_utc,
         (v.started_at AT TIME ZONE 'UTC') AT TIME ZONE 'America/Mexico_City' AS started_at_cdmx
  FROM policies p JOIN policy_visits v ON v.policy_id = p.id
  WHERE p.folio = 'POL-2026-009' ORDER BY v.visit_number;

  -- 2) Reportes de los equipos de la póliza (status, service_date y comparación)
  SELECT pr.serial_number, r.code, r.status, r.service_date,
         r.service_date >= v.started_at AS cuenta_en_visita_hoy,
         r.service_date >= (v.started_at AT TIME ZONE 'UTC') AT TIME ZONE 'America/Mexico_City' AS cuenta_si_started_at_fuera_cdmx
  FROM policies p
  JOIN policy_visits v ON v.policy_id = p.id AND v.status = 'in_progress'
  JOIN policy_printers pp ON pp.policy_id = p.id
  JOIN printers pr ON pr.id = pp.printer_id
  JOIN reports r ON r.printer_id = pr.id
  WHERE p.folio = 'POL-2026-009'
  ORDER BY r.service_date;

  -- 3) Entrega(s): visit_id y reportes que lleva
  SELECT d.id AS delivery_id, d.visit_id, d.delivery_date, d.signature_name,
         r.code, r.status, r.service_date, pr.serial_number
  FROM policies p
  JOIN policy_deliveries d ON d.policy_id = p.id
  LEFT JOIN policy_delivery_reports dr ON dr.delivery_id = d.id
  LEFT JOIN reports r ON r.id = dr.report_id
  LEFT JOIN printers pr ON pr.id = r.printer_id
  WHERE p.folio = 'POL-2026-009'
  ORDER BY d.delivery_date, pr.serial_number;
  ```

  Resultado esperado si la hipótesis es cierta: el reporte del ZT410 con `status = 'signed'`, `service_date` entre `2026-10-26 22:15` y `2026-10-27 04:15`, `cuenta_en_visita_hoy = false` y `cuenta_si_started_at_fuera_cdmx = true`; la entrega con `visit_id` = id de la visita 1 y los dos reportes. (Nombres de tabla/columna tomados de los modelos; si `folio` o alguna columna difiere, ajustar.)
- **Afecta al manual:** Sí. Visitas: qué cuenta como "equipo entregado en la visita" y cierre automático/manual.
- **Estado:** Corregido en rama `fix/visitas-entregas` (sin desplegar), solo servidor: "entregado" = entrega con `visit_id` → `policy_delivery_reports`, sin comparar fechas. Pendiente en la app Flutter: las 4 pantallas con el filtro `service_date >= started_at` (no tocadas).

---

# A) Pendientes de verificar

| # | Qué verificar | Cómo comprobarlo | Relacionado |
|---|---|---|---|
| 1 | `ACCESS_TOKEN_EXPIRE_MINUTES` en producción (duración de sesión web/portal; en local es 10080 = 7 días, el default del código es 60) | En el servidor: `grep -E "ACCESS_TOKEN|MOBILE_TOKEN|PUBLIC_LINK|UPLOAD_DIR|API_BASE_URL|PORTAL_BASE_URL" /ruta/server/.env` (no pegar claves). Comprobar el claim `exp` de un token: `python -c "import jwt,sys;print(jwt.decode(sys.argv[1],options={'verify_signature':False}))" <token>` | H-20, manual (duración de sesión) |
| 2 | Endpoints `/api/admin/*` sin autenticación en producción | `curl -i $API/api/admin/clients`, `curl -i $API/api/admin/technicians`, `curl -i $API/api/reports/<id>` y `curl -i $API/api/policies` sin cabecera `Authorization`. Si devuelven 200, el hallazgo está confirmado | H-01 |
| 3 | Qué estados de reporte llegan realmente | `SELECT status, count(*) FROM reports GROUP BY status;` en PostgreSQL. Esperados: `Signed`, `pending_delivery`; confirmar si existen `Synced`, `Draft`, `Reviewed-*` | H-10, H-22 |
| 4 | Comportamiento real de "Eliminar póliza" y de pólizas vencidas en el portal | Eliminar una póliza de prueba y revisar `GET /api/admin/policies`. Ver `SELECT folio, status, end_date FROM policies ORDER BY end_date;` y compararlo con lo que muestra el portal de un cliente con una póliza vencida | H-08, H-09 |
| 5 | Regla de fecha fin automática por frecuencia (Mensual = +1 mes) | Preguntar al dueño del negocio; en pantalla crear póliza con "Mensual (12 visitas)" y ver la fecha fin sugerida | H-23 |
| 6 | Significado de "equipos atendidos" en visita en curso | Con una póliza de 3 equipos y una visita En curso: crear 2 reportes en la app, mirar el contador, firmar la entrega y volver a mirar | H-24 |
| 7 | La imagen de firma del técnico en producción | Abrir `https://app.mainservicepc.com/technicians/<id>` con DevTools → Network: la petición a `…:8000/uploads/…` falla | H-16 |
| 8 | Alcance por planta en pólizas del portal (¿es intencional que se vean todas las impresoras?) | Preguntar al negocio; probar con un usuario invitado a una planta y revisar `GET /api/portal/policies/{id}` | H-12 |
| 9 | Si ya se hizo deploy de los commits del 21–22/10/2026 (`b49cb92`, `90153ed`, `d0571f0`) | `git log --oneline origin/main..HEAD` y `git branch -a --contains b49cb92`; en el servidor, `git -C /ruta/repo log -1 --format=%h` y `alembic current` (deben figurar 011–015); `curl $API/api/health`; comprobar que el admin muestra "Cerrar visita" en una visita En curso | H-20 |
| 10 | Ver si la app Flutter descarga archivos vía `/uploads/` (antes de bloquearlo) | `grep -rn "uploads" lib/ --include=*.dart` y revisar `sync_service.dart` | H-19 |
| 11 | Ruta de PDF de reportes (nombre del archivo) para evaluar si es adivinable | `SELECT storage_path FROM files WHERE storage_path LIKE '%pdf' LIMIT 5;` | H-19 |
| 12 | Si el ZT410 de POL-2026-009 quedó fuera de la visita por zona horaria | Consultas SQL del apartado "Cómo verificar" de H-27 | H-27, H-24 |

---

# B) Orden sugerido de trabajo

**Sesión 1 — Seguridad y autenticación (hacer ANTES de escribir los manuales)**
- H-01 (auth en `/api/admin/*`, excepción para el `GET` de contact-emails que usa la app, endpoints propios del portal), H-02 (rol en login y mensajes), H-19 (cerrar `/uploads`, al menos la fase 1 y 2).
- Dependencias: H-02 y H-01 comparten `app/auth.py`. H-19 requiere decidir cómo los frontends envían el token. Antes de desplegar H-01 hay que publicar la versión de la app compatible, o conservar el `GET` de contact-emails para técnicos.
- Después de esta sesión se pueden escribir los capítulos de Login, roles y descargas de PDF.

**Sesión 2 — Datos incorrectos del admin (hacer ANTES de escribir los capítulos correspondientes)**
- H-03 (Sincronización), H-07 (filtros tras paginar y KPI), H-08 (póliza eliminada), H-09 (estado de póliza único), H-24 (equipos atendidos), H-23 (fecha fin automática, depende de decisión de negocio), H-22 (filtro Pendiente entrega), H-26 (KPI clientes).
- Dependencias: H-08 debe ir antes de H-07 (el filtro SQL excluye `Deleted`) y H-09 comparte el helper de estado con H-07. H-09 también afecta al portal.

**Sesión 3 — Portal de clientes**
- H-04, H-05, H-06 (cálculos en servidor), H-10 (etiquetas), H-11 (mensajes y validación de contraseña), H-12 (alcance por planta, decisión de negocio), H-25 (login desactivado y "Reenviar").
- Dependencias: H-04 y H-10 conviene hacerlas juntas (mapa de estados). H-05 y H-06 se apoyan en las consultas de `portal.py` y deben compartir el helper de alcance `_get_printer_ids_in_scope`. H-09 (sesión 2) debe estar hecho antes de cerrar la lista de pólizas del portal.
- Antes de escribir el manual del portal conviene tener al menos H-04, H-05, H-06 y H-10; H-11 y H-12 pueden esperar si el manual documenta el comportamiento actual con una nota.

**Sesión 4 — Operación del admin, limpieza y documentación (puede esperar a después de los manuales)**
- H-13 (SMTP y correos inactivos), H-14 (confirmaciones de visitas), H-15 (desactivar impresoras), H-16 (firma y estados), H-17 (técnicos admin/inactivos), H-18 (reactivar, editar plantas, revocar tokens), H-20 (docs), H-21 (hook).
- Dependencias: H-18 depende de H-01 (los nuevos endpoints nacen con `require_admin`) y de H-17 (campo `is_active` en el listado). H-21 no depende de nada y se puede hacer en cualquier momento (conviene antes, para recuperar Glob/Grep con codebase-memory-mcp en las demás sesiones).

**Qué puede esperar sin bloquear los manuales:** H-13 a H-18, H-20, H-21, H-25 y H-26, siempre que el manual describa el comportamiento actual o lo marque como "pendiente de mejora". **Qué no conviene escribir todavía:** capítulos de Sincronización (H-03), Dashboard del portal (H-05), Detalle de impresora del portal (H-04), estados de póliza (H-08, H-09), fechas de pólizas (H-23) y roles/permisos (H-01, H-02).
