import 'package:drift/drift.dart' hide Column;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:industrial_service_reports/core/router/app_routes.dart';
import 'package:industrial_service_reports/core/router/route_args.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/data/local/local_database.dart';
import 'package:industrial_service_reports/features/auth/providers/session_provider.dart';
import 'package:industrial_service_reports/features/policies/providers/pending_delivery_provider.dart';
import 'package:industrial_service_reports/features/policies/providers/policy_visit_provider.dart';
import 'package:uuid/uuid.dart';

enum _PolicyFilter {
  all,
  active,
  expiring,
  expired,
}

enum PolicyStatus {
  active,
  expiring,
  expired,
}

@immutable
class PolicySummary {
  const PolicySummary({
    required this.id,
    required this.clientId,
    required this.folio,
    required this.clientName,
    required this.startDate,
    required this.endDate,
    required this.startDateRaw,
    required this.endDateRaw,
    required this.coveredPrinters,
    required this.status,
  });

  final String id;
  final String clientId;
  final String folio;
  final String clientName;
  final String startDate;
  final String endDate;
  final DateTime startDateRaw;
  final DateTime endDateRaw;
  final int coveredPrinters;
  final PolicyStatus status;
}

class PolicyDashboardScreen extends ConsumerStatefulWidget {
  const PolicyDashboardScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  ConsumerState<PolicyDashboardScreen> createState() =>
      _PolicyDashboardScreenState();
}

class _PolicyDashboardScreenState extends ConsumerState<PolicyDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  _PolicyFilter _selectedFilter = _PolicyFilter.all;
  List<PolicySummary> _policies = <PolicySummary>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPolicies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPolicies() async {
    try {
      final List<PolicySummary> policies = await _buildPolicySummaries();
      if (mounted) setState(() { _policies = policies; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<PolicySummary>> _buildPolicySummaries() async {
    final AppDatabase db = widget.database;
    final DateTime now = DateTime.now();

    final List<Policy> allPolicies = await db.select(db.policies).get();
    final List<PolicySummary> summaries = <PolicySummary>[];

    for (final Policy policy in allPolicies) {
      // Obtener nombre del cliente
      final Client? client = await (db.select(db.clients)
            ..where((c) => c.id.equals(policy.clientId)))
          .getSingleOrNull();
      final String clientName = client?.name ?? 'Cliente desconocido';

      // Contar impresoras cubiertas por la póliza
      final List<PolicyPrinter> policyPrinters = await (db.select(db.policyPrinters)
            ..where((pp) => pp.policyId.equals(policy.id)))
          .get();
      final int coveredPrinters = policyPrinters.length;

      // Determinar estado de la póliza
      final PolicyStatus status;
      if (now.isAfter(policy.endDate)) {
        status = PolicyStatus.expired;
      } else if (policy.endDate.difference(now).inDays < 30) {
        status = PolicyStatus.expiring;
      } else {
        status = PolicyStatus.active;
      }

      summaries.add(PolicySummary(
        id: policy.id,
        clientId: policy.clientId,
        folio: policy.folio,
        clientName: clientName,
        startDate: _formatDate(policy.startDate),
        endDate: _formatDate(policy.endDate),
        startDateRaw: policy.startDate,
        endDateRaw: policy.endDate,
        coveredPrinters: coveredPrinters,
        status: status,
      ));
    }

    return summaries;
  }

  String _formatDate(DateTime date) {
    final List<String> monthNames = <String>[
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${date.day.toString().padLeft(2, '0')} ${monthNames[date.month - 1]} ${date.year}';
  }

  List<PolicySummary> _filteredPolicies() {
    final String query = _searchController.text.trim().toLowerCase();

    return _policies.where((PolicySummary policy) {
      final bool matchesFilter = switch (_selectedFilter) {
        _PolicyFilter.all => true,
        _PolicyFilter.active => policy.status == PolicyStatus.active,
        _PolicyFilter.expiring => policy.status == PolicyStatus.expiring,
        _PolicyFilter.expired => policy.status == PolicyStatus.expired,
      };

      if (!matchesFilter) return false;
      if (query.isEmpty) return true;

      return policy.clientName.toLowerCase().contains(query) ||
          policy.folio.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<PolicySummary> policies = _filteredPolicies();
    final pendingAsync = ref.watch(pendingDeliveryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const <Widget>[
            Icon(Icons.assignment_rounded, size: 22),
            SizedBox(width: 8),
            Text('Pólizas'),
          ],
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppPalette.successDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppPalette.success),
                ),
                child: Row(
                  children: const <Widget>[
                    Icon(Icons.circle, color: AppPalette.success, size: 9),
                    SizedBox(width: 7),
                    Text(
                      'Sincronizado',
                      style: TextStyle(
                        color: AppPalette.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            children: <Widget>[
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Cliente o Folio',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    _FilterChip(
                      label: 'Todas',
                      icon: Icons.layers_rounded,
                      selected: _selectedFilter == _PolicyFilter.all,
                      selectedColor: AppPalette.primary,
                      selectedBorderColor: AppPalette.primaryHover,
                      onTap: () => setState(() {
                        _selectedFilter = _PolicyFilter.all;
                      }),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Vigentes',
                      icon: Icons.check_circle_rounded,
                      selected: _selectedFilter == _PolicyFilter.active,
                      selectedColor: AppPalette.successDark,
                      selectedBorderColor: AppPalette.success,
                      onTap: () => setState(() {
                        _selectedFilter = _PolicyFilter.active;
                      }),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Por Vencer',
                      icon: Icons.schedule_rounded,
                      selected: _selectedFilter == _PolicyFilter.expiring,
                      selectedColor: AppPalette.warningDark,
                      selectedBorderColor: AppPalette.warning,
                      onTap: () => setState(() {
                        _selectedFilter = _PolicyFilter.expiring;
                      }),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Vencidas',
                      icon: Icons.error_rounded,
                      selected: _selectedFilter == _PolicyFilter.expired,
                      selectedColor: const Color(0xFF471C1C),
                      selectedBorderColor: const Color(0xFFE57373),
                      onTap: () => setState(() {
                        _selectedFilter = _PolicyFilter.expired;
                      }),
                    ),
                  ],
                ),
              ),
              // Pending deliveries banner
              pendingAsync.when(
                data: (List<PolicyWithPendingReports> pending) {
                  if (pending.isEmpty) return const SizedBox.shrink();
                  final int totalReports =
                      pending.fold(0, (int s, p) => s + p.reports.length);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(height: 4),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C2E4A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppPalette.primary),
                        ),
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(children: <Widget>[
                              const Icon(Icons.pending_actions_rounded,
                                  color: AppPalette.primary, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Pendientes de entrega — $totalReports reporte(s)',
                                style: const TextStyle(
                                  color: AppPalette.backgroundLight,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            ...pending.map((PolicyWithPendingReports p) =>
                                _PendingDeliveryRow(policy: p)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: policies.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay pólizas para el filtro actual',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : ListView.separated(
                        itemCount: policies.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (BuildContext context, int index) {
                          final PolicySummary policy = policies[index];
                          return _PolicyCard(
                            database: widget.database,
                            policy: policy,
                            statusStyle: _styleFor(policy.status),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.large(
        backgroundColor: AppPalette.primary,
        foregroundColor: AppPalette.backgroundLight,
        onPressed: () async {
          final bool? saved = await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
              builder: (_) => AddPolicyScreen(database: widget.database),
            ),
          );
          if (saved == true && mounted) {
            _loadPolicies();
          }
        },
        child: const Icon(Icons.add_rounded, size: 34),
      ),
    );
  }

  _PolicyStatusStyle _styleFor(PolicyStatus status) {
    return switch (status) {
      PolicyStatus.active => const _PolicyStatusStyle(
          label: 'VIGENTE',
          bg: AppPalette.successDark,
          border: AppPalette.success,
          text: AppPalette.success,
        ),
      PolicyStatus.expiring => const _PolicyStatusStyle(
          label: 'POR VENCER',
          bg: AppPalette.warningDark,
          border: AppPalette.warning,
          text: AppPalette.warning,
        ),
      PolicyStatus.expired => const _PolicyStatusStyle(
          label: 'VENCIDA',
          bg: Color(0xFF471C1C),
          border: Color(0xFFE57373),
          text: Color(0xFFFFB3B3),
        ),
    };
  }
}

class _PendingDeliveryRow extends StatelessWidget {
  const _PendingDeliveryRow({required this.policy});

  final PolicyWithPendingReports policy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '${policy.policyFolio} — ${policy.reports.length} equipo(s)',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          FilledButton.tonal(
            onPressed: () => context.pushNamed(
              AppRoutes.policyDelivery,
              extra: policy,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.primary,
              foregroundColor: AppPalette.backgroundLight,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Iniciar entrega',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.selectedBorderColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final Color selectedBorderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: selectedColor,
      backgroundColor: AppPalette.surfaceDark,
      side: BorderSide(
        color: selected ? selectedBorderColor : AppPalette.surfaceDarkHighlight,
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            size: 15,
            color: AppPalette.backgroundLight,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppPalette.backgroundLight,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

class _PolicyCard extends ConsumerWidget {
  const _PolicyCard({
    required this.database,
    required this.policy,
    required this.statusStyle,
  });

  final AppDatabase database;
  final PolicySummary policy;
  final _PolicyStatusStyle statusStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // CAMBIO 2: buscar reportes pending_delivery para esta póliza
    final PolicyWithPendingReports? pendingPolicy =
        ref.watch(pendingDeliveryProvider).whenOrNull(
          data: (List<PolicyWithPendingReports> pending) =>
              pending.where((p) => p.policyId == policy.id).firstOrNull,
        );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PolicyDetailScreen(database: database, policy: policy),
            ),
          );
        },
        child: Card(
          color: AppPalette.surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppPalette.surfaceDarkHighlight),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.description_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        policy.folio,
                        style: const TextStyle(
                          color: AppPalette.accentBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusStyle.bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: statusStyle.border),
                      ),
                      child: Text(
                        statusStyle.label,
                        style: TextStyle(
                          color: statusStyle.text,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  policy.clientName,
                  style: const TextStyle(
                    color: AppPalette.backgroundLight,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 16,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '${policy.startDate} - ${policy.endDate}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: <Widget>[
                    _StatPill(
                      icon: Icons.print_rounded,
                      text: '${policy.coveredPrinters} Equipos amparados',
                    ),
                  ],
                ),
                // CAMBIO 2: botón VER RESUMEN si hay reportes pending_delivery
                if (pendingPolicy != null) ...<Widget>[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => context.pushNamed(
                        AppRoutes.policyDelivery,
                        extra: pendingPolicy,
                      ),
                      icon: const Icon(Icons.inventory_2_rounded, size: 18),
                      label: Text(
                        'VER RESUMEN (${pendingPolicy.reports.length} reportes)',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppPalette.primary,
                        foregroundColor: AppPalette.backgroundLight,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppPalette.surfaceDarkHighlight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: AppPalette.backgroundLight),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: AppPalette.backgroundLight,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyStatusStyle {
  const _PolicyStatusStyle({
    required this.label,
    required this.bg,
    required this.border,
    required this.text,
  });

  final String label;
  final Color bg;
  final Color border;
  final Color text;
}

// ─── Add / Edit Policy ────────────────────────────────────────────────────────

class AddPolicyScreen extends StatefulWidget {
  const AddPolicyScreen({
    super.key,
    required this.database,
    this.policy,
  });

  final AppDatabase database;
  final PolicySummary? policy;

  bool get isEditMode => policy != null;

  @override
  State<AddPolicyScreen> createState() => _AddPolicyScreenState();
}

class _AddPolicyScreenState extends State<AddPolicyScreen> {
  static const List<String> _coverageOptions = <String>[
    'Básica',
    'Extendida',
    'Premium',
  ];

  static const List<String> _frequencyOptions = <String>[
    'Mensual (12 visitas)',
    'Bimestral (6 visitas)',
    'Trimestral (4 visitas)',
    'Semestral (2 visitas)',
    'Anual (1 visita)',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _folioController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  // DB-loaded clients
  List<Client> _clients = <Client>[];
  bool _loadingClients = true;

  // Selected values
  String? _selectedClientId;
  String? _selectedCoverage;
  String? _selectedFrequency;
  DateTime? _startDate;
  DateTime? _endDate;

  // Printers
  final List<_PolicyPrinterItem> _selectedPrinters = <_PolicyPrinterItem>[];
  List<_PolicyPrinterItem> _availablePrinters = <_PolicyPrinterItem>[];
  bool _loadingPrinters = false;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _folioController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    try {
      final List<Client> clients = await (widget.database.select(widget.database.clients)
            ..where((c) => c.isActive.equals(true)))
          .get();
      if (!mounted) return;
      setState(() {
        _clients = clients;
        _loadingClients = false;
      });
      _initializeForm(clients);
    } catch (_) {
      if (mounted) setState(() => _loadingClients = false);
    }
  }

  Future<void> _loadPrintersForClient(String clientId, {String? existingPolicyId}) async {
    if (mounted) setState(() => _loadingPrinters = true);
    try {
      final AppDatabase db = widget.database;
      final List<Printer> printers = (await (db.select(db.printers)
              ..where((p) => p.clientId.equals(clientId)))
          .get())
          .where((p) => p.isActive)
          .toList();

      final List<_PolicyPrinterItem> items = <_PolicyPrinterItem>[];
      for (final Printer printer in printers) {
        final CatalogModel? model = await (db.select(db.catalogModels)
              ..where((m) => m.id.equals(printer.modelId)))
            .getSingleOrNull();
        final String modelDisplay = model != null
            ? '${model.brand} ${model.modelName}'
            : 'Modelo desconocido';
        items.add(_PolicyPrinterItem(
          id: printer.id,
          model: modelDisplay,
          serial: printer.serialNumber,
        ));
      }

      List<_PolicyPrinterItem> existing = <_PolicyPrinterItem>[];
      if (existingPolicyId != null) {
        final List<PolicyPrinter> policyPrinters = await (db.select(db.policyPrinters)
              ..where((pp) => pp.policyId.equals(existingPolicyId)))
            .get();
        final Set<String> existingIds =
            policyPrinters.map((pp) => pp.printerId).toSet();
        existing = items.where((item) => existingIds.contains(item.id)).toList();
      }

      if (mounted) {
        setState(() {
          _availablePrinters = items;
          if (existingPolicyId != null) {
            _selectedPrinters
              ..clear()
              ..addAll(existing);
          }
          _loadingPrinters = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPrinters = false);
    }
  }

  void _initializeForm(List<Client> clients) {
    if (!widget.isEditMode) {
      final DateTime now = DateTime.now();
      _folioController.text = 'POL-${now.year}-001';
      _startDateController.text = _formatDate(DateTime(now.year, 1, 1));
      _endDateController.text = _formatDate(DateTime(now.year, 12, 31));
      setState(() {
        _selectedCoverage = _coverageOptions[1];
        _selectedFrequency = _frequencyOptions[2];
        _startDate = DateTime(now.year, 1, 1);
        _endDate = DateTime(now.year, 12, 31);
        _selectedClientId = clients.isNotEmpty ? clients.first.id : null;
      });
      if (clients.isNotEmpty) {
        _loadPrintersForClient(clients.first.id);
      }
      return;
    }

    // Edit mode
    final PolicySummary policy = widget.policy!;
    _folioController.text = policy.folio;
    _startDateController.text = policy.startDate;
    _endDateController.text = policy.endDate;
    setState(() {
      _selectedClientId = policy.clientId;
      _selectedCoverage = 'Extendida';
      _selectedFrequency = _frequencyOptions[2];
      _startDate = policy.startDateRaw;
      _endDate = policy.endDateRaw;
    });
    if (policy.clientId.isNotEmpty) {
      _loadPrintersForClient(policy.clientId, existingPolicyId: policy.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.isEditMode
        ? 'Editar Póliza de Mantenimiento'
        : 'Nueva Póliza de Mantenimiento';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: <Widget>[
          if (widget.isEditMode)
            IconButton(
              tooltip: 'Eliminar póliza',
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE57373)),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 108),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  children: <Widget>[
                    _SectionCard(
                      title: 'DATOS DEL CONTRATO',
                      icon: Icons.description_rounded,
                      child: Column(
                        children: <Widget>[
                          TextFormField(
                            controller: _folioController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Folio de Póliza',
                              prefixIcon: Icon(Icons.badge_rounded),
                            ),
                            validator: _requiredValidator,
                          ),
                          const SizedBox(height: 12),
                          if (_loadingClients)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else
                            DropdownButtonFormField<String>(
                              value: _selectedClientId,
                              decoration: const InputDecoration(
                                labelText: 'Cliente',
                                prefixIcon: Icon(Icons.business_rounded),
                              ),
                              items: _clients
                                  .map(
                                    (Client client) => DropdownMenuItem<String>(
                                      value: client.id,
                                      child: Text(client.name),
                                    ),
                                  )
                                  .toList(),
                              validator: _requiredDropdownValidator,
                              onChanged: (String? value) {
                                if (value == _selectedClientId) return;
                                setState(() {
                                  _selectedClientId = value;
                                  _selectedPrinters.clear();
                                  _availablePrinters = <_PolicyPrinterItem>[];
                                });
                                if (value != null) {
                                  _loadPrintersForClient(value);
                                }
                              },
                            ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedCoverage,
                            decoration: const InputDecoration(
                              labelText: 'Nivel de Cobertura',
                              prefixIcon: Icon(Icons.workspace_premium_rounded),
                            ),
                            items: _coverageOptions
                                .map(
                                  (String coverage) => DropdownMenuItem<String>(
                                    value: coverage,
                                    child: Text(coverage),
                                  ),
                                )
                                .toList(),
                            validator: _requiredDropdownValidator,
                            onChanged: (String? value) {
                              setState(() {
                                _selectedCoverage = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SectionCard(
                      title: 'PERIODO Y FRECUENCIA',
                      icon: Icons.calendar_month_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          LayoutBuilder(
                            builder: (BuildContext context, BoxConstraints constraints) {
                              final bool compact = constraints.maxWidth < 620;
                              if (compact) {
                                return Column(
                                  children: <Widget>[
                                    _DateField(
                                      label: 'Fecha de Inicio',
                                      controller: _startDateController,
                                      onTap: () => _pickDate(isStart: true),
                                    ),
                                    const SizedBox(height: 10),
                                    _DateField(
                                      label: 'Fecha de Término',
                                      controller: _endDateController,
                                      onTap: () => _pickDate(isStart: false),
                                    ),
                                  ],
                                );
                              }
                              return Row(
                                children: <Widget>[
                                  Expanded(
                                    child: _DateField(
                                      label: 'Fecha de Inicio',
                                      controller: _startDateController,
                                      onTap: () => _pickDate(isStart: true),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _DateField(
                                      label: 'Fecha de Término',
                                      controller: _endDateController,
                                      onTap: () => _pickDate(isStart: false),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedFrequency,
                            decoration: const InputDecoration(
                              labelText: 'Frecuencia de Mantenimiento Preventivo',
                              prefixIcon: Icon(Icons.autorenew_rounded),
                            ),
                            items: _frequencyOptions
                                .map(
                                  (String frequency) => DropdownMenuItem<String>(
                                    value: frequency,
                                    child: Text(frequency),
                                  ),
                                )
                                .toList(),
                            validator: _requiredDropdownValidator,
                            onChanged: (String? value) {
                              setState(() {
                                _selectedFrequency = value;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Las fechas exactas de visita se programarán en el Calendario de la Póliza.',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SectionCard(
                      title: 'IMPRESORAS EN CONTRATO',
                      icon: Icons.print_rounded,
                      action: SizedBox(
                        height: 32,
                        child: FilledButton.icon(
                          onPressed: _onAddPrinter,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text(
                            'Agregar Equipos',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                        ),
                      ),
                      child: _loadingPrinters
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : _selectedPrinters.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Text(
                                    'Sin equipos agregados. Selecciona un cliente y agrega impresoras.',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              : Column(
                                  children: _selectedPrinters
                                      .map(
                                        (_PolicyPrinterItem printer) => ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 2,
                                          ),
                                          leading: const Icon(
                                            Icons.print_rounded,
                                            color: AppPalette.accentBlue,
                                          ),
                                          title: Text(
                                            printer.model,
                                            style: const TextStyle(
                                              color: AppPalette.backgroundLight,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          subtitle: Text(
                                            'S/N: ${printer.serial}',
                                            style: const TextStyle(
                                                color: Colors.white70),
                                          ),
                                          trailing: IconButton(
                                            tooltip: 'Quitar equipo',
                                            onPressed: () =>
                                                _removePrinter(printer),
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: Color(0xFFE57373),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          decoration: const BoxDecoration(
            color: AppPalette.surfaceDark,
            border: Border(top: BorderSide(color: AppPalette.surfaceDarkHighlight)),
          ),
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: FilledButton(
              onPressed: _onSave,
              child: const Text(
                'GUARDAR POLIZA',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Campo obligatorio';
    }
    return null;
  }

  String? _requiredDropdownValidator(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Seleccione una opción';
    }
    return null;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final DateTime now = DateTime.now();
    final DateTime initial = isStart
        ? (_startDate ?? now)
        : (_endDate ?? _startDate ?? now);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startDate = picked;
        _startDateController.text = _formatDate(picked);
      } else {
        _endDate = picked;
        _endDateController.text = _formatDate(picked);
      }
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    const List<String> months = <String>[
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];
    final String day = date.day.toString().padLeft(2, '0');
    final String month = months[date.month - 1];
    return '$day $month ${date.year}';
  }

  void _removePrinter(_PolicyPrinterItem printer) {
    setState(() {
      _selectedPrinters.remove(printer);
    });
  }

  Future<void> _onAddPrinter() async {
    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un cliente primero'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final Set<String> selectedIds =
        _selectedPrinters.map((p) => p.id).toSet();
    final List<_PolicyPrinterItem> available = _availablePrinters
        .where((p) => !selectedIds.contains(p.id))
        .toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No hay equipos disponibles (todos ya están en la póliza)'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final _PolicyPrinterItem? selected =
        await showDialog<_PolicyPrinterItem>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Seleccionar Impresora'),
          contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: available.length,
              itemBuilder: (BuildContext context, int index) {
                final _PolicyPrinterItem printer = available[index];
                return ListTile(
                  leading: const Icon(
                    Icons.print_rounded,
                    color: AppPalette.accentBlue,
                  ),
                  title: Text(
                    printer.model,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('S/N: ${printer.serial}'),
                  onTap: () => Navigator.of(context).pop(printer),
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );

    if (selected == null || !mounted) return;
    setState(() {
      _selectedPrinters.add(selected);
    });
  }

  Future<void> _confirmDelete() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Eliminar Póliza'),
          content: const Text('Esta acción eliminará la póliza seleccionada.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _onSave() async {
    final bool valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Completa los campos obligatorios'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Selecciona un cliente'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Completa las fechas de la póliza'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final AppDatabase db = widget.database;
      const Uuid uuid = Uuid();

      if (widget.isEditMode) {
        final String policyId = widget.policy!.id;
        await (db.update(db.policies)
              ..where((p) => p.id.equals(policyId)))
            .write(PoliciesCompanion(
          clientId: Value(_selectedClientId!),
          folio: Value(_folioController.text.trim()),
          startDate: Value(_startDate!),
          endDate: Value(_endDate!),
          coverageType: Value(_selectedCoverage!),
        ));

        // Replace policy printers
        await (db.delete(db.policyPrinters)
              ..where((pp) => pp.policyId.equals(policyId)))
            .go();
        for (final _PolicyPrinterItem printer in _selectedPrinters) {
          await db.into(db.policyPrinters).insert(
            PolicyPrintersCompanion.insert(
              id: uuid.v4(),
              policyId: policyId,
              printerId: printer.id,
            ),
          );
        }
      } else {
        final String policyId = uuid.v4();
        await db.into(db.policies).insert(
          PoliciesCompanion.insert(
            id: policyId,
            clientId: _selectedClientId!,
            folio: _folioController.text.trim(),
            startDate: _startDate!,
            endDate: _endDate!,
            coverageType: _selectedCoverage!,
            status: 'active',
          ),
        );
        for (final _PolicyPrinterItem printer in _selectedPrinters) {
          await db.into(db.policyPrinters).insert(
            PolicyPrintersCompanion.insert(
              id: uuid.v4(),
              policyId: policyId,
              printerId: printer.id,
            ),
          );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEditMode
              ? 'Póliza actualizada correctamente'
              : 'Póliza guardada correctamente'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.action,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppPalette.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppPalette.surfaceDarkHighlight),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 18, color: Colors.white60),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.controller,
    required this.onTap,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.event_rounded),
      ),
      validator: (String? value) {
        if ((value ?? '').trim().isEmpty) return 'Campo obligatorio';
        return null;
      },
    );
  }
}

@immutable
class _PolicyPrinterItem {
  const _PolicyPrinterItem({
    required this.id,
    required this.model,
    required this.serial,
  });

  final String id;
  final String model;
  final String serial;
}

// ─── Policy Detail ────────────────────────────────────────────────────────────

class PolicyDetailScreen extends ConsumerStatefulWidget {
  const PolicyDetailScreen({
    super.key,
    required this.database,
    required this.policy,
  });

  final AppDatabase database;
  final PolicySummary policy;

  @override
  ConsumerState<PolicyDetailScreen> createState() => _PolicyDetailScreenState();
}

class _PolicyDetailScreenState extends ConsumerState<PolicyDetailScreen> {
  List<_PolicyAsset> _parqueTotal = const <_PolicyAsset>[];
  List<_PolicyAsset> _misTareas = const <_PolicyAsset>[];
  bool _loading = true;

  // Visitas
  List<PolicyVisit> _visits = const <PolicyVisit>[];
  PolicyVisit? _activeVisit;
  int _pendingDeliveryCount = 0;
  List<PolicyDelivery> _deliveries = const <PolicyDelivery>[];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final SessionState session = ref.read(sessionProvider);
    final String currentUserId = session.userId;   // UUID
    final String currentUserCode = session.techId; // código legible, p.ej. T-0001
    final AppDatabase db = widget.database;

    List<_PolicyAsset> parque = <_PolicyAsset>[];
    List<PolicyVisit> visits = <PolicyVisit>[];
    PolicyVisit? activeVisit;
    int pendingCount = 0;

    try {
      // ── DIAGNÓSTICO ────────────────────────────────────────────────────────
      debugPrint('[PolicyDetail] policyId usado en query: ${widget.policy.id}');
      debugPrint('[PolicyDetail] session.userId (UUID): $currentUserId');
      debugPrint('[PolicyDetail] session.techId (código): $currentUserCode');

      final List<PolicyPrinter> policyPrinters = await (db.select(db.policyPrinters)
            ..where((PolicyPrinters pp) => pp.policyId.equals(widget.policy.id)))
          .get();
      debugPrint('[PolicyDetail] PolicyPrinters count para este policyId: ${policyPrinters.length}');

      // Todos los registros de PolicyPrinterAssignments en SQLite (sin filtro)
      final List<PolicyPrinterAssignment> todosAssignments =
          await db.select(db.policyPrinterAssignments).get();
      debugPrint('[PolicyDetail] TOTAL PolicyPrinterAssignments en SQLite: ${todosAssignments.length}');
      for (final PolicyPrinterAssignment a in todosAssignments) {
        debugPrint('[PolicyDetail]   assignment id=${a.id} '
            'policyId=${a.policyId} printerId=${a.printerId} '
            'technicianId=${a.technicianId}');
      }

      // Conteo filtrado por este policyId
      final List<PolicyPrinterAssignment> assignmentsPorPoliza = todosAssignments
          .where((PolicyPrinterAssignment a) => a.policyId == widget.policy.id)
          .toList();
      debugPrint('[PolicyDetail] PolicyPrinterAssignments para ESTE policyId: ${assignmentsPorPoliza.length}');
      // ───────────────────────────────────────────────────────────────────────

      for (final PolicyPrinter pp in policyPrinters) {
        final Printer? printer = await (db.select(db.printers)
              ..where((Printers p) => p.id.equals(pp.printerId)))
            .getSingleOrNull();

        if (printer == null) continue;

        final CatalogModel? model = await (db.select(db.catalogModels)
              ..where((CatalogModels m) => m.id.equals(printer.modelId)))
            .getSingleOrNull();

        final Plant? plant = await (db.select(db.plants)
              ..where((Plants pl) => pl.id.equals(printer.plantId)))
            .getSingleOrNull();

        final Area? area = await (db.select(db.areas)
              ..where((Areas a) => a.id.equals(printer.areaId)))
            .getSingleOrNull();

        // Asignaciones para esta impresora + esta póliza
        final List<PolicyPrinterAssignment> assignments = todosAssignments
            .where((PolicyPrinterAssignment a) =>
                a.printerId == pp.printerId && a.policyId == pp.policyId)
            .toList();

        bool isMine = false;
        String assignedTo = '—';
        if (assignments.isNotEmpty) {
          assignments.sort((PolicyPrinterAssignment a, PolicyPrinterAssignment b) =>
              b.assignedAt.compareTo(a.assignedAt));
          final PolicyPrinterAssignment latest = assignments.first;

          // Buscar el técnico asignado para obtener nombre y código
          final User? tech = await (db.select(db.users)
                ..where((Users u) => u.id.equals(latest.technicianId)))
              .getSingleOrNull();

          debugPrint('[PolicyDetail] printer=${printer.serialNumber} '
              'assignment.technicianId=${latest.technicianId} '
              'tech.id=${tech?.id} tech.code=${tech?.code} tech.name=${tech?.name}');

          // Comparar contra UUID (userId) y contra código (techId).
          // El servidor almacena el UUID en technician_id, pero se cubre
          // el caso donde se haya guardado el código por compatibilidad.
          isMine = latest.technicianId == currentUserId ||
              (currentUserCode.isNotEmpty &&
                  latest.technicianId == currentUserCode) ||
              (tech != null && tech.id == currentUserId) ||
              (tech?.code != null &&
                  currentUserCode.isNotEmpty &&
                  tech!.code == currentUserCode);

          if (isMine) {
            assignedTo = 'Tú';
          } else {
            assignedTo = tech?.name ?? latest.technicianId;
          }
        }

        parque.add(_PolicyAsset(
          model: model != null ? '${model.brand} ${model.modelName}' : 'Modelo desconocido',
          serial: printer.serialNumber,
          plant: plant?.name ?? '—',
          area: area?.name ?? '—',
          isMine: isMine,
          assignedTo: assignedTo,
        ));
      }

      debugPrint('[PolicyDetail] parque=${parque.length} misTareas=${parque.where((_PolicyAsset a) => a.isMine).length}');

      // Load visits — query directa a widget.database para evitar caché del provider
      visits = await (db.select(db.policyVisits)
            ..where((PolicyVisits v) => v.policyId.equals(widget.policy.id))
            ..orderBy([(PolicyVisits v) => OrderingTerm.asc(v.visitNumber)]))
          .get();
      debugPrint('[PolicyDetail] visitas count en SQLite: ${visits.length}');
      if (visits.isNotEmpty) {
        debugPrint('[PolicyDetail] primera visita: ${visits.first}');
      }
      final List<PolicyVisit> activeVisits = await (db.select(db.policyVisits)
            ..where((PolicyVisits v) =>
                v.policyId.equals(widget.policy.id) &
                v.status.equals('in_progress'))
            ..orderBy([(PolicyVisits v) => OrderingTerm.desc(v.startedAt)])
            ..limit(1))
          .get();
      activeVisit = activeVisits.firstOrNull;

      // Count pending_delivery and signed reports for printers in this policy.
      // reportsExist > 0 means the tech has actually created reports — prevents
      // false auto-complete when a visit is activated but no reports exist yet.
      int reportsExist = 0;
      for (final PolicyPrinter pp in policyPrinters) {
        final List<Report> relevantReports = await (db.select(db.reports)
              ..where((Reports r) =>
                  r.printerId.equals(pp.printerId) &
                  r.status.isIn(<String>['pending_delivery', 'signed'])))
            .get();
        reportsExist += relevantReports.length;
        pendingCount += relevantReports
            .where((Report r) => r.status == 'pending_delivery')
            .length;
      }

      // Auto-completar visita solo si:
      //   1. Hay una visita activa (in_progress)
      //   2. El técnico tiene al menos 1 tarea asignada
      //   3. Existe al menos 1 reporte creado (evita falso auto-complete al abrir tras sync)
      //   4. Ningún reporte está pendiente de entrega
      final int myTaskCount = parque.where((_PolicyAsset a) => a.isMine).length;
      // ignore: avoid_print
      debugPrint('[PolicyDetail] auto-complete check: myTasks=$myTaskCount reportsExist=$reportsExist pending=$pendingCount activeVisit=${activeVisit?.id} visitsCount=${visits.length}');
      if (activeVisit != null && myTaskCount > 0 && reportsExist > 0 && pendingCount == 0 && visits.isNotEmpty) {
        try {
          await (db.update(db.policyVisits)
                ..where((PolicyVisits v) => v.id.equals(activeVisit!.id)))
              .write(PolicyVisitsCompanion(
            status: const Value<String>('completed'),
            completedAt: Value<DateTime>(DateTime.now()),
          ));
          debugPrint('[PolicyDetail] Visita auto-completada en load: ${activeVisit!.id}');
          // Refrescar activeVisit
          activeVisit = null;
          visits = await (db.select(db.policyVisits)
                ..where((PolicyVisits v) => v.policyId.equals(widget.policy.id))
                ..orderBy([(PolicyVisits v) => OrderingTerm.asc(v.visitNumber)]))
              .get();
        } catch (e) {
          debugPrint('[PolicyDetail] Auto-completar visita en load (no fatal): $e');
        }
      }

      // Cargar historial de entregas para esta póliza
      final List<PolicyDelivery> deliveries = await (db.select(db.policyDeliveries)
            ..where((PolicyDeliveries d) => d.policyId.equals(widget.policy.id))
            ..orderBy([(PolicyDeliveries d) => OrderingTerm.desc(d.deliveryDate)]))
          .get();

      if (mounted) {
        setState(() {
          _parqueTotal = parque;
          _misTareas = parque.where((_PolicyAsset a) => a.isMine).toList();
          _visits = visits;
          _activeVisit = activeVisit;
          _pendingDeliveryCount = pendingCount;
          _deliveries = deliveries;
        });
      }
    } catch (e, stack) {
      debugPrint('[PolicyDetail] ERROR en _loadData: $e');
      debugPrint('[PolicyDetail] Stack: $stack');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  _PolicyStatusStyle _statusStyle(PolicyStatus status) {
    return switch (status) {
      PolicyStatus.active => const _PolicyStatusStyle(
          label: 'VIGENTE',
          bg: AppPalette.successDark,
          border: AppPalette.success,
          text: AppPalette.success,
        ),
      PolicyStatus.expiring => const _PolicyStatusStyle(
          label: 'POR VENCER',
          bg: AppPalette.warningDark,
          border: AppPalette.warning,
          text: AppPalette.warning,
        ),
      PolicyStatus.expired => const _PolicyStatusStyle(
          label: 'VENCIDA',
          bg: Color(0xFF471C1C),
          border: Color(0xFFE57373),
          text: Color(0xFFFFB3B3),
        ),
    };
  }

  String _compactDateRange() {
    final List<String> start = widget.policy.startDate.split(' ');
    final List<String> end = widget.policy.endDate.split(' ');
    if (start.length < 3 || end.length < 3) {
      return '${widget.policy.startDate} - ${widget.policy.endDate}';
    }
    return '${start[0]} ${start[1]} - ${end[0]} ${end[1]} ${end[2]}';
  }

  Future<void> _confirmDeletePolicy() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Eliminar Póliza'),
          content: const Text('¿Seguro que deseas eliminar esta póliza?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Póliza eliminada (mock)'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final _PolicyStatusStyle style = _statusStyle(widget.policy.status);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Póliza'),
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'edit') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AddPolicyScreen(database: widget.database, policy: widget.policy),
                  ),
                );
              }
              if (value == 'delete') {
                _confirmDeletePolicy();
              }
            },
            itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'edit',
                child: Text('Editar Póliza'),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Text(
                  'Eliminar Póliza',
                  style: TextStyle(color: Color(0xFFE57373)),
                ),
              ),
            ],
          ),
        ],
      ),
      body: DefaultTabController(
        length: 3,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              children: <Widget>[
                Card(
                  color: AppPalette.surfaceDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppPalette.surfaceDarkHighlight),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                widget.policy.folio,
                                style: const TextStyle(
                                  color: AppPalette.backgroundLight,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: style.bg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: style.border),
                              ),
                              child: Text(
                                style.label,
                                style: TextStyle(
                                  color: style.text,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.business_rounded,
                              size: 20,
                              color: AppPalette.accentBlue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    widget.policy.clientName,
                                    style: const TextStyle(
                                      color: AppPalette.backgroundLight,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Cobertura: Premium',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.event_rounded,
                              size: 16,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _compactDateRange(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Icon(
                              Icons.autorenew_rounded,
                              size: 16,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Trimestral',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppPalette.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppPalette.surfaceDarkHighlight),
                  ),
                  child: TabBar(
                    labelColor: AppPalette.backgroundLight,
                    unselectedLabelColor: Colors.white60,
                    indicatorColor: AppPalette.primary,
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: <Widget>[
                      Tab(text: 'Mis Tareas (${_misTareas.length})'),
                      Tab(text: 'Parque Total (${_parqueTotal.length})'),
                      Tab(text: 'Visitas (${_visits.length})'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (_loading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  Expanded(
                    child: TabBarView(
                      children: <Widget>[
                        _MyTasksTab(
                          tasks: _misTareas,
                          onStartService: () {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Abriendo Checklist de ${_misTareas.length} equipos...',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                        _ParqueTotalTab(printers: _parqueTotal),
                        _VisitsTab(
                          visits: _visits,
                          activeVisit: _activeVisit,
                          totalPrinters: _parqueTotal.length,
                          pendingDeliveryCount: _pendingDeliveryCount,
                          deliveries: _deliveries,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: ref.watch(pendingDeliveryProvider).whenOrNull(
        data: (List<PolicyWithPendingReports> pending) {
          final PolicyWithPendingReports? pp = pending
              .where((PolicyWithPendingReports p) => p.policyId == widget.policy.id)
              .firstOrNull;
          if (pp == null) return null;
          return SafeArea(
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
                  onPressed: () => context.pushNamed(
                    AppRoutes.policyDelivery,
                    extra: pp,
                  ),
                  icon: const Icon(Icons.inventory_2_rounded, size: 18),
                  label: Text(
                    'VER RESUMEN (${pp.reports.length} reportes)',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.primary,
                    foregroundColor: AppPalette.backgroundLight,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MyTasksTab extends StatelessWidget {
  const _MyTasksTab({
    required this.tasks,
    required this.onStartService,
  });

  final List<_PolicyAsset> tasks;
  final VoidCallback onStartService;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView.separated(
            itemCount: tasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int index) {
              final _PolicyAsset item = tasks[index];
              return _TaskCard(item: item, showMineBadge: true);
            },
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          width: double.infinity,
          child: FilledButton(
            onPressed: onStartService,
            child: Text(
              '✓ INICIAR MI SERVICIO (${tasks.length} EQUIPOS)',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ParqueTotalTab extends StatelessWidget {
  const _ParqueTotalTab({
    required this.printers,
  });

  final List<_PolicyAsset> printers;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: printers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (BuildContext context, int index) {
        final _PolicyAsset item = printers[index];
        return _TaskCard(item: item, showMineBadge: false);
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.item,
    required this.showMineBadge,
  });

  final _PolicyAsset item;
  final bool showMineBadge;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppPalette.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppPalette.surfaceDarkHighlight),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (showMineBadge)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E304D),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF355A8C)),
                    ),
                    child: const Text(
                      'TU ASIGNACIÓN',
                      style: TextStyle(
                        color: AppPalette.accentBlue,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else
                  _AssigneeBadge(item: item),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'S/N: ${item.serial}',
              style: const TextStyle(
                color: AppPalette.accentBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Colors.white60,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${item.plant} / ${item.area}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AssigneeBadge extends StatelessWidget {
  const _AssigneeBadge({
    required this.item,
  });

  final _PolicyAsset item;

  @override
  Widget build(BuildContext context) {
    if (item.isMine) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1E304D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF355A8C)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircleAvatar(
              radius: 8,
              backgroundColor: AppPalette.accentBlue,
              child: Text(
                'T',
                style: TextStyle(
                  color: AppPalette.backgroundDark,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(width: 6),
            Text(
              'Tú',
              style: TextStyle(
                color: AppPalette.accentBlue,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    // Sin asignación: mostrar candado
    if (item.assignedTo == '—') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppPalette.surfaceDarkHighlight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3A4557)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.lock_outline_rounded, size: 14, color: Colors.white54),
            SizedBox(width: 5),
            Text(
              'Sin asignar',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // Con asignación: mostrar nombre del técnico asignado
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppPalette.surfaceDarkHighlight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A4557)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircleAvatar(
            radius: 8,
            backgroundColor: const Color(0xFF495567),
            child: Text(
              item.assignedTo.characters.first.toUpperCase(),
              style: const TextStyle(
                color: AppPalette.backgroundLight,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            item.assignedTo,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarTab extends StatelessWidget {
  const _CalendarTab({
    required this.visits,
  });

  final List<_PolicyVisit> visits;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: visits.length,
      itemBuilder: (BuildContext context, int index) {
        final _PolicyVisit visit = visits[index];
        final bool isLast = index == visits.length - 1;
        final _VisitStyle style = _visitStyle(visit.status);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 30,
                child: Column(
                  children: <Widget>[
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: style.bg,
                        shape: BoxShape.circle,
                        border: Border.all(color: style.border),
                      ),
                      child: Icon(style.icon, size: 13, color: style.iconColor),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 74,
                        color: AppPalette.surfaceDarkHighlight,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Card(
                  color: AppPalette.surfaceDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppPalette.surfaceDarkHighlight),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                visit.title,
                                style: const TextStyle(
                                  color: AppPalette.backgroundLight,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Text(
                              style.label,
                              style: TextStyle(
                                color: style.iconColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          visit.dateLabel,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  _VisitStyle _visitStyle(_VisitStatus status) {
    return switch (status) {
      _VisitStatus.completed => const _VisitStyle(
          label: 'COMPLETADA',
          icon: Icons.check_rounded,
          bg: AppPalette.successDark,
          border: AppPalette.success,
          iconColor: AppPalette.success,
        ),
      _VisitStatus.pending => const _VisitStyle(
          label: 'PENDIENTE',
          icon: Icons.schedule_rounded,
          bg: AppPalette.warningDark,
          border: AppPalette.warning,
          iconColor: AppPalette.warning,
        ),
      _VisitStatus.scheduled => const _VisitStyle(
          label: 'PROGRAMADA',
          icon: Icons.event_available_rounded,
          bg: Color(0xFF1E304D),
          border: Color(0xFF355A8C),
          iconColor: AppPalette.accentBlue,
        ),
    };
  }
}

@immutable
class _PolicyAsset {
  const _PolicyAsset({
    required this.model,
    required this.serial,
    required this.plant,
    required this.area,
    required this.isMine,
    required this.assignedTo,
  });

  final String model;
  final String serial;
  final String plant;
  final String area;
  final bool isMine;
  final String assignedTo;
}

enum _VisitStatus {
  completed,
  pending,
  scheduled,
}

@immutable
class _PolicyVisit {
  const _PolicyVisit({
    required this.title,
    required this.status,
    required this.dateLabel,
  });

  final String title;
  final _VisitStatus status;
  final String dateLabel;
}

class _VisitStyle {
  const _VisitStyle({
    required this.label,
    required this.icon,
    required this.bg,
    required this.border,
    required this.iconColor,
  });

  final String label;
  final IconData icon;
  final Color bg;
  final Color border;
  final Color iconColor;
}

// ─── Visitas Tab ──────────────────────────────────────────────────────────────

class _VisitsTab extends StatelessWidget {
  const _VisitsTab({
    required this.visits,
    required this.activeVisit,
    required this.totalPrinters,
    required this.pendingDeliveryCount,
    required this.deliveries,
  });

  final List<PolicyVisit> visits;
  final PolicyVisit? activeVisit;
  final int totalPrinters;
  final int pendingDeliveryCount;
  final List<PolicyDelivery> deliveries;

  @override
  Widget build(BuildContext context) {
    debugPrint('[VisitsTab] visitas recibidas en widget: ${visits.length}');
    if (visits.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.event_busy_rounded, size: 48, color: Colors.white30),
            SizedBox(height: 12),
            Text(
              'No hay visitas generadas para esta póliza',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: <Widget>[
        // ── Visita activa ────────────────────────────────────────────────────
        if (activeVisit != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2E4A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppPalette.primary),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.sync_rounded,
                        color: AppPalette.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Visita ${activeVisit!.visitNumber}/${visits.length} — En Curso',
                      style: const TextStyle(
                        color: AppPalette.backgroundLight,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Progreso
                Row(
                  children: <Widget>[
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: totalPrinters > 0
                              ? pendingDeliveryCount / totalPrinters
                              : 0,
                          minHeight: 8,
                          backgroundColor: AppPalette.surfaceDarkHighlight,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppPalette.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$pendingDeliveryCount/$totalPrinters equipos',
                      style: const TextStyle(
                        color: AppPalette.backgroundLight,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // ── Lista de visitas ─────────────────────────────────────────────────
        const Text(
          'Historial de visitas',
          style: TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        ...visits.map((PolicyVisit v) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _VisitRow(
                visit: v,
                totalVisits: visits.length,
              ),
            )),

        // ── Historial de entregas ────────────────────────────────────────────
        if (deliveries.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          const Text(
            'Historial de entregas',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          ...deliveries.map((PolicyDelivery d) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DeliveryHistoryRow(delivery: d),
              )),
        ],
      ],
    );
  }
}

class _VisitRow extends StatelessWidget {
  const _VisitRow({required this.visit, required this.totalVisits});

  final PolicyVisit visit;
  final int totalVisits;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color border, Color textColor, String label, IconData icon) =
        switch (visit.status) {
      'in_progress' => (
          const Color(0xFF1C2E4A),
          AppPalette.primary,
          AppPalette.primary,
          'EN CURSO',
          Icons.sync_rounded,
        ),
      'completed' => (
          AppPalette.successDark,
          AppPalette.success,
          AppPalette.success,
          'COMPLETADA',
          Icons.check_circle_rounded,
        ),
      _ => (
          AppPalette.surfaceDark,
          AppPalette.surfaceDarkHighlight,
          Colors.white54,
          'PROGRAMADA',
          Icons.event_available_rounded,
        ),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Visita ${visit.visitNumber}/$totalVisits',
                  style: const TextStyle(
                    color: AppPalette.backgroundLight,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                if (visit.scheduledDate != null)
                  Text(
                    visit.scheduledDate!,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppPalette.backgroundDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryHistoryRow extends StatelessWidget {
  const _DeliveryHistoryRow({required this.delivery});

  final PolicyDelivery delivery;

  String _formatDate(DateTime date) {
    const List<String> months = <String>[
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: AppPalette.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.surfaceDarkHighlight),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.check_circle_rounded,
              color: AppPalette.success, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _formatDate(delivery.deliveryDate),
                  style: const TextStyle(
                    color: AppPalette.backgroundLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Firmó: ${delivery.signatureName}',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => context.pushNamed(
              AppRoutes.visitSummary,
              extra: VisitSummaryArgs(
                deliveryId: delivery.id,
                policyFolio: '',
              ),
            ),
            icon: const Icon(Icons.summarize_rounded, size: 14),
            label: const Text('Ver resumen'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppPalette.backgroundLight,
              side: const BorderSide(color: AppPalette.surfaceDarkHighlight),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
