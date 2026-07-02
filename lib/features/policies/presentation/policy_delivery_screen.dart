import 'dart:io' as io;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:industrial_service_reports/core/utils/date_utils.dart' show formatLocalCDMX;
import 'package:go_router/go_router.dart';
import 'package:industrial_service_reports/core/router/app_routes.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/core/router/route_args.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/data/local/local_database.dart';
import 'package:industrial_service_reports/features/auth/providers/session_provider.dart';
import 'package:industrial_service_reports/features/policies/providers/pending_delivery_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PolicyDeliveryScreen extends ConsumerStatefulWidget {
  const PolicyDeliveryScreen({super.key, required this.policy});

  final PolicyWithPendingReports policy;

  @override
  ConsumerState<PolicyDeliveryScreen> createState() =>
      _PolicyDeliveryScreenState();
}

class _PolicyDeliveryScreenState extends ConsumerState<PolicyDeliveryScreen> {
  late final PageController _pageController;
  int _currentPage = 0;
  int? _totalAssigned;
  int? _alreadyDeliveredCount;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadTotalAssigned();
    _loadAlreadyDelivered();
  }

  Future<void> _loadTotalAssigned() async {
    final AppDatabase db = localDatabase;
    final List<PolicyPrinter> printers = await (db.select(db.policyPrinters)
          ..where((PolicyPrinters pp) =>
              pp.policyId.equals(widget.policy.policyId)))
        .get();
    if (mounted) setState(() => _totalAssigned = printers.length);
  }

  /// Counts reports with status 'signed' for this policy's printers since the
  /// active visit started. This is subtracted from _totalAssigned to compute
  /// how many printers are actually still pending in this visit round, so the
  /// button label correctly reads "PARCIAL" only when the current batch does not
  /// cover ALL remaining printers (not the historical total).
  Future<void> _loadAlreadyDelivered() async {
    final AppDatabase db = localDatabase;

    final List<PolicyPrinter> pps = await (db.select(db.policyPrinters)
          ..where((PolicyPrinters pp) =>
              pp.policyId.equals(widget.policy.policyId)))
        .get();
    final List<String> printerIds = pps.map((pp) => pp.printerId).toList();

    if (printerIds.isEmpty) {
      if (mounted) setState(() => _alreadyDeliveredCount = 0);
      return;
    }

    final PolicyVisit? activeVisit = await (db.select(db.policyVisits)
          ..where((PolicyVisits v) =>
              v.policyId.equals(widget.policy.policyId) &
              v.status.equals('in_progress'))
          ..limit(1))
        .getSingleOrNull();

    final List<Report> signed = await (db.select(db.reports)
          ..where((Reports r) {
            Expression<bool> cond =
                r.printerId.isIn(printerIds) & r.status.equals('signed');
            if (activeVisit?.startedAt != null) {
              cond = cond &
                  r.serviceDate.isBiggerOrEqualValue(activeVisit!.startedAt!);
            }
            return cond;
          }))
        .get();

    if (mounted) setState(() => _alreadyDeliveredCount = signed.length);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToSignature() {
    final session = ref.read(sessionProvider);
    context.pushNamed(
      AppRoutes.policyDeliverySignature,
      extra: PolicyDeliverySignatureArgs(
        policyId: widget.policy.policyId,
        policyFolio: widget.policy.policyFolio,
        reportIds: widget.policy.reports
            .map((r) => r.report.id)
            .toList(),
        techId: session.userId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int total = widget.policy.reports.length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            const Icon(Icons.inventory_2_rounded, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.policy.policyFolio,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                '${_currentPage + 1}/$total equipos',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          // Page indicator
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(total, (int i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _currentPage ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _currentPage
                        ? AppPalette.primary
                        : AppPalette.surfaceDarkHighlight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          // Cards
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (int p) => setState(() => _currentPage = p),
              itemCount: total,
              itemBuilder: (BuildContext ctx, int index) {
                return _DeliveryCard(item: widget.policy.reports[index]);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: const BoxDecoration(
            color: AppPalette.surfaceDark,
            border: Border(
                top: BorderSide(color: AppPalette.surfaceDarkHighlight)),
          ),
          child: Builder(builder: (BuildContext ctx) {
            final int completed = widget.policy.reports.length;
            final int? assigned = _totalAssigned;
            // canSign: at least one report ready — partial delivery is allowed
            final bool canSign = assigned != null && completed > 0;

            // pendingTotalEnVisita: how many printers are STILL pending in this
            // visit round = total printers − already signed in this visit.
            // Used only for the label, never to block signing.
            final int pendingTotalEnVisita = (assigned ?? 0) -
                (_alreadyDeliveredCount ?? 0);
            final bool isPartial =
                pendingTotalEnVisita > 0 && completed < pendingTotalEnVisita;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (!canSign && assigned != null && assigned > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Sin reportes listos para entregar',
                      style: const TextStyle(
                        color: AppPalette.warning,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: canSign ? _goToSignature : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: canSign
                          ? (isPartial
                              ? AppPalette.warning
                              : AppPalette.success)
                          : Colors.grey.shade700,
                      foregroundColor: AppPalette.backgroundLight,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(Icons.draw_rounded, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            isPartial
                                ? 'FIRMAR ENTREGA PARCIAL ($completed de $pendingTotalEnVisita equipos)'
                                : 'FIRMAR ENTREGA ($completed equipo${completed != 1 ? 's' : ''})',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.item});

  final ReportDeliveryItem item;

  @override
  Widget build(BuildContext context) {
    final report = item.report;
    final int checkedCount =
        report.technicalCheckboxes.values.where((v) => v).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: AppPalette.surfaceDark,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Model + serial
              Text(
                item.modelName,
                style: const TextStyle(
                  color: AppPalette.backgroundLight,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.serialNumber,
                style: const TextStyle(
                  color: AppPalette.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              // Location
              Row(children: <Widget>[
                const Icon(Icons.factory_rounded,
                    color: Colors.white54, size: 16),
                const SizedBox(width: 6),
                Text('${item.plantName} / ${item.areaName}',
                    style: const TextStyle(color: Colors.white70)),
              ]),
              const SizedBox(height: 6),
              // Service type + date
              Row(children: <Widget>[
                const Icon(Icons.build_rounded,
                    color: Colors.white54, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${report.serviceType}  •  '
                  '${formatLocalCDMX(report.serviceDate)}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ]),
              const SizedBox(height: 6),
              // Checklist summary
              Row(children: <Widget>[
                const Icon(Icons.checklist_rounded,
                    color: Colors.white54, size: 16),
                const SizedBox(width: 6),
                Text(
                  '$checkedCount elemento(s) en checklist',
                  style: const TextStyle(color: Colors.white70),
                ),
              ]),
              // Photo thumbnail
              if (item.firstPhotoPath != null) ...<Widget>[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    io.File(item.firstPhotoPath!),
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ],
              // View report button
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => context.pushNamed(
                  AppRoutes.reportView,
                  extra: ReportViewArgs(reportId: report.id),
                ),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Ver reporte completo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.backgroundLight,
                  side: const BorderSide(color: AppPalette.surfaceDarkHighlight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
