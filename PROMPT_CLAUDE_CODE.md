# Prompt para Claude Code — Enlazar Base de Datos con la UI

## Contexto del Proyecto

Aplicación Flutter offline-first para gestión de mantenimiento industrial (CMMS).
Stack: Flutter + Drift (SQLite) + Riverpod + go_router.

El schema de la base de datos está **100% completo** en `lib/data/local/app_database.dart`.
Las pantallas tienen **UI completa y pulida**.

**El problema**: la mayoría de las pantallas usan datos mock/hardcodeados en lugar de leer/escribir en la base de datos real.

---

## Archivos clave de referencia

| Archivo | Rol |
|---|---|
| `lib/data/local/app_database.dart` | Schema Drift completo (tablas, columnas, relaciones) |
| `lib/data/local/local_database.dart` | Singleton `localDatabase` |
| `lib/core/router/app_router.dart` | Rutas con go_router |
| `lib/core/router/route_args.dart` | Clases de argumentos de navegación |
| `lib/features/reports/providers/capture_provider.dart` | Estado del reporte en curso |

---

## PRIORIDAD 1 — CRÍTICO: El flujo de creación de reportes está roto

### 1.1 — `PrinterSummary` le falta el campo `printerId`

**Archivo**: `lib/features/printers/models/printer_summary.dart`

El modelo `PrinterSummary` no tiene el campo `printerId` (el UUID interno del registro en la tabla `printers`). Sin este campo, es imposible enlazar un reporte con una impresora real.

**Fix**: Agregar `final String printerId;` al modelo `PrinterSummary` como campo requerido.

---

### 1.2 — `PrinterConfirmationScreen` no pasa `printerId` al crear reporte

**Archivo**: `lib/features/printers/presentation/printer_confirmation_screen.dart`

El botón "Crear reporte" llama:
```dart
onCreateReport: () => context.pushNamed(AppRoutes.capture)
```
No pasa ningún `CaptureArgs`. Resultado: `captureProvider.printerId` siempre es `null`.

**Fix**: Cambiar la llamada para pasar el `printerId` del `PrinterSummary`:
```dart
onCreateReport: () => context.pushNamed(
  AppRoutes.capture,
  extra: CaptureArgs(printerId: printer.printerId),
)
```

---

### 1.3 — `SignatureScreen._onFinishPressed()` NO guarda a la base de datos

**Archivo**: `lib/features/signature/presentation/signature_screen.dart`

El método `_onFinishPressed()` valida el formulario y muestra un diálogo de éxito, pero **nunca escribe nada en la base de datos**. Este es el bug más crítico de toda la app.

**Fix**: Conectar `SignatureScreen` con `captureProvider` (usando `ConsumerStatefulWidget`) y al presionar "Finalizar y Guardar Reporte":

1. Leer el estado completo de `captureProvider`
2. Insertar un registro en la tabla `reports` con:
   - `id`: nuevo UUID v4
   - `printerId`: `captureProvider.printerId` (no puede ser null en este punto)
   - `techId`: ID del usuario desde `sessionProvider` (usar un ID por defecto si la sesión no tiene uno real aún)
   - `serviceType`: `captureProvider.selectedServiceType`
   - `status`: `'pendiente_sync'`
   - `serviceDate`: `DateTime.now()`
   - `linearInchesCounter`: `int.parse(captureProvider.counterValue)`
   - `darknessLevel`: parsear `captureProvider.darknessValue` si no está vacío
   - `labelTypeId`: `null` por ahora (se resuelve en prioridad 2)
   - `technicalCheckboxes`: `captureProvider.checkValues`
   - `notes`: `captureProvider.notes`
   - `signatureName`: `_signerNameController.text.trim()`
   - `signatureRole`: `_signerRoleController.text.trim()`
   - `syncDate`: `null` (pendiente de sync)
3. Llamar `captureProvider.notifier.resetCapture()` después de guardar
4. Navegar a `/dashboard` solo si el guardado fue exitoso
5. Si hay error en el guardado, mostrar un SnackBar de error y NO navegar

El `localDatabase` está disponible en `lib/data/local/local_database.dart`.

---

### 1.4 — `ReportSummaryScreen` muestra datos hardcodeados de impresora

**Archivo**: `lib/features/reports/presentation/report_summary_screen.dart`

```dart
static const String _serial = '99J882';        // HARDCODED
static const String _model = 'ZT610';          // HARDCODED
static const String _counterPrevious = '100,000'; // HARDCODED
```

**Fix**:
1. Convertir a `ConsumerWidget` si no lo es ya
2. Leer `captureProvider.printerId`
3. Crear un `FutureProvider.family<PrinterDetail?, String>` que dado un `printerId` haga un JOIN de `printers` + `catalog_models` + `clients` y devuelva los datos de la impresora (serial, modelo, nombre del cliente)
4. Crear otro `FutureProvider.family<Report?, String>` que dado un `printerId` devuelva el **último reporte guardado** (el más reciente por `createdAt`) para mostrar el contador anterior en la gráfica de barras
5. Mostrar loading mientras cargan los datos; mostrar `'-'` si no hay datos previos

---

## PRIORIDAD 2 — ALTO: Pantallas con datos completamente mock

### 2.1 — `ClientListScreen` nunca usa la base de datos

**Archivo**: `lib/features/clients/presentation/client_list_screen.dart`

La pantalla recibe `database` como parámetro pero usa `_mockClients` hardcodeado. Los filtros y búsqueda operan sobre esos datos falsos.

**Fix**:
1. Crear un `StreamProvider<List<ClientWithStats>>` (o `FutureProvider`) que haga una query a la tabla `clients` con JOIN a `printers` (para contar unidades) y JOIN a `policies` (para contar pólizas activas y determinar el status: `stable` | `noPolicy` | `risk`)
   - `risk` = tiene póliza pero algún equipo tiene historial de fallas recurrentes (simplificar: para ahora, `risk` = tiene póliza que vence en menos de 30 días)
   - `noPolicy` = no tiene ninguna póliza activa
   - `stable` = tiene póliza activa vigente
2. Reemplazar `_mockClients` con el resultado del provider
3. Aplicar los filtros (`activePolicy`, `noPolicy`, `risk`) y la búsqueda sobre los datos reales
4. El campo `contact` puede venir del nombre del contacto de su planta principal (`plants.contactName`)

---

### 2.2 — `AddClientScreen._onSubmit()` no guarda a la base de datos

**Archivo**: `lib/features/clients/presentation/add_client_screen.dart`

El método `_onSubmit()` hace `await Future.delayed(250ms)` y muestra éxito, pero **nunca inserta nada en la DB**.

El método `_confirmDeleteClient()` también confirma la eliminación pero **nunca la ejecuta en DB**.

**Fix para `_onSubmit()`**:

En modo **crear** (`!isEditMode`):
1. Generar UUID para `clientId`
2. Insertar en tabla `clients` (nombre, RFC, dirección)
3. Por cada `_PlantDraft` en `_plantDrafts`:
   - Generar UUID para `plantId`
   - Insertar en tabla `plants` (con `clientId`, nombre, contacto, teléfono)
   - Crear un `Area` por defecto llamada `"General"` para esa planta (generar UUID para `areaId`, insertar en `areas`)
4. Todo dentro de una transacción `database.transaction(...)`

En modo **editar** (`isEditMode`):
1. Actualizar registro en tabla `clients`
2. Para las plantas: actualizar las existentes, insertar las nuevas

**Fix para `_confirmDeleteClient()`**:
1. Actualizar `isActive = false` en la tabla `clients` (soft delete, no borrado físico)

---

### 2.3 — `QrScannerScreen` búsqueda manual mock y recientes hardcodeados

**Archivo**: `lib/features/qr_scanner/presentation/qr_scanner_screen.dart`

- El botón "Buscar" muestra un SnackBar pero no hace ninguna query
- Las "Búsquedas Recientes" son una lista `_mockRecentSearches` hardcodeada

**Fix**:

**Búsqueda manual**:
1. Al presionar "Buscar", ejecutar una query a la tabla `printers` filtrando por `serialNumber` (LIKE o exact match)
2. Hacer un JOIN con `clients`, `plants`, `areas` y `catalog_models` para obtener los datos del `PrinterSummary`
3. Si se encuentra, navegar a `PrinterConfirmationScreen` con el resultado
4. Si no se encuentra, mostrar SnackBar "No se encontró ninguna impresora con ese serial"

**"Búsquedas Recientes"**:
- Por ahora, simplificar: mostrar las últimas 5 impresoras que tienen al menos un reporte (las más recientemente servidas), ordenadas por `reports.createdAt DESC`
- Hacer el JOIN necesario para construir el `PrinterSummary` completo

---

### 2.4 — `QuickAddPrinterScreen` carga opciones hardcodeadas y usa IDs falsos

**Archivo**: `lib/features/printers/presentation/quick_add_printer_screen.dart`

Los dropdowns de Cliente, Planta y Área usan listas hardcodeadas (`_clientOptions`, `_plantOptions`, `_areaOptions`) con IDs mock (`_mockClientIds`, `_mockPlantIds`, `_mockAreaIds`).

**Fix**:
1. Al cargar la pantalla, hacer un query a `clients` (donde `isActive = true`) para llenar el dropdown de clientes
2. Cuando el usuario selecciona un cliente, cargar las plantas de ese cliente desde la tabla `plants`
3. Cuando el usuario selecciona una planta, cargar las áreas de esa planta desde `areas`
4. Usar los IDs reales de los registros al guardar la impresora (ya no los mock IDs hardcodeados)
5. Agregar un botón "Crear Nuevo Cliente" que navegue a `/clients/add` (ya existe la ruta)

---

## PRIORIDAD 3 — MEDIO: Inicialización de catálogos

### 3.1 — Sembrar datos iniciales de catálogos al abrir la app

**Archivo**: `lib/data/local/app_database.dart` (método `beforeOpen` en `MigrationStrategy`)

Las tablas de catálogos (`catalog_label_types`, `catalog_actions`, `catalog_parts`, `catalog_failures`) están vacías. La app necesita datos iniciales para funcionar.

**Fix**: En el `beforeOpen` de la `MigrationStrategy`, insertar los datos iniciales usando `insertOnConflictUpdate` (para que sea idempotente):

**`catalog_label_types`** (mapeo con `kLabelTypes` de `capture_provider.dart`):
```
'Papel TT'
'Papel TD'
'Plástica (BOPP/Poliéster)'
```

**`catalog_failures`** (mapeo con `kChecklistItems` de `capture_provider.dart`):
```
'Mantenimiento general'
'Calibración sensores'
'Rodillo dañado'
'Cabezal dañado'
'Sensor ribbon dañado'
'Sensor papel dañado'
'Pruebas'
'Otros'
```

Usar IDs deterministas (UUID v5 o simplemente UUIDs fijos hardcodeados como strings) para que siempre sean los mismos.

---

### 3.2 — Guardar `labelTypeId` real en el reporte

Una vez sembrados los catálogos, al guardar el reporte en `SignatureScreen`:
- Buscar el `CatalogLabelType` cuyo `name` coincida con `captureProvider.selectedLabelType`
- Guardar su `id` en `reports.labelTypeId`

---

## PRIORIDAD 4 — MEDIO: Autenticación básica con DB

### 4.1 — `AuthProvider.login()` siempre hardcodea el usuario

**Archivo**: `lib/features/auth/providers/auth_provider.dart`

El login siempre asigna `userName: 'Juan Perez'` y `techId: '#T-8492'` sin consultar la DB.

**Fix** (implementación pragmática para proyecto terminal):
1. Al hacer login, buscar en la tabla `users` un registro donde `email = identifier`
2. Si existe, tomar su `id`, `name` y `role` para el `sessionProvider`
3. Si no existe (primer uso), crear un usuario con los datos del formulario y asignarlo
4. Esto permite que el `techId` en los reportes sea un UUID real de la tabla `users`

**Nota**: No hay contraseñas reales en la DB — el PIN es solo UI/local por ahora (el proyecto es offline-first para uso interno de la empresa).

---

## PRIORIDAD 5 — BAJO: Pantallas de solo lectura que muestran datos mock

Estas pantallas necesitan datos reales pero son de menor prioridad porque no rompen el flujo principal:

### 5.1 — `PrinterInventoryScreen`
Mostrar impresoras reales desde la tabla `printers` con JOIN a `clients`, `plants`, `areas`, `catalog_models`. Aplicar los filtros del `printerInventoryProvider`.

### 5.2 — `PrinterDetailScreen` y `ServiceHistoryScreen`
Cargar el historial de reportes de una impresora específica desde `reports` JOIN `users` para mostrar quién hizo el servicio.

### 5.3 — `PolicyDashboardScreen`
Cargar pólizas reales desde `policies` con estado calculado (activa/vencida/por vencer).

---

## Instrucciones generales para Claude Code

1. **No romper lo que funciona**: `QuickAddPrinterScreen._onSaveAndCreateReport()` ya guarda en DB correctamente. No tocar su lógica central de inserción, solo corregir que cargue opciones reales del menú.

2. **Usar el `localDatabase` singleton**: Importar desde `package:industrial_service_reports/data/local/local_database.dart`. No crear nuevas instancias de `AppDatabase`.

3. **Para providers con DB usar `StreamProvider` cuando sea posible**: Drift tiene soporte nativo para `Stream<List<T>>` via `.watch()` que se integra perfectamente con Riverpod para actualización reactiva.

4. **Manejo de errores**: Los métodos que escriben en DB deben tener try/catch y mostrar SnackBar de error si falla.

5. **UUIDs**: Usar el paquete `uuid` (ya en `pubspec.yaml`) con `const Uuid().v4()` para generar IDs.

6. **No modificar el schema de la DB** (`app_database.dart` ni `app_database.g.dart`). Si necesitas regenerar el código generado, ejecutar `dart run build_runner build`.

7. **Orden de implementación recomendado**: Prioridad 1 → 2.2 (AddClient) → 2.1 (ClientList) → 3.1 (Catálogos seed) → resto.

---

## Estado actual del flujo principal (para referencia)

```
QR Scanner (mock)
  → PrinterConfirmationScreen (no pasa printerId al capture) ← BUG 1.2
    → ExpressCaptureScreen (UI funcional, estado en captureProvider)
      → ReportSummaryScreen (datos de impresora hardcodeados) ← BUG 1.4
        → SignatureScreen (NO GUARDA EN DB) ← BUG 1.3 CRÍTICO
          → Dashboard
```

El flujo correcto post-fix:
```
QR Scanner (query real por serial/qr)
  → PrinterConfirmationScreen (pasa printerId)
    → ExpressCaptureScreen (printerId guardado en captureProvider)
      → ReportSummaryScreen (carga datos reales de printer + último reporte)
        → SignatureScreen (guarda Report completo en DB → resetCapture → Dashboard)
```
