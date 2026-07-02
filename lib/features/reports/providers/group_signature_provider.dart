import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/data/local/local_database.dart';
import 'package:industrial_service_reports/features/policies/providers/pending_delivery_provider.dart'
    show ReportDeliveryItem;

@immutable
class ClientGroupWithReports {
  const ClientGroupWithReports({
    required this.clientId,
    required this.clientName,
    required this.signatureBlockId,
    required this.reports,
  });

  final String clientId;
  final String clientName;
  final String signatureBlockId;
  final List<ReportDeliveryItem> reports;
}

/// Returns all open group-signature groups (reports with
/// status='pending_group_signature' and reportBlockStatus='open'),
/// grouped by signatureBlockId → one entry per client group.
final pendingGroupProvider =
    FutureProvider<List<ClientGroupWithReports>>((ref) async {
  final AppDatabase db = localDatabase;

  final List<Report> pending = await (db.select(db.reports)
        ..where((Reports r) =>
            r.status.equals('pending_group_signature') &
            r.reportBlockStatus.equals('open')))
      .get();

  if (pending.isEmpty) return <ClientGroupWithReports>[];

  final Map<String, List<Report>> byBlock = <String, List<Report>>{};
  for (final Report r in pending) {
    final String key = r.signatureBlockId ?? '__unknown__';
    byBlock.putIfAbsent(key, () => <Report>[]).add(r);
  }

  final List<ClientGroupWithReports> result = <ClientGroupWithReports>[];

  for (final MapEntry<String, List<Report>> entry in byBlock.entries) {
    if (entry.key == '__unknown__') continue;

    final String blockId = entry.key;
    final List<Report> groupReports = entry.value;

    final Printer? firstPrinter = await (db.select(db.printers)
          ..where((Printers t) => t.id.equals(groupReports.first.printerId)))
        .getSingleOrNull();
    if (firstPrinter == null) continue;

    final Client? client = await (db.select(db.clients)
          ..where((Clients t) => t.id.equals(firstPrinter.clientId)))
        .getSingleOrNull();

    final List<ReportDeliveryItem> items = <ReportDeliveryItem>[];
    for (final Report r in groupReports) {
      final Printer? p = await (db.select(db.printers)
            ..where((Printers t) => t.id.equals(r.printerId)))
          .getSingleOrNull();

      final CatalogModel? model = p == null
          ? null
          : await (db.select(db.catalogModels)
                ..where((CatalogModels t) => t.id.equals(p.modelId)))
              .getSingleOrNull();

      final Plant? plant = p == null
          ? null
          : await (db.select(db.plants)
                ..where((Plants t) => t.id.equals(p.plantId)))
              .getSingleOrNull();

      final Area? area = p == null
          ? null
          : await (db.select(db.areas)
                ..where((Areas t) => t.id.equals(p.areaId)))
              .getSingleOrNull();

      String? firstPhoto;
      try {
        final List<dynamic> photos = jsonDecode(r.photoPaths) as List<dynamic>;
        if (photos.isNotEmpty) firstPhoto = photos.first as String?;
      } catch (_) {}

      items.add(ReportDeliveryItem(
        report: r,
        serialNumber: p?.serialNumber ?? r.printerId,
        modelName: model != null
            ? '${model.brand} ${model.modelName}'
            : 'Desconocido',
        plantName: plant?.name ?? '—',
        areaName: area?.name ?? '—',
        firstPhotoPath: firstPhoto,
      ));
    }

    if (items.isNotEmpty) {
      result.add(ClientGroupWithReports(
        clientId: firstPrinter.clientId,
        clientName: client?.name ?? 'Cliente',
        signatureBlockId: blockId,
        reports: items,
      ));
    }
  }

  return result;
});
