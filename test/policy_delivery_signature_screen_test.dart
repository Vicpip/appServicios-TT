// ignore_for_file: depend_on_referenced_packages
// Pantalla "Firma de entrega" (policy_delivery_signature_screen.dart):
// tarjeta "Envío por correo", validación del correo adicional y valor que se
// guarda/encola con la entrega.
//
//   flutter test test/policy_delivery_signature_screen_test.dart
import 'dart:convert';
import 'dart:io' as io;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:industrial_service_reports/core/router/app_routes.dart';
import 'package:industrial_service_reports/core/router/route_args.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/data/local/local_database.dart';
import 'package:industrial_service_reports/features/policies/presentation/policy_delivery_signature_screen.dart';
import 'package:industrial_service_reports/features/signature/widgets/email_delivery_section.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:signature/signature.dart';

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.dir);
  final String dir;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
}

Future<void> _seed(AppDatabase db) async {
  await db.into(db.users).insert(UsersCompanion.insert(
      id: 'u1', name: 'Tec', email: 'u1@smp.test', role: 'technician'));
  await db.into(db.clients).insert(ClientsCompanion.insert(id: 'c1', name: 'Cliente'));
  await db.into(db.plants).insert(PlantsCompanion.insert(id: 'pl1', clientId: 'c1', name: 'P'));
  await db.into(db.areas).insert(AreasCompanion.insert(id: 'a1', plantId: 'pl1', name: 'A'));
  await db.into(db.catalogModels).insert(
      CatalogModelsCompanion.insert(id: 'm1', brand: 'Zebra', modelName: 'ZT411', dpi: 300));
  await db.into(db.printers).insert(PrintersCompanion.insert(
      id: 'pr1', qrUuid: 'q', serialNumber: 'SN-1', clientId: 'c1',
      plantId: 'pl1', areaId: 'a1', modelId: 'm1'));
  await db.into(db.policies).insert(PoliciesCompanion.insert(
      id: 'pol1', clientId: 'c1', folio: 'POL-1', startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2027, 1, 1), coverageType: 'Integral', status: 'Active'));
  await db.into(db.reports).insert(ReportsCompanion.insert(
      id: 'r1', printerId: 'pr1', techId: 'u1', serviceType: 'Preventivo',
      status: 'pending_delivery', serviceDate: DateTime(2026, 10, 22),
      linearInchesCounter: 10, technicalCheckboxes: <String, bool>{}));
}

Future<void> _pumpScreen(WidgetTester tester) async {
  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, __) => const PolicyDeliverySignatureScreen(
          args: PolicyDeliverySignatureArgs(
            policyId: 'pol1',
            policyFolio: 'POL-1',
            reportIds: <String>['r1'],
            techId: 'u1',
          ),
        ),
      ),
      GoRoute(
        path: '/ok',
        name: AppRoutes.policyDeliverySuccess,
        builder: (_, __) => const Scaffold(body: Text('ÉXITO')),
      ),
    ],
  );
  await tester.binding.setSurfaceSize(const Size(900, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)));
  await tester.pump();
  await tester.pump();
}

Future<void> _fillAndSign(WidgetTester tester, {String? extraEmail}) async {
  final Finder fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'Cliente Firma');
  await tester.enterText(fields.at(1), 'Compras');
  if (extraEmail != null) {
    await tester.enterText(find.widgetWithText(TextFormField, 'Correo adicional'), extraEmail);
  }
  final Offset c = tester.getCenter(find.byType(Signature));
  final TestGesture g = await tester.startGesture(c - const Offset(60, 30));
  await g.moveBy(const Offset(40, 20));
  await g.moveBy(const Offset(40, -20));
  await g.up();
  await tester.pump();
}

void main() {
  late AppDatabase db;
  late io.Directory tmp;

  setUp(() async {
    tmp = io.Directory.systemTemp.createTempSync('delivery_sig_test_');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    db = AppDatabase(NativeDatabase.memory());
    localDatabase = db;
    await _seed(db);
    // Sin red: los correos del cliente se "consultan" con un doble.
    contactEmailsFetcher = (String _) async => <String>['uno@cliente.com', 'dos@cliente.com'];
  });

  tearDown(() async {
    contactEmailsFetcher = fetchClientContactEmails;
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  testWidgets('muestra la tarjeta "Envío por correo" con los correos registrados', (tester) async {
    await _pumpScreen(tester);
    expect(find.text('Envío por correo'), findsOneWidget);
    expect(find.text('Se enviará a: uno@cliente.com, dos@cliente.com'), findsOneWidget);
    expect(find.text('Agregar otro'), findsOneWidget);
  });

  testWidgets('sin conexión la tarjeta no aparece (no hay campo de correo)', (tester) async {
    contactEmailsFetcher = (String _) async => null; // sin conexión
    await _pumpScreen(tester);
    expect(find.text('Envío por correo'), findsNothing);
    expect(find.text('Correo adicional'), findsNothing);
  });

  testWidgets('sin correos registrados: "Sin correos registrados" + campo', (tester) async {
    contactEmailsFetcher = (String _) async => <String>[];
    await _pumpScreen(tester);
    expect(find.text('Sin correos registrados'), findsOneWidget);
    expect(find.text('Correo adicional'), findsOneWidget);
  });

  testWidgets('correo inválido: "Correo inválido" y NO se guarda la entrega', (tester) async {
    await _pumpScreen(tester);
    await tester.tap(find.text('Agregar otro'));
    await tester.pump();
    await _fillAndSign(tester, extraEmail: 'esto-no-es-correo');

    await tester.tap(find.text('Confirmar Entrega'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Correo inválido'), findsWidgets);
    expect(find.text('ÉXITO'), findsNothing);
    expect(await db.select(db.policyDeliveries).get(), isEmpty);
    expect(await db.select(db.syncQueue).get(), isEmpty);
  });

  testWidgets('correo válido: se guarda en la entrega y se sube en la cola', (tester) async {
    await _pumpScreen(tester);
    await tester.tap(find.text('Agregar otro'));
    await tester.pump();
    await _fillAndSign(tester, extraEmail: ' firma@cliente.com ');

    await tester.runAsync(() async {
      await tester.tap(find.text('Confirmar Entrega'));
      // _onConfirm hace E/S real (PNG de la firma, BD): se espera a que termine.
      for (int i = 0; i < 100; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if ((await db.select(db.policyDeliveries).get()).isNotEmpty &&
            (await db.select(db.syncQueue).get()).length >= 2) {
          break;
        }
      }
    });
    await tester.pumpAndSettle();

    final PolicyDelivery d = await db.select(db.policyDeliveries).getSingle();
    expect(d.extraEmail, 'firma@cliente.com');
    final SyncQueueData q = await (db.select(db.syncQueue)
          ..where((SyncQueue s) => s.entityType.equals('policy_delivery')))
        .getSingle();
    final Map<String, dynamic> payload =
        jsonDecode(q.payloadJson) as Map<String, dynamic>;
    expect(payload['extra_email'], 'firma@cliente.com');
    expect(payload['report_ids'], <String>['r1']);
  });

  testWidgets('sin correo adicional: el comportamiento no cambia (extra_email nulo)', (tester) async {
    await _pumpScreen(tester);
    await _fillAndSign(tester);

    await tester.runAsync(() async {
      await tester.tap(find.text('Confirmar Entrega'));
      for (int i = 0; i < 100; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if ((await db.select(db.syncQueue).get()).length >= 2) break;
      }
    });
    await tester.pumpAndSettle();

    final PolicyDelivery d = await db.select(db.policyDeliveries).getSingle();
    expect(d.extraEmail, isNull);
    final SyncQueueData q = await (db.select(db.syncQueue)
          ..where((SyncQueue s) => s.entityType.equals('policy_delivery')))
        .getSingle();
    expect((jsonDecode(q.payloadJson) as Map<String, dynamic>)['extra_email'], isNull);
  });
}
