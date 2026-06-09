import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/data/local/local_database.dart';

@immutable
class ReportDeliveryItem {
  const ReportDeliveryItem({
    required this.report,
    required this.serialNumber,
    required this.modelName,
    required this.plantName,
    required this.areaName,
    this.firstPhotoPath,
  });

  final Report report;
  final String serialNumber;
  final String modelName;
  final String plantName;
  final String areaName;
  final String? firstPhotoPath;
}

@immutable
class PolicyWithPendingReports {
  const PolicyWithPendingReports({
    required this.policyId,
    required this.policyFolio,
    required this.reports,
  });

  final String policyId;
  final String policyFolio;
  final List<ReportDeliveryItem> reports;
}

/// Returns all reports with status == 'pending_delivery', grouped by policyId.
final pendingDeliveryProvider =
    FutureProvider<List<PolicyWithPendingReports>>((ref) async {
  final AppDatabase db = localDatabase;

  // Get all pending_delivery reports
  final List<Report> pendingReports = await (db.select(db.reports)
        ..where((Reports r) => r.status.equals('pending_delivery')))
      .get();

  if (pendingReports.isEmpty) return <PolicyWithPendingReports>[];

  // Group by policyId via PolicyPrinters link.
  // A printer can appear in multiple policies (e.g. last year + this year).
  // We must find the specific policy whose visit is currently in_progress —
  // using getSingleOrNull() would throw StateError when multiple rows match.
  final Map<String, List<Report>> byPolicy = <String, List<Report>>{};
  for (final Report r in pendingReports) {
    // All policies that contain this printer.
    final List<PolicyPrinter> candidates = await (db.select(db.policyPrinters)
          ..where((PolicyPrinters t) => t.printerId.equals(r.printerId)))
        .get();

    // Pick the policy that has an active (in_progress) visit for THIS printer.
    String? activePolicyId;
    for (final PolicyPrinter candidate in candidates) {
      final bool hasActiveVisit = await (db.select(db.policyVisits)
            ..where((PolicyVisits v) =>
                v.policyId.equals(candidate.policyId) &
                v.status.equals('in_progress'))
            ..limit(1))
          .getSingleOrNull()
          .then((v) => v != null);
      if (hasActiveVisit) {
        activePolicyId = candidate.policyId;
        break;
      }
    }

    final String key = activePolicyId ?? '__no_policy__';
    byPolicy.putIfAbsent(key, () => <Report>[]).add(r);
  }

  final List<PolicyWithPendingReports> result = <PolicyWithPendingReports>[];

  for (final MapEntry<String, List<Report>> entry in byPolicy.entries) {
    final String policyId = entry.key;
    if (policyId == '__no_policy__') continue;

    final Policy? policy = await (db.select(db.policies)
          ..where((Policies t) => t.id.equals(policyId)))
        .getSingleOrNull();
    if (policy == null) continue;

    final List<ReportDeliveryItem> items = <ReportDeliveryItem>[];
    for (final Report r in entry.value) {
      final Printer? printer = await (db.select(db.printers)
            ..where((Printers t) => t.id.equals(r.printerId)))
          .getSingleOrNull();

      final CatalogModel? model = printer == null
          ? null
          : await (db.select(db.catalogModels)
                ..where((CatalogModels t) => t.id.equals(printer.modelId)))
              .getSingleOrNull();

      final Plant? plant = printer == null
          ? null
          : await (db.select(db.plants)
                ..where((Plants t) => t.id.equals(printer.plantId)))
              .getSingleOrNull();

      final Area? area = printer == null
          ? null
          : await (db.select(db.areas)
                ..where((Areas t) => t.id.equals(printer.areaId)))
              .getSingleOrNull();

      String? firstPhoto;
      try {
        final List<dynamic> photos =
            jsonDecode(r.photoPaths) as List<dynamic>;
        if (photos.isNotEmpty) firstPhoto = photos.first as String?;
      } catch (_) {}

      final String modelName = model != null
          ? '${model.brand} ${model.modelName}'
          : 'Desconocido';

      items.add(ReportDeliveryItem(
        report: r,
        serialNumber: printer?.serialNumber ?? r.printerId,
        modelName: modelName,
        plantName: plant?.name ?? '—',
        areaName: area?.name ?? '—',
        firstPhotoPath: firstPhoto,
      ));
    }

    if (items.isNotEmpty) {
      result.add(PolicyWithPendingReports(
        policyId: policyId,
        policyFolio: policy.folio,
        reports: items,
      ));
    }
  }

  return result;
});
