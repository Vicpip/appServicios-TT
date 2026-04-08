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

  // Group by policyId via PolicyPrinters link
  final Map<String, List<Report>> byPolicy = <String, List<Report>>{};
  for (final Report r in pendingReports) {
    // Find PolicyPrinter for this printer
    final PolicyPrinter? pp = await (db.select(db.policyPrinters)
          ..where((PolicyPrinters t) => t.printerId.equals(r.printerId)))
        .getSingleOrNull();

    final String key = pp?.policyId ?? '__no_policy__';
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
