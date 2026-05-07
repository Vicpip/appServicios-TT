import 'dart:convert';
import 'dart:io' as io;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:industrial_service_reports/core/constants.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/features/auth/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Result
// ---------------------------------------------------------------------------

/// Summary returned after a sync run.
class SyncResult {
  const SyncResult({
    required this.processed,
    required this.succeeded,
    required this.failed,
  });

  /// Total items that were attempted.
  final int processed;

  /// Items successfully uploaded to the server.
  final int succeeded;

  /// Items that failed (will be retried on the next run unless max attempts reached).
  final int failed;
}

// ---------------------------------------------------------------------------
// SyncService
// ---------------------------------------------------------------------------

/// Uploads pending [SyncQueue] entries to the FastAPI backend.
///
/// Usage:
/// ```dart
/// final result = await SyncService(database).runSync(
///   onProgress: (msg) => print(msg),
/// );
/// ```
class SyncService {
  SyncService(this._db);

  final AppDatabase _db;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Process every item whose [SyncQueueData.estadoPeticion] is `'pending'`.
  ///
  /// [baseUrl]     – server root URL, e.g. `http://10.0.2.2:8000`.
  /// [onProgress]  – called after each item with a human-readable status string.
  /// [retryFailed] – when true, resets all 'failed' items to 'pending' with
  ///                 0 attempts before processing, giving them fresh retries.
  Future<SyncResult> runSync({
    String baseUrl = kServerBaseUrlDevice,
    void Function(String message)? onProgress,
    bool retryFailed = false,
  }) async {
    // ignore: avoid_print
    print('[SyncService] runSync → baseUrl=$baseUrl');
    // Reject sync immediately if the JWT is absent or expired so the UI can
    // prompt re-login without sending a single request to the server.
    final AuthService authService = AuthService();
    if (!await authService.hasValidTokenForSync()) {
      throw const TokenExpiredException();
    }

    // Step 0: Download server data (non-fatal if offline)
    try {
      onProgress?.call('Descargando datos del servidor...');
      await downloadData(baseUrl: baseUrl);
    } catch (e) {
      // ignore: avoid_print
      debugPrint('[Sync] downloadData error: $e');
      onProgress?.call('Sin conexión — usando datos locales');
    }

    // Reset 'failed' items so they get fresh attempts in this run
    if (retryFailed) {
      await (_db.update(_db.syncQueue)
            ..where((SyncQueue q) => q.estadoPeticion.equals('failed')))
          .write(SyncQueueCompanion(
        estadoPeticion: const Value<String>('pending'),
        intentosFallidos: const Value<int>(0),
        lastError: const Value<String?>(null),
        updatedAt: Value<DateTime>(DateTime.now()),
      ));
    }

    final List<SyncQueueData> pending = await (_db.select(_db.syncQueue)
          ..where((SyncQueue q) => q.estadoPeticion.equals('pending')))
        .get();

    // Read JWT once for all requests in this sync run.
    final String? authToken = await authService.getToken();

    int succeeded = 0;
    int failed = 0;

    for (int i = 0; i < pending.length; i++) {
      final SyncQueueData item = pending[i];
      onProgress?.call(
        '${i + 1}/${pending.length} — ${_entityLabel(item.entityType)}',
      );

      try {
        await _processItem(item, baseUrl, authToken);

        // Mark as synced
        await (_db.update(_db.syncQueue)
              ..where((SyncQueue q) => q.id.equals(item.id)))
            .write(SyncQueueCompanion(
          estadoPeticion: const Value<String>('synced'),
          updatedAt: Value<DateTime>(DateTime.now()),
        ));
        succeeded++;
      } catch (e) {
        final int newAttempts = item.intentosFallidos + 1;
        final String newStatus =
            newAttempts >= kMaxSyncAttempts ? 'failed' : 'pending';

        // Truncate error to 300 chars so the UI stays readable.
        final String errorMsg = e.toString().length > 300
            ? '${e.toString().substring(0, 297)}...'
            : e.toString();

        await (_db.update(_db.syncQueue)
              ..where((SyncQueue q) => q.id.equals(item.id)))
            .write(SyncQueueCompanion(
          estadoPeticion: Value<String>(newStatus),
          intentosFallidos: Value<int>(newAttempts),
          lastError: Value<String>(errorMsg),
          updatedAt: Value<DateTime>(DateTime.now()),
        ));
        failed++;
      }
    }

    // Stamp lastSyncAt on all user records when at least one item succeeded
    if (succeeded > 0) {
      final DateTime now = DateTime.now();
      await (_db.update(_db.users))
          .write(UsersCompanion(lastSyncAt: Value<DateTime>(now)));
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_sync_timestamp', now.toIso8601String());
      } catch (_) {}
    }

    return SyncResult(
      processed: pending.length,
      succeeded: succeeded,
      failed: failed,
    );
  }

  // ---------------------------------------------------------------------------
  // Internal dispatch
  // ---------------------------------------------------------------------------

  Future<void> _processItem(
    SyncQueueData item,
    String baseUrl,
    String? authToken,
  ) async {
    switch (item.entityType) {
      case 'report':
        await _upsertDependencies(item, baseUrl, authToken);
        await _syncReport(item, baseUrl, authToken);
      case 'file':
      case 'signature':
      case 'pdf':
        await _syncFile(item, baseUrl, authToken);
      case 'policy_delivery':
        await _syncPolicyDelivery(item, baseUrl, authToken);
      case 'report_update':
        await _syncReportUpdate(item, baseUrl, authToken);
    }
  }

  // ---------------------------------------------------------------------------
  // Download — GET /api/sync/download  (seeds local DB from server)
  // ---------------------------------------------------------------------------

  Future<void> downloadData({
    String baseUrl = kServerBaseUrlDevice,
  }) async {
    final AuthService authService = AuthService();
    final String? authToken = await authService.getToken();
    final String url = '$baseUrl/api/sync/download';
    // ignore: avoid_print
    print('[SyncService] GET $url');

    final http.Response response = await http.get(
      Uri.parse(url),
      headers: <String, String>{
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;

    // Insert in topological order: catalogModels → clients → plants → areas → printers → policies → reports → technicians → assignments → visits
    // technicians must come before assignments (FK: technician_id → users.id)
    final List<dynamic> catalogModels =
        (data['catalogModels'] as List<dynamic>?) ?? <dynamic>[];
    for (final dynamic m in catalogModels) {
      final Map<String, dynamic> d = m as Map<String, dynamic>;
      await _db
          .into(_db.catalogModels)
          .insertOnConflictUpdate(CatalogModelsCompanion.insert(
            id: d['id'] as String,
            brand: d['brand'] as String,
            modelName: d['modelName'] as String,
            dpi: d['dpi'] as int,
            isActive: Value<bool>(d['isActive'] as bool? ?? true),
          ));
    }

    final List<dynamic> clients =
        (data['clients'] as List<dynamic>?) ?? <dynamic>[];
    for (final dynamic c in clients) {
      final Map<String, dynamic> d = c as Map<String, dynamic>;
      await _db.into(_db.clients).insertOnConflictUpdate(
            ClientsCompanion.insert(
              id: d['id'] as String,
              name: d['name'] as String,
              rfc: Value<String?>(d['rfc'] as String?),
              address: Value<String?>(d['address'] as String?),
              isActive: Value<bool>(d['isActive'] as bool? ?? true),
            ),
          );
    }

    final List<dynamic> plants =
        (data['plants'] as List<dynamic>?) ?? <dynamic>[];
    for (final dynamic p in plants) {
      final Map<String, dynamic> d = p as Map<String, dynamic>;
      await _db.into(_db.plants).insertOnConflictUpdate(
            PlantsCompanion.insert(
              id: d['id'] as String,
              clientId: d['clientId'] as String,
              name: d['name'] as String,
              contactName: Value<String?>(d['contactName'] as String?),
              phone: Value<String?>(d['phone'] as String?),
            ),
          );
    }

    final List<dynamic> areas =
        (data['areas'] as List<dynamic>?) ?? <dynamic>[];
    for (final dynamic a in areas) {
      final Map<String, dynamic> d = a as Map<String, dynamic>;
      await _db.into(_db.areas).insertOnConflictUpdate(
            AreasCompanion.insert(
              id: d['id'] as String,
              plantId: d['plantId'] as String,
              name: d['name'] as String,
            ),
          );
    }

    final List<dynamic> printers =
        (data['printers'] as List<dynamic>?) ?? <dynamic>[];
    for (final dynamic pr in printers) {
      final Map<String, dynamic> d = pr as Map<String, dynamic>;
      await _db.into(_db.printers).insertOnConflictUpdate(
            PrintersCompanion.insert(
              id: d['id'] as String,
              code: Value<String?>(d['code'] as String?),
              qrUuid: d['qrUuid'] as String,
              serialNumber: d['serialNumber'] as String,
              clientId: d['clientId'] as String,
              plantId: d['plantId'] as String,
              areaId: d['areaId'] as String,
              modelId: d['modelId'] as String,
              isActive: Value<bool>(d['isActive'] as bool? ?? true),
            ),
          );
    }

    final List<dynamic> policies =
        (data['policies'] as List<dynamic>?) ?? <dynamic>[];
    for (final dynamic pol in policies) {
      final Map<String, dynamic> d = pol as Map<String, dynamic>;
      await _db.into(_db.policies).insertOnConflictUpdate(
            PoliciesCompanion.insert(
              id: d['id'] as String,
              code: Value<String?>(d['code'] as String?),
              clientId: d['clientId'] as String,
              folio: d['folio'] as String,
              startDate: DateTime.parse(d['startDate'] as String),
              endDate: DateTime.parse(d['endDate'] as String),
              coverageType: d['coverageType'] as String,
              slaNotes: Value<String?>(d['slaNotes'] as String?),
              frequencyMaintenance:
                  Value<String?>(d['frequencyMaintenance'] as String?),
              status: d['status'] as String,
            ),
          );
      final List<dynamic> printerIds =
          (d['printerIds'] as List<dynamic>?) ?? <dynamic>[];
      for (final dynamic pid in printerIds) {
        await _db.into(_db.policyPrinters).insertOnConflictUpdate(
              PolicyPrintersCompanion.insert(
                id: '${d['id']}_${pid as String}',
                policyId: d['id'] as String,
                printerId: pid,
              ),
            );
      }
    }

    final List<dynamic> reports =
        (data['reports'] as List<dynamic>?) ?? <dynamic>[];
    for (final dynamic rpt in reports) {
      final Map<String, dynamic> d = rpt as Map<String, dynamic>;
      // Only upsert if printerId exists locally (avoid FK violations)
      final bool printerExists = await (_db.select(_db.printers)
            ..where((Printers p) => p.id.equals(d['printerId'] as String? ?? '')))
          .getSingleOrNull() !=
          null;
      if (!printerExists) continue;
      // Decode checkbox JSON string → Map<String, bool> for TypeConverter
      final String checkboxJson = d['technicalCheckboxes'] as String? ?? '{}';
      final Map<String, bool> checkboxMap = <String, bool>{};
      try {
        final Map<String, dynamic> raw =
            jsonDecode(checkboxJson) as Map<String, dynamic>;
        raw.forEach((String k, dynamic v) {
          checkboxMap[k] = v == true;
        });
      } catch (_) {}

      await _db.into(_db.reports).insertOnConflictUpdate(ReportsCompanion.insert(
        id: d['id'] as String,
        code: Value<String?>(d['code'] as String?),
        printerId: d['printerId'] as String,
        techId: d['techId'] as String? ?? '',
        serviceType: d['serviceType'] as String? ?? '',
        status: d['status'] as String? ?? 'Synced',
        serviceDate: d['serviceDate'] != null
            ? DateTime.parse(d['serviceDate'] as String)
            : DateTime.now(),
        linearInchesCounter: (d['linearInchesCounter'] as int?) ?? 0,
        darknessLevel: Value<int?>(d['darknessLevel'] as int?),
        technicalCheckboxes: checkboxMap,
        notes: Value<String?>(d['notes'] as String?),
        signatureName: Value<String?>(d['signatureName'] as String?),
        signatureRole: Value<String?>(d['signatureRole'] as String?),
        photoCount: Value<int>(d['photoCount'] as int? ?? 0),
      ));
    }

    // Technicians: seed all active technicians so assignment FK resolves on every tablet
    final List<dynamic> technicians =
        (data['technicians'] as List<dynamic>?) ?? <dynamic>[];
    // ignore: avoid_print
    debugPrint('[Sync] técnicos descargados: ${technicians.length}');
    for (final dynamic t in technicians) {
      final Map<String, dynamic> d = t as Map<String, dynamic>;
      await _db.into(_db.users).insertOnConflictUpdate(
            UsersCompanion.insert(
              id: d['id'] as String,
              code: Value<String?>(d['code'] as String?),
              name: d['name'] as String,
              email: d['email'] as String,
              role: d['role'] as String,
              isActive: Value<bool>(true),
            ),
          );
    }

    final List<dynamic> assignments =
        (data['policyPrinterAssignments'] as List<dynamic>?) ?? <dynamic>[];
    // ignore: avoid_print
    print('[Sync] assignments recibidos: ${assignments.length}');
    if (assignments.isNotEmpty) {
      // ignore: avoid_print
      print('[Sync] primer assignment: ${assignments.first}');
    }
    int assignmentsSaved = 0;
    for (final dynamic a in assignments) {
      final Map<String, dynamic> d = a as Map<String, dynamic>;
      final String assignmentId = d['id'] as String;
      final String printerId = d['printerId'] as String;
      final String technicianId = d['technicianId'] as String;

      // Guard FK: printer must exist locally
      final Printer? printerExists = await (_db.select(_db.printers)
            ..where((Printers p) => p.id.equals(printerId)))
          .getSingleOrNull();
      if (printerExists == null) {
        // ignore: avoid_print
        debugPrint('[Sync] SKIP assignment $assignmentId: printer $printerId no existe local');
        continue;
      }

      // Guard FK: technician (user) must exist locally
      final User? techExists = await (_db.select(_db.users)
            ..where((Users u) => u.id.equals(technicianId)))
          .getSingleOrNull();
      if (techExists == null) {
        // ignore: avoid_print
        debugPrint('[Sync] SKIP assignment $assignmentId: technician $technicianId no existe local');
        continue;
      }

      // ignore: avoid_print
      debugPrint('[Sync] persistiendo assignment $assignmentId policyId=${d['policyId']}');
      try {
        await _db.into(_db.policyPrinterAssignments).insertOnConflictUpdate(
              PolicyPrinterAssignmentsCompanion.insert(
                id: assignmentId,
                policyId: d['policyId'] as String,
                printerId: printerId,
                technicianId: technicianId,
                assignedAt: DateTime.parse(d['assignedAt'] as String),
              ),
            );
        assignmentsSaved++;
      } catch (e) {
        // ignore: avoid_print
        debugPrint('[Sync] ERROR assignment $assignmentId: $e');
      }
    }
    // ignore: avoid_print
    print('[Sync] assignments guardados: $assignmentsSaved / ${assignments.length}');

    // Policy visits
    final List<dynamic> visits =
        (data['policyVisits'] as List<dynamic>?) ?? <dynamic>[];
    // ignore: avoid_print
    debugPrint('[Sync] visitas recibidas: ${visits.length}');

    // Agrupar por policyId
    final Map<String, List<dynamic>> visitsByPolicy = {};
    for (final v in visits) {
      final pid = (v as Map<String, dynamic>)['policyId'] as String;
      visitsByPolicy.putIfAbsent(pid, () => []).add(v);
    }

    // Por cada póliza presente en el payload, reemplazar todas sus visitas locales
    for (final entry in visitsByPolicy.entries) {
      final policyId = entry.key;
      final policyVisits = entry.value;

      // Guard FK: policy must exist locally
      final bool policyExists = await (_db.select(_db.policies)
                ..where((Policies p) => p.id.equals(policyId)))
              .getSingleOrNull() !=
          null;
      if (!policyExists) {
        // ignore: avoid_print
        debugPrint('[Sync] SKIP policyId=$policyId: no existe local, omitiendo ${policyVisits.length} visitas');
        continue;
      }

      // Eliminar visitas locales de esta póliza
      await (_db.delete(_db.policyVisits)
            ..where((v) => v.policyId.equals(policyId)))
          .go();
      // ignore: avoid_print
      debugPrint('[Sync] eliminadas visitas locales de policyId=$policyId');

      // Insertar las nuevas
      for (final v in policyVisits) {
        final Map<String, dynamic> d = v as Map<String, dynamic>;
        // ignore: avoid_print
        debugPrint('[Sync] visita recibida: id=${d['id']} status=${d['status']}');
        try {
          await _db.into(_db.policyVisits).insert(
                PolicyVisitsCompanion.insert(
                  id: d['id'] as String,
                  policyId: d['policyId'] as String,
                  visitNumber: d['visitNumber'] as int,
                  scheduledDate: Value<String?>(d['scheduledDate'] as String?),
                  status: Value<String>(d['status'] as String? ?? 'scheduled'),
                  startedAt: Value<DateTime?>(
                    d['startedAt'] != null
                        ? DateTime.parse(d['startedAt'] as String)
                        : null,
                  ),
                  completedAt: Value<DateTime?>(
                    d['completedAt'] != null
                        ? DateTime.parse(d['completedAt'] as String)
                        : null,
                  ),
                  createdAt: Value<DateTime>(
                    d['createdAt'] != null
                        ? DateTime.parse(d['createdAt'] as String)
                        : DateTime.now(),
                  ),
                ),
              );
          // ignore: avoid_print
          debugPrint('[Sync] visita guardada: ${d['id']}');
        } catch (e) {
          // ignore: avoid_print
          debugPrint('[Sync] ERROR visita ${d['id']}: $e');
        }
      }
    }
    // ignore: avoid_print
    debugPrint('[Sync] policyVisits guardadas: ${visits.length} / ${visits.length}');

    // NOTE: sync_service.dart NO contiene lógica de auto-completado de visitas.
    // El auto-complete está en _loadData() de PolicyDetailScreen (solo se ejecuta
    // en initState — NO hay stream listener). Si una visita in_progress se
    // auto-completa tras el sync, el bug está en que pendingCount==0 cuando el
    // técnico aún no ha creado reportes para esa visita.
    // ignore: avoid_print
    debugPrint('[Sync] download completo — orden: catalogModels → clients → plants → areas → printers → policies → reports → technicians → assignments → visits');
  }

  // ---------------------------------------------------------------------------
  // Upsert dependencies — POST /api/sync/entities  (resolves FK on server)
  // ---------------------------------------------------------------------------

  Future<void> _upsertDependencies(
    SyncQueueData item,
    String baseUrl,
    String? authToken,
  ) async {
    final Map<String, dynamic> payload =
        jsonDecode(item.payloadJson) as Map<String, dynamic>;
    final String? printerId = payload['printerId'] as String?;
    final String? techId = payload['techId'] as String?;

    final List<Map<String, dynamic>> entities = <Map<String, dynamic>>[];

    // Catalog model (via printer)
    if (printerId != null) {
      final Printer? printer =
          await (_db.select(_db.printers)
                ..where((Printers p) => p.id.equals(printerId)))
              .getSingleOrNull();
      if (printer != null) {
        final CatalogModel? model =
            await (_db.select(_db.catalogModels)
                  ..where((CatalogModels m) => m.id.equals(printer.modelId)))
                .getSingleOrNull();
        if (model != null) {
          entities.add(<String, dynamic>{
            'type': 'catalog_model',
            'data': <String, dynamic>{
              'id': model.id,
              'brand': model.brand,
              'modelName': model.modelName,
              'dpi': model.dpi,
              'isActive': model.isActive,
            },
          });
        }

        // Client
        final Client? client =
            await (_db.select(_db.clients)
                  ..where((Clients c) => c.id.equals(printer.clientId)))
                .getSingleOrNull();
        if (client != null) {
          entities.add(<String, dynamic>{
            'type': 'client',
            'data': <String, dynamic>{
              'id': client.id,
              'name': client.name,
              'rfc': client.rfc,
              'address': client.address,
              'isActive': client.isActive,
            },
          });
        }

        // Plant
        final Plant? plant =
            await (_db.select(_db.plants)
                  ..where((Plants p) => p.id.equals(printer.plantId)))
                .getSingleOrNull();
        if (plant != null) {
          entities.add(<String, dynamic>{
            'type': 'plant',
            'data': <String, dynamic>{
              'id': plant.id,
              'clientId': plant.clientId,
              'name': plant.name,
              'contactName': plant.contactName,
              'phone': plant.phone,
            },
          });
        }

        // Area
        final Area? area =
            await (_db.select(_db.areas)
                  ..where((Areas a) => a.id.equals(printer.areaId)))
                .getSingleOrNull();
        if (area != null) {
          entities.add(<String, dynamic>{
            'type': 'area',
            'data': <String, dynamic>{
              'id': area.id,
              'plantId': area.plantId,
              'name': area.name,
            },
          });
        }

        // Printer itself
        entities.add(<String, dynamic>{
          'type': 'printer',
          'data': <String, dynamic>{
            'id': printer.id,
            'code': printer.code,
            'qrUuid': printer.qrUuid,
            'serialNumber': printer.serialNumber,
            'clientId': printer.clientId,
            'plantId': printer.plantId,
            'areaId': printer.areaId,
            'modelId': printer.modelId,
            'isActive': printer.isActive,
          },
        });
      }
    }

    // Technician (user)
    if (techId != null) {
      final User? tech =
          await (_db.select(_db.users)
                ..where((Users u) => u.id.equals(techId)))
              .getSingleOrNull();
      if (tech != null) {
        entities.insert(0, <String, dynamic>{
          'type': 'user',
          'data': <String, dynamic>{
            'id': tech.id,
            'code': tech.code,
            'name': tech.name,
            'email': tech.email,
            'role': tech.role,
            'isActive': tech.isActive,
          },
        });
      }
    }

    if (entities.isEmpty) return;

    final String url = '$baseUrl/api/sync/entities';
    // ignore: avoid_print
    print('[SyncService] POST $url (${entities.length} entities)');

    final http.Response response = await http.post(
      Uri.parse(url),
      headers: <String, String>{
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(<String, dynamic>{'entities': entities}),
    );

    // ignore: avoid_print
    print('[SyncService] entities response ${response.statusCode}: ${response.body}');
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          'entities HTTP ${response.statusCode}: ${response.body}');
    }
  }

  // ---------------------------------------------------------------------------
  // Report upload — POST /api/reports  (JSON body, camelCase accepted by backend)
  // ---------------------------------------------------------------------------

  Future<void> _syncReport(
    SyncQueueData item,
    String baseUrl,
    String? authToken,
  ) async {
    final String url = '$baseUrl/api/reports';
    // ignore: avoid_print
    print('[SyncService] POST $url (entity: ${item.entityId})');
    final Object payload = jsonDecode(item.payloadJson);
    try {
      final http.Response response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(payload),
      );

      // ignore: avoid_print
      print('[SyncService] Response ${response.statusCode}: ${response.body}');
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // ignore: avoid_print
      print('[SyncService] Error: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // File upload — POST /api/files  (multipart/form-data)
  //
  // payloadJson must contain:
  //   { "localPath": "/path/to/file.jpg", "fileCategory": "photo" | "signature" }
  // ---------------------------------------------------------------------------

  Future<void> _syncFile(
    SyncQueueData item,
    String baseUrl,
    String? authToken,
  ) async {
    final Map<String, dynamic> meta =
        jsonDecode(item.payloadJson) as Map<String, dynamic>;
    final String? localPath = meta['localPath'] as String?;
    final String fileCategory =
        meta['fileCategory'] as String? ?? item.entityType;

    // ignore: avoid_print
    print(
      '[SyncService] _syncFile: entityType=${item.entityType}, '
      'entityId=${item.entityId}, fileCategory=$fileCategory, '
      'localPath=$localPath',
    );

    if (localPath == null || localPath.isEmpty) {
      throw Exception(
        'localPath ausente en payloadJson para ${item.entityType}/${item.entityId}',
      );
    }

    final io.File file = io.File(localPath);
    final bool exists = file.existsSync();
    // ignore: avoid_print
    print('[SyncService] _syncFile: exists=$exists, path=$localPath');

    if (!exists) {
      throw Exception(
        'Archivo local no encontrado: $localPath '
        '(entityType=${item.entityType}, entityId=${item.entityId})',
      );
    }

    final String url = '$baseUrl/api/files';
    // ignore: avoid_print
    print('[SyncService] POST $url (file: $localPath, category: $fileCategory)');
    try {
      final http.MultipartRequest request =
          http.MultipartRequest('POST', Uri.parse(url))
            ..fields['entity_type'] = 'report'
            ..fields['entity_id'] = item.entityId
            ..fields['file_category'] = fileCategory
            ..files.add(await http.MultipartFile.fromPath('file', localPath));

      if (authToken != null) {
        request.headers['Authorization'] = 'Bearer $authToken';
      }

      final http.StreamedResponse response = await request.send();
      final String body = await response.stream.bytesToString();
      // ignore: avoid_print
      print('[SyncService] Response ${response.statusCode}: $body');
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('HTTP ${response.statusCode}: $body');
      }
    } catch (e) {
      // ignore: avoid_print
      print('[SyncService] Error: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Policy delivery upload — POST /api/policy-deliveries
  // ---------------------------------------------------------------------------

  Future<void> _syncPolicyDelivery(
    SyncQueueData item,
    String baseUrl,
    String? authToken,
  ) async {
    final String url = '$baseUrl/api/policy-deliveries';
    // ignore: avoid_print
    print('[SyncService] POST $url (entity: ${item.entityId})');
    final Object payload = jsonDecode(item.payloadJson);
    final http.Response response = await http.post(
      Uri.parse(url),
      headers: <String, String>{
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  // ---------------------------------------------------------------------------
  // Report update — PATCH /api/reports/{entityId}
  // ---------------------------------------------------------------------------

  Future<void> _syncReportUpdate(
    SyncQueueData item,
    String baseUrl,
    String? authToken,
  ) async {
    final String url = '$baseUrl/api/reports/${item.entityId}';
    // ignore: avoid_print
    print('[SyncService] PATCH $url (entity: ${item.entityId})');
    final Object payload = jsonDecode(item.payloadJson);

    final http.Response response = await http.patch(
      Uri.parse(url),
      headers: <String, String>{
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(payload),
    );

    // ignore: avoid_print
    print('[SyncService] PATCH response ${response.statusCode}: ${response.body}');
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    // Apply server response to local Drift DB
    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;

    final String checkboxJson =
        data['technical_checkboxes'] as String? ?? '{}';
    final Map<String, bool> checkboxMap = <String, bool>{};
    try {
      final Map<String, dynamic> raw =
          jsonDecode(checkboxJson) as Map<String, dynamic>;
      raw.forEach((String k, dynamic v) {
        checkboxMap[k] = v == true;
      });
    } catch (_) {}

    await (_db.update(_db.reports)
          ..where((Reports r) => r.id.equals(item.entityId)))
        .write(ReportsCompanion(
      serviceType: data['service_type'] != null
          ? Value<String>(data['service_type'] as String)
          : const Value<String>.absent(),
      notes: Value<String?>(data['notes'] as String?),
      linearInchesCounter: data['linear_inches_counter'] != null
          ? Value<int>(data['linear_inches_counter'] as int)
          : const Value<int>.absent(),
      darknessLevel: Value<int?>(data['darkness_level'] as int?),
    ));
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _entityLabel(String entityType) => switch (entityType) {
        'report' => 'Reporte',
        'file' => 'Archivo',
        'signature' => 'Firma',
        'pdf' => 'PDF',
        'policy_delivery' => 'Entrega póliza',
        'report_update' => 'Actualizar reporte',
        _ => entityType,
      };
}
