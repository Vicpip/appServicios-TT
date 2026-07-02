import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:industrial_service_reports/core/router/app_routes.dart';
import 'package:industrial_service_reports/core/router/route_args.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/core/utils/date_utils.dart' show formatLocalCDMX;
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/data/local/local_database.dart';
import 'package:industrial_service_reports/features/auth/providers/session_provider.dart';
import 'package:industrial_service_reports/features/policies/providers/pending_delivery_provider.dart'
    show ReportDeliveryItem;
import 'package:industrial_service_reports/features/reports/providers/group_signature_provider.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionState session = ref.watch(sessionProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppPalette.backgroundDark,
        appBar: AppBar(
          backgroundColor: AppPalette.surfaceDark,
          title: const Text('Reportes'),
          bottom: const TabBar(
            labelColor: AppPalette.backgroundLight,
            unselectedLabelColor: Colors.white60,
            indicatorColor: AppPalette.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: <Widget>[
              Tab(text: 'Recientes'),
              Tab(text: 'Grupos abiertos'),
              Tab(text: 'Póliza activa'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _RecentReportsTab(techId: session.userId),
            const _OpenGroupsTab(),
            _ActivePolicyTab(techId: session.userId),
          ],
        ),
      ),
    );
  }
}

// ─── Tab 1 — Recientes ─────────────────────────────────────────────────────

class _RecentReportItem {
  const _RecentReportItem({
    required this.reportId,
    required this.model,
    required this.serial,
    required this.dateText,
    required this.serviceType,
    required this.clientName,
  });

  final String reportId;
  final String model;
  final String serial;
  final String dateText;
  final String serviceType;
  final String clientName;
}

class _RecentReportsTab extends StatefulWidget {
  const _RecentReportsTab({required this.techId});

  final String techId;

  @override
  State<_RecentReportsTab> createState() => _RecentReportsTabState();
}

class _RecentReportsTabState extends State<_RecentReportsTab> {
  bool _loading = true;
  List<_RecentReportItem> _items = const <_RecentReportItem>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final AppDatabase db = localDatabase;

    final List<Report> reports = await (db.select(db.reports)
          ..where((Reports r) =>
              r.techId.equals(widget.techId) & r.status.equals('Signed'))
          ..orderBy([(Reports r) => OrderingTerm.desc(r.serviceDate)])
          ..limit(20))
        .get();

    final List<_RecentReportItem> items = <_RecentReportItem>[];
    for (final Report report in reports) {
      final Printer? printer = await (db.select(db.printers)
            ..where((Printers p) => p.id.equals(report.printerId)))
          .getSingleOrNull();

      final CatalogModel? model = printer == null
          ? null
          : await (db.select(db.catalogModels)
                ..where((CatalogModels m) => m.id.equals(printer.modelId)))
              .getSingleOrNull();

      final Client? client = printer == null
          ? null
          : await (db.select(db.clients)
                ..where((Clients c) => c.id.equals(printer.clientId)))
              .getSingleOrNull();

      items.add(_RecentReportItem(
        reportId: report.id,
        model: model != null
            ? '${model.brand} ${model.modelName}'
            : 'Modelo desconocido',
        serial: printer?.serialNumber ?? '—',
        dateText: formatLocalCDMX(report.serviceDate),
        serviceType: report.serviceType,
        clientName: client?.name ?? 'Cliente',
      ));
    }

    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return const _EmptyTabState(
        icon: Icons.description_outlined,
        message: 'No hay reportes recientes',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final _RecentReportItem item = _items[index];
        return _RecentReportCard(item: item);
      },
    );
  }
}

class _RecentReportCard extends StatelessWidget {
  const _RecentReportCard({required this.item});

  final _RecentReportItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.surfaceDark,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.pushNamed(
          AppRoutes.reportView,
          extra: ReportViewArgs(reportId: item.reportId),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppPalette.surfaceDarkHighlight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      item.model,
                      style: const TextStyle(
                        color: AppPalette.backgroundLight,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppPalette.surfaceDarkHighlight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      item.serviceType,
                      style: const TextStyle(
                        color: AppPalette.accentBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'S/N: ${item.serial}',
                style: const TextStyle(
                  color: AppPalette.accentBlue,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  const Icon(Icons.business_rounded,
                      size: 14, color: Colors.white54),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    item.dateText,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tab 2 — Grupos abiertos ────────────────────────────────────────────────

class _OpenGroupsTab extends ConsumerWidget {
  const _OpenGroupsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ClientGroupWithReports>> groupsAsync =
        ref.watch(pendingGroupProvider);

    return groupsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) => Center(
        child: Text(
          'Error al cargar grupos: $error',
          style: const TextStyle(color: Colors.white70),
        ),
      ),
      data: (List<ClientGroupWithReports> groups) {
        if (groups.isEmpty) {
          return const _EmptyTabState(
            icon: Icons.group_work_outlined,
            message: 'No hay grupos abiertos',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(14),
          itemCount: groups.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (BuildContext context, int index) {
            return _OpenGroupCard(group: groups[index]);
          },
        );
      },
    );
  }
}

class _OpenGroupCard extends StatelessWidget {
  const _OpenGroupCard({required this.group});

  final ClientGroupWithReports group;

  @override
  Widget build(BuildContext context) {
    final int n = group.reports.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.surfaceDarkHighlight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.group_work_rounded, color: AppPalette.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  group.clientName,
                  style: const TextStyle(
                    color: AppPalette.backgroundLight,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$n reporte${n == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final ReportDeliveryItem item in group.reports)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.print_rounded,
                      size: 14, color: Colors.white54),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${item.modelName} · S/N: ${item.serialNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.pushNamed(
                AppRoutes.groupSignature,
                extra: GroupSignatureArgs(
                  signatureBlockId: group.signatureBlockId,
                  clientName: group.clientName,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.primary,
                foregroundColor: AppPalette.backgroundLight,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text('Cerrar y firmar ($n reportes)'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tab 3 — Póliza activa ──────────────────────────────────────────────────

class _ActivePolicyPrinter {
  const _ActivePolicyPrinter({
    required this.model,
    required this.serial,
    required this.isDone,
    this.plantName,
    this.areaName,
  });

  final String model;
  final String serial;
  final bool isDone;
  final String? plantName;
  final String? areaName;
}

class _ActivePolicyData {
  const _ActivePolicyData({
    required this.clientName,
    required this.folio,
    required this.printers,
  });

  final String clientName;
  final String folio;
  final List<_ActivePolicyPrinter> printers;
}

class _ActivePolicyTab extends StatefulWidget {
  const _ActivePolicyTab({required this.techId});

  final String techId;

  @override
  State<_ActivePolicyTab> createState() => _ActivePolicyTabState();
}

class _ActivePolicyTabState extends State<_ActivePolicyTab> {
  bool _loading = true;
  _ActivePolicyData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final AppDatabase db = localDatabase;

    final List<PolicyPrinterAssignment> myAssignments =
        await (db.select(db.policyPrinterAssignments)
              ..where((PolicyPrinterAssignments a) =>
                  a.technicianId.equals(widget.techId)))
            .get();

    _ActivePolicyData? result;

    if (myAssignments.isNotEmpty) {
      final Set<String> myPolicyIds =
          myAssignments.map((PolicyPrinterAssignment a) => a.policyId).toSet();

      PolicyVisit? activeVisit;
      String? activePolicyId;
      for (final String policyId in myPolicyIds) {
        final List<PolicyVisit> visits = await (db.select(db.policyVisits)
              ..where((PolicyVisits v) =>
                  v.policyId.equals(policyId) & v.status.equals('in_progress'))
              ..orderBy([(PolicyVisits v) => OrderingTerm.desc(v.startedAt)])
              ..limit(1))
            .get();
        if (visits.isNotEmpty) {
          activeVisit = visits.first;
          activePolicyId = policyId;
          break;
        }
      }

      if (activeVisit != null && activePolicyId != null) {
        final Policy? policy = await (db.select(db.policies)
              ..where((Policies p) => p.id.equals(activePolicyId!)))
            .getSingleOrNull();

        if (policy != null) {
          final Client? client = await (db.select(db.clients)
                ..where((Clients c) => c.id.equals(policy.clientId)))
              .getSingleOrNull();

          final List<PolicyPrinter> policyPrinters = await (db
                  .select(db.policyPrinters)
                ..where(
                    (PolicyPrinters pp) => pp.policyId.equals(activePolicyId!)))
              .get();

          final DateTime? visitStart = activeVisit.startedAt;
          final List<_ActivePolicyPrinter> printers = <_ActivePolicyPrinter>[];
          for (final PolicyPrinter pp in policyPrinters) {
            final Printer? printer = await (db.select(db.printers)
                  ..where((Printers p) => p.id.equals(pp.printerId)))
                .getSingleOrNull();
            if (printer == null) continue;

            final CatalogModel? model = await (db.select(db.catalogModels)
                  ..where((CatalogModels m) => m.id.equals(printer.modelId)))
                .getSingleOrNull();

            final Plant? plant = await (db.select(db.plants)
                  ..where((Plants t) => t.id.equals(printer.plantId)))
                .getSingleOrNull();

            final Area? area = await (db.select(db.areas)
                  ..where((Areas t) => t.id.equals(printer.areaId)))
                .getSingleOrNull();

            final List<Report> doneReports = await (db.select(db.reports)
                  ..where((Reports r) {
                    Expression<bool> cond = r.printerId.equals(pp.printerId) &
                        (r.status.equals('pending_delivery') |
                            r.status.equals('signed'));
                    if (visitStart != null) {
                      cond =
                          cond & r.serviceDate.isBiggerOrEqualValue(visitStart);
                    }
                    return cond;
                  }))
                .get();
            final bool isDone = doneReports.isNotEmpty;

            printers.add(_ActivePolicyPrinter(
              model: model != null
                  ? '${model.brand} ${model.modelName}'
                  : 'Modelo desconocido',
              serial: printer.serialNumber,
              isDone: isDone,
              plantName: plant?.name,
              areaName: area?.name,
            ));
          }

          result = _ActivePolicyData(
            clientName: client?.name ?? 'Cliente',
            folio: policy.folio,
            printers: printers,
          );
        }
      }
    }

    if (mounted) {
      setState(() {
        _data = result;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final _ActivePolicyData? data = _data;
    if (data == null) {
      return const _EmptyTabState(
        icon: Icons.assignment_late_outlined,
        message: 'Sin visita de póliza activa',
      );
    }

    final int done = data.printers.where((_ActivePolicyPrinter p) => p.isDone).length;
    final int total = data.printers.length;
    final List<_ActivePolicyPrinter> pending =
        data.printers.where((_ActivePolicyPrinter p) => !p.isDone).toList();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppPalette.surfaceDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppPalette.surfaceDarkHighlight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.business_rounded,
                      color: AppPalette.accentBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data.clientName,
                      style: const TextStyle(
                        color: AppPalette.backgroundLight,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Póliza ${data.folio}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$done de $total equipos atendidos',
                style: const TextStyle(
                  color: AppPalette.accentBlue,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.pushNamed(AppRoutes.policies),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppPalette.backgroundLight,
                    side: const BorderSide(color: AppPalette.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Ver detalle de póliza'),
                ),
              ),
            ],
          ),
        ),
        if (pending.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          const Text(
            'IMPRESORAS PENDIENTES',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          for (final _ActivePolicyPrinter printer in pending)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppPalette.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppPalette.surfaceDarkHighlight),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.print_rounded,
                        size: 18, color: AppPalette.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            printer.model,
                            style: const TextStyle(
                              color: AppPalette.backgroundLight,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'S/N: ${printer.serial}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          if (printer.plantName != null ||
                              printer.areaName != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: <Widget>[
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 14,
                                    color: Colors.white54,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '${printer.plantName ?? '—'} / ${printer.areaName ?? '—'}',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// ─── Estado vacío compartido ────────────────────────────────────────────────

class _EmptyTabState extends StatelessWidget {
  const _EmptyTabState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppPalette.surfaceDarkHighlight,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: Colors.white54),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
