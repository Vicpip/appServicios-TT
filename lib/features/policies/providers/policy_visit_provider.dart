import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/data/local/local_database.dart';

/// Retorna la visita con status='in_progress' más reciente para la póliza dada, o null.
final activeVisitProvider =
    FutureProvider.family<PolicyVisit?, String>((ref, policyId) async {
  final db = localDatabase;
  final results = await (db.select(db.policyVisits)
        ..where((v) =>
            v.policyId.equals(policyId) & v.status.equals('in_progress'))
        ..orderBy([(v) => OrderingTerm.desc(v.startedAt)])
        ..limit(1))
      .get();
  return results.firstOrNull;
});

/// Retorna todas las visitas de la póliza ordenadas por visit_number.
final policyVisitsProvider =
    FutureProvider.family<List<PolicyVisit>, String>((ref, policyId) async {
  final db = localDatabase;
  final result = await (db.select(db.policyVisits)
        ..where((v) => v.policyId.equals(policyId))
        ..orderBy([(v) => OrderingTerm.asc(v.visitNumber)]))
      .get();
  return result;
});
