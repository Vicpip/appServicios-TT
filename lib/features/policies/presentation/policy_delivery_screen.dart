import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:industrial_service_reports/core/router/app_routes.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/core/router/route_args.dart';
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

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
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
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _goToSignature,
              icon: const Icon(Icons.draw_rounded, size: 20),
              label: const Text(
                'FIRMAR ENTREGA',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.success,
                foregroundColor: AppPalette.backgroundLight,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
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
                  '${report.serviceDate.day.toString().padLeft(2, '0')}/'
                  '${report.serviceDate.month.toString().padLeft(2, '0')}/'
                  '${report.serviceDate.year}',
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
