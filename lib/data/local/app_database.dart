import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class CheckboxMapConverter extends TypeConverter<Map<String, bool>, String> {
  const CheckboxMapConverter();

  @override
  Map<String, bool> fromSql(String fromDb) {
    if (fromDb.trim().isEmpty) {
      return <String, bool>{};
    }

    final dynamic decoded = jsonDecode(fromDb);
    if (decoded is! Map<String, dynamic>) {
      return <String, bool>{};
    }

    return decoded.map(
      (String key, dynamic value) => MapEntry<String, bool>(
        key,
        value == true || value == 1 || value == 'true',
      ),
    );
  }

  @override
  String toSql(Map<String, bool> value) => jsonEncode(value);
}

class Users extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get email => text().unique()();

  TextColumn get role => text()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class Clients extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get rfc => text().nullable()();

  TextColumn get address => text().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class Plants extends Table {
  TextColumn get id => text()();

  TextColumn get clientId => text().references(Clients, #id)();

  TextColumn get name => text()();

  TextColumn get contactName => text().nullable()();

  TextColumn get phone => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Areas extends Table {
  TextColumn get id => text()();

  TextColumn get plantId => text().references(Plants, #id)();

  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class CatalogModels extends Table {
  TextColumn get id => text()();

  TextColumn get brand => text()();

  TextColumn get modelName => text()();

  IntColumn get dpi => integer()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class Printers extends Table {
  TextColumn get id => text()();

  TextColumn get qrUuid => text()();

  TextColumn get serialNumber => text().unique()();

  TextColumn get clientId => text().references(Clients, #id)();

  TextColumn get plantId => text().references(Plants, #id)();

  TextColumn get areaId => text().references(Areas, #id)();

  TextColumn get modelId => text().references(CatalogModels, #id)();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class CatalogActions extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class CatalogParts extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class CatalogFailures extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class CatalogLabelTypes extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class Reports extends Table {
  TextColumn get id => text()();

  TextColumn get printerId => text().references(Printers, #id)();

  TextColumn get techId => text().references(Users, #id)();

  TextColumn get serviceType => text()();

  TextColumn get status => text()();

  DateTimeColumn get serviceDate => dateTime()();

  IntColumn get linearInchesCounter => integer()();

  IntColumn get darknessLevel => integer().nullable()();

  TextColumn get labelTypeId =>
      text().nullable().references(CatalogLabelTypes, #id)();

  TextColumn get technicalCheckboxes =>
      text().map(const CheckboxMapConverter())();

  TextColumn get notes => text().nullable()();

  TextColumn get signatureName => text().nullable()();

  TextColumn get signatureRole => text().nullable()();

  TextColumn get internalNotes => text().nullable()();

  TextColumn get supersedesReportId => text().nullable().references(Reports, #id)();

  DateTimeColumn get syncDate => dateTime().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class ReportActions extends Table {
  TextColumn get id => text()();

  TextColumn get reportId => text().references(Reports, #id)();

  TextColumn get actionId => text().references(CatalogActions, #id)();

  @override
  Set<Column> get primaryKey => {id};
}

class ReportParts extends Table {
  TextColumn get id => text()();

  TextColumn get reportId => text().references(Reports, #id)();

  TextColumn get partId => text().references(CatalogParts, #id)();

  BoolColumn get wasDamaged => boolean().withDefault(const Constant(false))();

  IntColumn get wearLevel => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Policies extends Table {
  TextColumn get id => text()();

  TextColumn get clientId => text().references(Clients, #id)();

  TextColumn get folio => text().unique()();

  DateTimeColumn get startDate => dateTime()();

  DateTimeColumn get endDate => dateTime()();

  TextColumn get coverageType => text()();

  TextColumn get slaNotes => text().nullable()();

  TextColumn get status => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class PolicyPrinters extends Table {
  TextColumn get id => text()();

  TextColumn get policyId => text().references(Policies, #id)();

  TextColumn get printerId => text().references(Printers, #id)();

  @override
  Set<Column> get primaryKey => {id};
}

class PolicyDeliveries extends Table {
  TextColumn get id => text()();

  TextColumn get policyId => text().references(Policies, #id)();

  DateTimeColumn get deliveryDate => dateTime()();

  TextColumn get signatureName => text()();

  TextColumn get signatureRole => text()();

  TextColumn get techId => text().references(Users, #id)();

  @override
  Set<Column> get primaryKey => {id};
}

class PolicyDeliveryReports extends Table {
  TextColumn get id => text()();

  TextColumn get deliveryId => text().references(PolicyDeliveries, #id)();

  TextColumn get reportId => text().references(Reports, #id)();

  @override
  Set<Column> get primaryKey => {id};
}

class Files extends Table {
  TextColumn get id => text()();

  TextColumn get fileHash => text()();

  TextColumn get fileType => text()();

  TextColumn get storagePath => text()();

  TextColumn get origin => text()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class EntityFiles extends Table {
  TextColumn get id => text()();

  TextColumn get fileId => text().references(Files, #id)();

  TextColumn get entityId => text()();

  TextColumn get entityType => text()();

  TextColumn get fileCategory => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: <Type>[
    Users,
    Clients,
    Plants,
    Areas,
    CatalogModels,
    Printers,
    Reports,
    ReportActions,
    ReportParts,
    Policies,
    PolicyPrinters,
    PolicyDeliveries,
    PolicyDeliveryReports,
    Files,
    EntityFiles,
    CatalogActions,
    CatalogParts,
    CatalogFailures,
    CatalogLabelTypes,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator migrator) async {
          await migrator.createAll();
        },
        onUpgrade: (Migrator migrator, int from, int to) async {
          if (from < 2) {
            await migrator.addColumn(reports, reports.darknessLevel);
          }
          if (from < 3) {
            await migrator.addColumn(plants, plants.contactName);
            await migrator.addColumn(plants, plants.phone);
          }
        },
        beforeOpen: (OpeningDetails details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
          await _seedCatalogs();
        },
      );

  Future<void> _seedCatalogs() async {
    const List<(String, String)> labelTypes = <(String, String)>[
      ('a0000000-0000-0000-0000-000000000001', 'Papel TT'),
      ('a0000000-0000-0000-0000-000000000002', 'Papel TD'),
      ('a0000000-0000-0000-0000-000000000003', 'Plástica (BOPP/Poliéster)'),
    ];
    for (final (id, name) in labelTypes) {
      await into(catalogLabelTypes).insertOnConflictUpdate(
        CatalogLabelTypesCompanion.insert(id: id, name: name),
      );
    }

    const List<(String, String)> failures = <(String, String)>[
      ('b0000000-0000-0000-0000-000000000001', 'Mantenimiento general'),
      ('b0000000-0000-0000-0000-000000000002', 'Calibración sensores'),
      ('b0000000-0000-0000-0000-000000000003', 'Rodillo dañado'),
      ('b0000000-0000-0000-0000-000000000004', 'Cabezal dañado'),
      ('b0000000-0000-0000-0000-000000000005', 'Sensor ribbon dañado'),
      ('b0000000-0000-0000-0000-000000000006', 'Sensor papel dañado'),
      ('b0000000-0000-0000-0000-000000000007', 'Pruebas'),
      ('b0000000-0000-0000-0000-000000000008', 'Otros'),
    ];
    for (final (id, name) in failures) {
      await into(catalogFailures).insertOnConflictUpdate(
        CatalogFailuresCompanion.insert(id: id, name: name),
      );
    }
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'industrial_service_reports.sqlite',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}


