import 'package:flutter/material.dart';

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
    required this.folio,
    required this.clientName,
    required this.startDate,
    required this.endDate,
    required this.coveredPrinters,
    required this.status,
  });

  final String folio;
  final String clientName;
  final String startDate;
  final String endDate;
  final int coveredPrinters;
  final PolicyStatus status;
}

class PolicyDashboardScreen extends StatefulWidget {
  const PolicyDashboardScreen({super.key});

  @override
  State<PolicyDashboardScreen> createState() => _PolicyDashboardScreenState();
}

class _PolicyDashboardScreenState extends State<PolicyDashboardScreen> {
  static const Color _screenBg = Color(0xFF0D1117);
  static const Color _cardBg = Color(0xFF161B22);
  static const Color _cardBorder = Color(0xFF293445);
  static const Color _chipBg = Color(0xFF1A2029);
  static const Color _chipBorder = Color(0xFF2A3342);
  static const Color _primaryBlue = Color(0xFF136DEC);
  static const Color _folioBlue = Color(0xFF8EC5FF);
  static const Color _mutedText = Color(0xFFA2ADBC);

  static const List<PolicySummary> _mockPolicies = <PolicySummary>[
    PolicySummary(
      folio: 'POL-2026-001',
      clientName: 'Logística Global S.A.',
      startDate: '01 Ene 2026',
      endDate: '31 Dic 2026',
      coveredPrinters: 15,
      status: PolicyStatus.active,
    ),
    PolicySummary(
      folio: 'POL-2025-118',
      clientName: 'Beautyge Mexico',
      startDate: '01 Jul 2025',
      endDate: '15 Mar 2026',
      coveredPrinters: 9,
      status: PolicyStatus.expiring,
    ),
    PolicySummary(
      folio: 'POL-2024-077',
      clientName: 'Empaques del Centro',
      startDate: '01 Ene 2024',
      endDate: '31 Dic 2025',
      coveredPrinters: 6,
      status: PolicyStatus.expired,
    ),
    PolicySummary(
      folio: 'POL-2026-014',
      clientName: 'Norte Industrial Group',
      startDate: '01 Feb 2026',
      endDate: '31 Ene 2027',
      coveredPrinters: 20,
      status: PolicyStatus.active,
    ),
    PolicySummary(
      folio: 'POL-2025-132',
      clientName: 'Global Trade Operations',
      startDate: '15 Ago 2025',
      endDate: '30 Abr 2026',
      coveredPrinters: 12,
      status: PolicyStatus.expiring,
    ),
  ];

  final TextEditingController _searchController = TextEditingController();
  _PolicyFilter _selectedFilter = _PolicyFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PolicySummary> _filteredPolicies() {
    final String query = _searchController.text.trim().toLowerCase();

    return _mockPolicies.where((PolicySummary policy) {
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

    return Scaffold(
      backgroundColor: _screenBg,
      appBar: AppBar(
        backgroundColor: _screenBg,
        title: const Text('Pólizas de Mantenimiento'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF11351E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1F5A35)),
                ),
                child: const Row(
                  children: <Widget>[
                    Icon(Icons.circle_rounded, size: 9, color: Color(0xFF4CFF8C)),
                    SizedBox(width: 7),
                    Text(
                      'ONLINE',
                      style: TextStyle(
                        color: Color(0xFF4CFF8C),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
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
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            children: <Widget>[
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1722),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFF1F2937)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Buscar por Cliente o Folio...',
                    hintStyle: TextStyle(color: Colors.white54),
                    prefixIcon: Icon(Icons.search_rounded),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
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
                      textColor: Colors.white,
                      onTap: () => setState(() {
                        _selectedFilter = _PolicyFilter.all;
                      }),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Vigentes',
                      icon: Icons.check_circle_rounded,
                      selected: _selectedFilter == _PolicyFilter.active,
                      textColor: const Color(0xFF4CFF8C),
                      onTap: () => setState(() {
                        _selectedFilter = _PolicyFilter.active;
                      }),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Por Vencer',
                      icon: Icons.schedule_rounded,
                      selected: _selectedFilter == _PolicyFilter.expiring,
                      textColor: const Color(0xFFF1A85A),
                      onTap: () => setState(() {
                        _selectedFilter = _PolicyFilter.expiring;
                      }),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Vencidas',
                      icon: Icons.error_rounded,
                      selected: _selectedFilter == _PolicyFilter.expired,
                      textColor: const Color(0xFFFF8F8F),
                      onTap: () => setState(() {
                        _selectedFilter = _PolicyFilter.expired;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: policies.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay pólizas para este filtro',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: policies.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (BuildContext context, int index) {
                          final PolicySummary policy = policies[index];
                          final _PolicyStatusStyle statusStyle =
                              _styleFor(policy.status);
                          return _PolicyCard(
                            policy: policy,
                            cardBg: _cardBg,
                            cardBorder: _cardBorder,
                            folioBlue: _folioBlue,
                            mutedText: _mutedText,
                            statusStyle: statusStyle,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AddPolicyScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Nueva Póliza',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  _PolicyStatusStyle _styleFor(PolicyStatus status) {
    return switch (status) {
      PolicyStatus.active => const _PolicyStatusStyle(
          label: 'VIGENTE',
          bg: Color(0xFF11351E),
          border: Color(0xFF1F5A35),
          text: Color(0xFF4CFF8C),
        ),
      PolicyStatus.expiring => const _PolicyStatusStyle(
          label: 'POR VENCER',
          bg: Color(0xFF4A2F10),
          border: Color(0xFF7A4F1A),
          text: Color(0xFFF1A85A),
        ),
      PolicyStatus.expired => const _PolicyStatusStyle(
          label: 'VENCIDA',
          bg: Color(0xFF471C1C),
          border: Color(0xFF753434),
          text: Color(0xFFFF8F8F),
        ),
    };
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: _PolicyDashboardScreenState._primaryBlue,
      backgroundColor: _PolicyDashboardScreenState._chipBg,
      side: BorderSide(
        color: selected
            ? _PolicyDashboardScreenState._primaryBlue
            : _PolicyDashboardScreenState._chipBorder,
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            size: 16,
            color: selected ? Colors.white : textColor,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({
    required this.policy,
    required this.cardBg,
    required this.cardBorder,
    required this.folioBlue,
    required this.mutedText,
    required this.statusStyle,
  });

  final PolicySummary policy;
  final Color cardBg;
  final Color cardBorder;
  final Color folioBlue;
  final Color mutedText;
  final _PolicyStatusStyle statusStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.description_rounded, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    policy.folio,
                    style: TextStyle(
                      color: folioBlue,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusStyle.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: statusStyle.border),
                  ),
                  child: Text(
                    '● ${statusStyle.label}',
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
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Icon(Icons.calendar_month_rounded, size: 16, color: mutedText),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Vigencia: ${policy.startDate} - ${policy.endDate}',
                    style: TextStyle(
                      color: mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2836),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2E3B4F)),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.print_rounded, size: 16, color: Colors.white70),
                      const SizedBox(width: 6),
                      Text(
                        '${policy.coveredPrinters} Equipos amparados',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 34,
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PolicyDetailScreen(policy: policy),
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2A3342),
                      foregroundColor: Colors.white,
                    ),
                    label: const Text(
                      'Ver Detalles',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
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

class AddPolicyScreen extends StatefulWidget {
  const AddPolicyScreen({
    super.key,
    this.policy,
  });

  final PolicySummary? policy;

  bool get isEditMode => policy != null;

  @override
  State<AddPolicyScreen> createState() => _AddPolicyScreenState();
}

class _AddPolicyScreenState extends State<AddPolicyScreen> {
  static const Color _screenBg = Color(0xFF0D1117);
  static const Color _cardBg = Color(0xFF161B22);
  static const Color _cardBorder = Color(0xFF293445);
  static const Color _sectionTitle = Color(0xFF8EA3BF);

  static const List<String> _clientOptions = <String>[
    'Logística Global S.A.',
    'Beautyge Mexico',
    'Empaques del Centro',
    'Norte Industrial Group',
    'Global Trade Operations',
  ];

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

  String? _selectedClient;
  String? _selectedCoverage;
  String? _selectedFrequency;
  DateTime? _startDate;
  DateTime? _endDate;

  final List<_PolicyPrinterItem> _selectedPrinters = <_PolicyPrinterItem>[
    const _PolicyPrinterItem(
      model: 'Zebra ZT411',
      serial: '52J194200122',
    ),
    const _PolicyPrinterItem(
      model: 'Zebra ZD421',
      serial: '21C203301045',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  @override
  void dispose() {
    _folioController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  void _initializeForm() {
    if (!widget.isEditMode) {
      _folioController.text = 'POL-2026-001';
      _selectedClient = _clientOptions.first;
      _selectedCoverage = _coverageOptions[1];
      _selectedFrequency = _frequencyOptions[2];
      _startDate = DateTime(2026, 1, 1);
      _endDate = DateTime(2026, 12, 31);
      _startDateController.text = _formatDate(_startDate);
      _endDateController.text = _formatDate(_endDate);
      return;
    }

    final PolicySummary policy = widget.policy!;
    _folioController.text = policy.folio;
    _selectedClient = policy.clientName;
    _selectedCoverage = 'Extendida';
    _selectedFrequency = _frequencyOptions[2];
    _startDateController.text = policy.startDate;
    _endDateController.text = policy.endDate;
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.isEditMode
        ? 'Editar Póliza de Mantenimiento'
        : 'Nueva Póliza de Mantenimiento';

    return Scaffold(
      backgroundColor: _screenBg,
      appBar: AppBar(
        backgroundColor: _screenBg,
        title: Text(title),
        actions: <Widget>[
          if (widget.isEditMode)
            IconButton(
              tooltip: 'Eliminar póliza',
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF8F8F)),
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
                          DropdownButtonFormField<String>(
                            initialValue: _selectedClient,
                            decoration: const InputDecoration(
                              labelText: 'Cliente',
                              prefixIcon: Icon(Icons.business_rounded),
                            ),
                            items: _clientOptions
                                .map(
                                  (String client) => DropdownMenuItem<String>(
                                    value: client,
                                    child: Text(client),
                                  ),
                                )
                                .toList(),
                            validator: _requiredDropdownValidator,
                            onChanged: (String? value) {
                              setState(() {
                                _selectedClient = value;
                              });
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
                            builder:
                                (BuildContext context, BoxConstraints constraints) {
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
                                  (String frequency) =>
                                      DropdownMenuItem<String>(
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
                          onPressed: _onAddMockPrinter,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text(
                            'Agregar Equipos',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                        ),
                      ),
                      child: Column(
                        children: _selectedPrinters
                            .map(
                              (_PolicyPrinterItem printer) => ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                leading: const Icon(
                                  Icons.print_rounded,
                                  color: Color(0xFF8EC5FF),
                                ),
                                title: Text(
                                  printer.model,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  'S/N: ${printer.serial}',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                trailing: IconButton(
                                  tooltip: 'Quitar equipo',
                                  onPressed: () => _removePrinter(printer),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Color(0xFFFF8F8F),
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
            color: _cardBg,
            border: Border(top: BorderSide(color: _cardBorder)),
          ),
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: FilledButton(
              onPressed: _onSave,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF136DEC),
                foregroundColor: Colors.white,
              ),
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
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
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

  void _onAddMockPrinter() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Selector de equipos (mock)'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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

  void _onSave() {
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

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Póliza guardada correctamente (mock)'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop(true);
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: _AddPolicyScreenState._cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _AddPolicyScreenState._cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 18, color: _AddPolicyScreenState._sectionTitle),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _AddPolicyScreenState._sectionTitle,
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
    required this.model,
    required this.serial,
  });

  final String model;
  final String serial;
}

class PolicyDetailScreen extends StatefulWidget {
  const PolicyDetailScreen({
    super.key,
    required this.policy,
  });

  final PolicySummary policy;

  @override
  State<PolicyDetailScreen> createState() => _PolicyDetailScreenState();
}

class _PolicyDetailScreenState extends State<PolicyDetailScreen> {
  static const Color _screenBg = Color(0xFF0D1117);
  static const Color _cardBg = Color(0xFF161B22);
  static const Color _cardBorder = Color(0xFF293445);
  static const Color _mutedText = Color(0xFFA2ADBC);
  static const Color _softBlue = Color(0xFF8EC5FF);

  late final List<_PolicyAsset> _parqueTotal;
  late final List<_PolicyAsset> _misTareas;
  late final List<_PolicyVisit> _visits;

  @override
  void initState() {
    super.initState();
    _parqueTotal = _buildParqueTotal();
    _misTareas = _parqueTotal.where((_PolicyAsset item) => item.isMine).toList();
    _visits = <_PolicyVisit>[
      const _PolicyVisit(
        title: 'Visita Q1',
        status: _VisitStatus.completed,
        dateLabel: '15 Mar 2026',
      ),
      const _PolicyVisit(
        title: 'Visita Q2',
        status: _VisitStatus.pending,
        dateLabel: '15 Jun 2026',
      ),
      const _PolicyVisit(
        title: 'Visita Q3',
        status: _VisitStatus.scheduled,
        dateLabel: '20 Sep 2026',
      ),
      const _PolicyVisit(
        title: 'Visita Q4',
        status: _VisitStatus.scheduled,
        dateLabel: '10 Dic 2026',
      ),
    ];
  }

  List<_PolicyAsset> _buildParqueTotal() {
    const List<String> models = <String>[
      'Zebra ZT411',
      'Zebra ZD421',
      'Zebra ZT610',
      'Zebra ZT231',
    ];
    const List<String> plants = <String>[
      'Planta Norte',
      'Planta Sur',
      'Principal',
      'Nave 2',
    ];
    const List<String> areas = <String>[
      'Línea de Empaque',
      'Línea 3',
      'Almacén',
      'Recibo',
    ];
    const List<String> others = <String>[
      'Pedro R.',
      'Daniela M.',
      'Mariana S.',
      'Luis T.',
    ];

    return List<_PolicyAsset>.generate(24, (int index) {
      final bool isMine = index < 12;
      final String serial = 'SN-${520000000000 + index}';
      return _PolicyAsset(
        model: models[index % models.length],
        serial: serial,
        plant: plants[index % plants.length],
        area: areas[index % areas.length],
        isMine: isMine,
        assignedTo: isMine ? 'Tú' : others[index % others.length],
      );
    });
  }

  _PolicyStatusStyle _statusStyle(PolicyStatus status) {
    return switch (status) {
      PolicyStatus.active => const _PolicyStatusStyle(
          label: 'VIGENTE',
          bg: Color(0xFF11351E),
          border: Color(0xFF1F5A35),
          text: Color(0xFF4CFF8C),
        ),
      PolicyStatus.expiring => const _PolicyStatusStyle(
          label: 'POR VENCER',
          bg: Color(0xFF4A2F10),
          border: Color(0xFF7A4F1A),
          text: Color(0xFFF1A85A),
        ),
      PolicyStatus.expired => const _PolicyStatusStyle(
          label: 'VENCIDA',
          bg: Color(0xFF471C1C),
          border: Color(0xFF753434),
          text: Color(0xFFFF8F8F),
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
      backgroundColor: _screenBg,
      appBar: AppBar(
        backgroundColor: _screenBg,
        title: const Text('Detalle de Póliza'),
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'edit') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AddPolicyScreen(policy: widget.policy),
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
                  style: TextStyle(color: Color(0xFFFF8F8F)),
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
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              children: <Widget>[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              widget.policy.folio,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: style.bg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: style.border),
                            ),
                            child: Text(
                              '● ${style.label}',
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
                            color: _softBlue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  widget.policy.clientName,
                                  style: const TextStyle(
                                    color: Colors.white,
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
                            color: _mutedText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _compactDateRange(),
                            style: const TextStyle(
                              color: _mutedText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Icon(
                            Icons.autorenew_rounded,
                            size: 16,
                            color: _mutedText,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Trimestral',
                            style: TextStyle(
                              color: _mutedText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: TabBar(
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    indicatorColor: const Color(0xFF136DEC),
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: <Widget>[
                      Tab(text: 'Mis Tareas (${_misTareas.length})'),
                      Tab(text: 'Parque Total (${_parqueTotal.length})'),
                      const Tab(text: 'Calendario'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
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
                      _CalendarTab(visits: _visits),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF136DEC),
              foregroundColor: Colors.white,
            ),
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF293445)),
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
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (showMineBadge)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E304D),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF355A8C)),
                    ),
                    child: const Text(
                      'TU ASIGNACIÓN',
                      style: TextStyle(
                        color: Color(0xFF8EC5FF),
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
                color: Color(0xFF8EC5FF),
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
              backgroundColor: Color(0xFF8EC5FF),
              child: Text(
                'T',
                style: TextStyle(
                  color: Color(0xFF0D1117),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(width: 6),
            Text(
              'Tú',
              style: TextStyle(
                color: Color(0xFF8EC5FF),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3342),
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
                color: Colors.white,
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
          const SizedBox(width: 6),
          const Icon(Icons.lock_outline_rounded, size: 14, color: Colors.white54),
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
                        color: const Color(0xFF2A3342),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF293445)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              visit.title,
                              style: const TextStyle(
                                color: Colors.white,
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
          bg: Color(0xFF11351E),
          border: Color(0xFF1F5A35),
          iconColor: Color(0xFF4CFF8C),
        ),
      _VisitStatus.pending => const _VisitStyle(
          label: 'PENDIENTE',
          icon: Icons.schedule_rounded,
          bg: Color(0xFF4A2F10),
          border: Color(0xFF7A4F1A),
          iconColor: Color(0xFFF1A85A),
        ),
      _VisitStatus.scheduled => const _VisitStyle(
          label: 'PROGRAMADA',
          icon: Icons.event_available_rounded,
          bg: Color(0xFF1E304D),
          border: Color(0xFF355A8C),
          iconColor: Color(0xFF8EC5FF),
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

