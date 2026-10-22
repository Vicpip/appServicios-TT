// Lógica de la cola de sincronización: cola por técnico y errores sin conectividad.
//
//   flutter test test/sync_queue_logic_test.dart
import 'dart:async';
import 'dart:io' as io;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:industrial_service_reports/core/constants.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/features/sync/services/sync_service.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late SyncService service;
  final List<String> processed = <String>[];

  Future<void> addQueue(String id, String type, String entityId,
      {int attempts = 0, int minute = 0}) {
    return db.into(db.syncQueue).insert(SyncQueueCompanion.insert(
          id: id,
          methodHttp: 'POST',
          endpointDestino: '/api/x',
          payloadJson: '{}',
          entityType: type,
          entityId: entityId,
          fechaCreacion: Value<DateTime>(DateTime(2026, 10, 22, 9, minute)),
          intentosFallidos: Value<int>(attempts),
        ));
  }

  Future<List<SyncQueueData>> pending() => (db.select(db.syncQueue)
        ..where((SyncQueue q) => q.estadoPeticion.equals('pending'))
        ..orderBy([(SyncQueue q) => OrderingTerm.asc(q.fechaCreacion)]))
      .get();

  Future<SyncQueueData> row(String id) => (db.select(db.syncQueue)
        ..where((SyncQueue q) => q.id.equals(id)))
      .getSingle();

  setUp(() async {
    processed.clear();
    db = AppDatabase(NativeDatabase.memory());
    service = SyncService(db);

    await db.into(db.users).insert(UsersCompanion.insert(
        id: 'u1', name: 'Tec Uno', email: 'u1@smp.test', role: 'technician'));
    await db.into(db.users).insert(UsersCompanion.insert(
        id: 'u2', name: 'Tec Dos', email: 'u2@smp.test', role: 'technician'));
    await db
        .into(db.clients)
        .insert(ClientsCompanion.insert(id: 'c1', name: 'Cliente'));
    await db.into(db.plants).insert(
        PlantsCompanion.insert(id: 'pl1', clientId: 'c1', name: 'Planta'));
    await db
        .into(db.areas)
        .insert(AreasCompanion.insert(id: 'a1', plantId: 'pl1', name: 'Área'));
    await db.into(db.catalogModels).insert(CatalogModelsCompanion.insert(
        id: 'm1', brand: 'Zebra', modelName: 'ZT411', dpi: 300));
    await db.into(db.printers).insert(PrintersCompanion.insert(
        id: 'pr1',
        qrUuid: 'qr1',
        serialNumber: 'SN-1',
        clientId: 'c1',
        plantId: 'pl1',
        areaId: 'a1',
        modelId: 'm1'));
    for (final (String id, String tech) in <(String, String)>[
      ('r1', 'u1'),
      ('r2', 'u2')
    ]) {
      await db.into(db.reports).insert(ReportsCompanion.insert(
            id: id,
            printerId: 'pr1',
            techId: tech,
            serviceType: 'Preventivo',
            status: 'Signed',
            serviceDate: DateTime(2026, 10, 22),
            linearInchesCounter: 100,
            technicalCheckboxes: <String, bool>{},
          ));
    }
    await db.into(db.policies).insert(PoliciesCompanion.insert(
        id: 'pol1',
        clientId: 'c1',
        folio: 'POL-1',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2027, 1, 1),
        coverageType: 'Integral',
        status: 'Active'));
    await db.into(db.policyDeliveries).insert(PolicyDeliveriesCompanion.insert(
        id: 'd2',
        policyId: 'pol1',
        deliveryDate: DateTime(2026, 10, 22),
        signatureName: 'Cliente',
        signatureRole: 'Compras',
        techId: 'u2'));
  });

  tearDown(() => db.close());

  group('cola por técnico', () {
    test('no sube elementos de otro técnico', () async {
      await addQueue('q1', 'report', 'r1', minute: 1); // u1
      await addQueue('q2', 'report', 'r2', minute: 2); // u2
      await addQueue('q3', 'pdf', 'r1', minute: 3); // u1
      await addQueue('q4', 'signature', 'd2', minute: 4); // entrega de u2
      await addQueue('q5', 'policy_delivery', 'd2', minute: 5); // entrega de u2

      final SyncResult res = await service.uploadPending(
        pending: await pending(),
        currentUserId: 'u1',
        processItem: (SyncQueueData i) async => processed.add(i.id),
      );

      expect(processed, <String>['q1', 'q3']);
      expect(res.succeeded, 2);
      expect(res.skippedOtherUser, 3);
      expect(res.failed, 0);
      // Los de u2 quedan intactos: pendientes, sin intentos ni error.
      for (final String id in <String>['q2', 'q4', 'q5']) {
        final SyncQueueData r = await row(id);
        expect(r.estadoPeticion, 'pending');
        expect(r.intentosFallidos, 0);
        expect(r.lastError, isNull);
      }
      expect((await row('q1')).estadoPeticion, 'synced');
    });

    test('con la sesión del otro técnico suben justo los suyos', () async {
      await addQueue('q1', 'report', 'r1', minute: 1);
      await addQueue('q2', 'report', 'r2', minute: 2);
      await service.uploadPending(
        pending: await pending(),
        currentUserId: 'u2',
        processItem: (SyncQueueData i) async => processed.add(i.id),
      );
      expect(processed, <String>['q2']);
    });

    test('elementos sin dueño conocido se suben (no se pierden)', () async {
      await addQueue('q1', 'file', 'entidad-desconocida', minute: 1);
      final SyncResult res = await service.uploadPending(
        pending: await pending(),
        currentUserId: 'u1',
        processItem: (SyncQueueData i) async => processed.add(i.id),
      );
      expect(res.succeeded, 1);
      expect(res.skippedOtherUser, 0);
    });
  });

  group('errores sin conectividad', () {
    final Map<String, Object> connectivityErrors = <String, Object>{
      'SocketException': const io.SocketException('sin red'),
      'TimeoutException': TimeoutException('lento'),
      'HandshakeException': const io.HandshakeException('tls'),
      'ClientException': http.ClientException('sin ruta'),
    };

    for (final MapEntry<String, Object> e in connectivityErrors.entries) {
      test('${e.key}: no cuenta intento y detiene la corrida', () async {
        await addQueue('q1', 'report', 'r1', minute: 1, attempts: 2);
        await addQueue('q2', 'pdf', 'r1', minute: 2);

        final SyncResult res = await service.uploadPending(
          pending: await pending(),
          currentUserId: 'u1',
          processItem: (SyncQueueData i) async {
            processed.add(i.id);
            throw e.value;
          },
        );

        expect(res.offline, isTrue);
        expect(res.failed, 0);
        expect(res.succeeded, 0);
        expect(processed, <String>['q1'], reason: 'se detiene al primer error de red');
        final SyncQueueData q1 = await row('q1');
        expect(q1.estadoPeticion, 'pending');
        expect(q1.intentosFallidos, 2, reason: 'no suma intento');
        expect(q1.lastError, isNull);
        expect((await row('q2')).intentosFallidos, 0);
      });
    }

    test('isConnectivityError distingue red de errores del servidor', () {
      expect(isConnectivityError(const io.SocketException('x')), isTrue);
      expect(isConnectivityError(http.ClientException('x')), isTrue);
      expect(isConnectivityError(const HttpStatusException(500, 'boom')), isFalse);
      expect(isConnectivityError(Exception('otro')), isFalse);
    });

    test('un error 500 SÍ suma intento y al llegar al máximo pasa a failed', () async {
      await addQueue('q1', 'report', 'r1', minute: 1, attempts: kMaxSyncAttempts - 2);
      for (int i = 0; i < 2; i++) {
        await service.uploadPending(
          pending: await pending(),
          currentUserId: 'u1',
          processItem: (SyncQueueData _) async =>
              throw const HttpStatusException(500, 'boom'),
        );
        if (i == 0) {
          final SyncQueueData r = await row('q1');
          expect(r.estadoPeticion, 'pending');
          expect(r.intentosFallidos, kMaxSyncAttempts - 1);
          expect(r.lastError, contains('HTTP 500'));
        }
      }
      final SyncQueueData r = await row('q1');
      expect(r.estadoPeticion, 'failed');
      expect(r.intentosFallidos, kMaxSyncAttempts);
    });

    test('401/403 lanza SessionRevokedException y no suma intento', () async {
      await addQueue('q1', 'report', 'r1', minute: 1);
      await expectLater(
        service.uploadPending(
          pending: await pending(),
          currentUserId: 'u1',
          processItem: (SyncQueueData _) async =>
              throw const HttpStatusException(401, 'revocada'),
        ),
        throwsA(isA<SessionRevokedException>()),
      );
      final SyncQueueData r = await row('q1');
      expect(r.estadoPeticion, 'pending');
      expect(r.intentosFallidos, 0);
    });

    test('mezcla: uno sube, el siguiente sin red, el tercero ni se intenta', () async {
      await addQueue('q1', 'report', 'r1', minute: 1);
      await addQueue('q2', 'pdf', 'r1', minute: 2);
      await addQueue('q3', 'signature', 'r1', minute: 3);
      final SyncResult res = await service.uploadPending(
        pending: await pending(),
        currentUserId: 'u1',
        processItem: (SyncQueueData i) async {
          processed.add(i.id);
          if (i.id == 'q2') throw const io.SocketException('sin red');
        },
      );
      expect(processed, <String>['q1', 'q2']);
      expect(res.succeeded, 1);
      expect(res.offline, isTrue);
      expect((await row('q2')).intentosFallidos, 0);
      expect((await row('q3')).estadoPeticion, 'pending');
    });
  });
}
