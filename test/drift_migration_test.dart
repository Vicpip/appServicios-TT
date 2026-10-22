// ignore_for_file: prefer_single_quotes
// Migración de Drift v10 -> v11 (la v11 aún no se libera, incluye las columnas
// de darkness real, syncedAt, extraEmail de la entrega y cierre de visita).
//
// Cómo correrla:
//   flutter test test/drift_migration_test.dart
//
// Infraestructura: test/drift_schemas/drift_schema_v10.json (volcado del HEAD
// previo a v11) y drift_schema_v11.json; test/generated_migrations/ se genera con
//   dart run drift_dev schema dump lib/data/local/app_database.dart test/drift_schemas/
//   dart run drift_dev schema generate test/drift_schemas/ test/generated_migrations/
// Si cambias el esquema de nuevo, vuelve a volcar y regenerar.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';

import 'generated_migrations/schema.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('el esquema resultante de migrar v10 -> v11 coincide con el v11', () async {
    final InitializedSchema schema = await verifier.schemaAt(10);
    final AppDatabase db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 11);
    await db.close();
  });

  test('v10 -> v11 conserva reportes, firmas, entregas y cola pendiente', () async {
    final InitializedSchema schema = await verifier.schemaAt(10);
    final raw = schema.rawDatabase;

    // --- Datos v10 (coherentes con las llaves foráneas) ---
    raw.execute("INSERT INTO users (id, name, email, role, is_active) "
        "VALUES ('u1', 'Tec Uno', 'tec1@smp.test', 'technician', 1), "
        "('u2', 'Tec Dos', 'tec2@smp.test', 'technician', 1)");
    raw.execute("INSERT INTO clients (id, name, is_active) VALUES ('c1', 'Cliente', 1)");
    raw.execute("INSERT INTO plants (id, client_id, name) VALUES ('pl1', 'c1', 'Planta')");
    raw.execute("INSERT INTO areas (id, plant_id, name) VALUES ('a1', 'pl1', 'Área')");
    raw.execute("INSERT INTO catalog_models (id, brand, model_name, dpi, is_active) "
        "VALUES ('m1', 'Zebra', 'ZT411', 300, 1)");
    raw.execute("INSERT INTO printers (id, qr_uuid, serial_number, client_id, plant_id, area_id, model_id, is_active) "
        "VALUES ('pr1', 'qr1', 'SN-1', 'c1', 'pl1', 'a1', 'm1', 1)");
    // darkness ENTERO (v10) y firma individual guardada
    raw.execute("INSERT INTO reports (id, printer_id, tech_id, service_type, status, service_date, "
        "linear_inches_counter, darkness_level, technical_checkboxes, signature_name, signature_role, "
        "signature_image_path, pending_email, code) VALUES "
        "('r1', 'pr1', 'u1', 'Preventivo', 'Signed', 1760000000, 1000, 18, '{\"Pruebas\":true}', "
        "'Cliente Uno', 'Compras', '/data/sig1.png', 'extra@cliente.com', 'R-001'), "
        "('r2', 'pr1', 'u2', 'Correctivo', 'pending_delivery', 1760000100, 50, NULL, '{}', "
        "NULL, NULL, NULL, NULL, 'R-002')");
    raw.execute("INSERT INTO policies (id, client_id, folio, start_date, end_date, coverage_type, status) "
        "VALUES ('pol1', 'c1', 'POL-1', 1750000000, 1790000000, 'Integral', 'Active')");
    raw.execute("INSERT INTO policy_visits (id, policy_id, visit_number, status) "
        "VALUES ('v1', 'pol1', 1, 'in_progress')");
    raw.execute("INSERT INTO policy_deliveries (id, policy_id, delivery_date, signature_name, "
        "signature_role, tech_id, signature_image_path) VALUES "
        "('d1', 'pol1', 1760000200, 'Cliente Dos', 'Gerente', 'u1', '/data/sigd.png')");
    // Cola pendiente: reporte, firma y entrega de DOS técnicos distintos.
    raw.execute("INSERT INTO sync_queue (id, method_http, endpoint_destino, payload_json, entity_type, "
        "entity_id, fecha_creacion, estado_peticion, intentos_fallidos) VALUES "
        "('q1', 'POST', '/api/reports', '{}', 'report', 'r1', 1760000300, 'pending', 0), "
        "('q2', 'POST', '/api/files', '{\"localPath\":\"/data/sig1.png\"}', 'signature', 'r1', 1760000301, 'pending', 2), "
        "('q3', 'POST', '/api/policy-deliveries', '{}', 'policy_delivery', 'd1', 1760000302, 'failed', 5), "
        "('q4', 'POST', '/api/reports', '{}', 'report', 'r2', 1760000303, 'pending', 0)");

    // --- Migrar ---
    final AppDatabase db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 11);

    // Reportes y firmas intactos
    final List<Report> reports =
        await (db.select(db.reports)..orderBy([(Reports r) => OrderingTerm.asc(r.id)])).get();
    expect(reports.map((Report r) => r.id), <String>['r1', 'r2']);
    final Report r1 = reports.first;
    expect(r1.status, 'Signed');
    expect(r1.signatureName, 'Cliente Uno');
    expect(r1.signatureImagePath, '/data/sig1.png');
    expect(r1.pendingEmail, 'extra@cliente.com');
    expect(r1.technicalCheckboxes, <String, bool>{'Pruebas': true});
    expect(r1.code, 'R-001');
    // darkness: el entero previo se conserva como double (18 -> 18.0); NULL sigue NULL
    expect(r1.darknessLevel, 18.0);
    expect(reports.last.darknessLevel, isNull);
    // syncedAt nuevo: queda nulo
    expect(reports.every((Report r) => r.syncedAt == null), isTrue);

    // Cola: mismas filas, mismo estado e intentos (incluido el 'failed')
    final List<SyncQueueData> queue =
        await (db.select(db.syncQueue)..orderBy([(SyncQueue q) => OrderingTerm.asc(q.id)])).get();
    expect(queue.map((SyncQueueData q) => q.id), <String>['q1', 'q2', 'q3', 'q4']);
    expect(queue.map((SyncQueueData q) => q.estadoPeticion),
        <String>['pending', 'pending', 'failed', 'pending']);
    expect(queue.map((SyncQueueData q) => q.intentosFallidos), <int>[0, 2, 5, 0]);
    expect(queue[1].payloadJson, contains('/data/sig1.png'));

    // Entrega: firma conservada y correo adicional nuevo, nulo
    final PolicyDelivery d1 = await db.select(db.policyDeliveries).getSingle();
    expect(d1.signatureImagePath, '/data/sigd.png');
    expect(d1.signatureName, 'Cliente Dos');
    expect(d1.extraEmail, isNull);

    // Visita: sigue en curso y sin datos de cierre
    final PolicyVisit v1 = await db.select(db.policyVisits).getSingle();
    expect(v1.status, 'in_progress');
    expect(v1.closedAt, isNull);
    expect(v1.closedReason, isNull);
    expect(v1.closedByName, isNull);

    // La BD migrada ya acepta los campos nuevos
    await db.into(db.policyDeliveries).insert(PolicyDeliveriesCompanion.insert(
          id: 'd2',
          policyId: 'pol1',
          deliveryDate: DateTime(2026, 10, 22),
          signatureName: 'X',
          signatureRole: 'Y',
          techId: 'u1',
          extraEmail: const Value<String?>('otro@cliente.com'),
        ));
    await (db.update(db.reports)..where((Reports r) => r.id.equals('r1')))
        .write(const ReportsCompanion(darknessLevel: Value<double?>(18.5)));
    expect((await (db.select(db.reports)..where((Reports r) => r.id.equals('r1'))).getSingle())
            .darknessLevel,
        18.5);
    await db.close();
  });
}
