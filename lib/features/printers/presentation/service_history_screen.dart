import 'package:flutter/material.dart';

class ServiceHistoryScreen extends StatefulWidget {
  const ServiceHistoryScreen({
    super.key,
    required this.printerId,
    required this.model,
    required this.serialNumber,
  });

  final String printerId;
  final String model;
  final String serialNumber;

  @override
  State<ServiceHistoryScreen> createState() => _ServiceHistoryScreenState();
}

class _ServiceHistoryScreenState extends State<ServiceHistoryScreen> {
  static const Color _screenBg = Color(0xFF0D1117);
  static const Color _headerBg = Color(0xFF161B22);
  static const Color _cardBg = Color(0xFF161B22);
  static const Color _cardBorder = Color(0xFF273141);
  static const Color _lineColor = Color(0xFF2A3342);
  static const Color _serialBlue = Color(0xFF8EC5FF);
  static const Color _mutedText = Color(0xFF9AA8BA);
  static const Color _infoPillBg = Color(0xFF202A38);
  static const Color _infoPillBorder = Color(0xFF2C3748);
  static const Color _accentBlue = Color(0xFF69AFFF);

  static const List<_ServiceHistoryItem> _mockHistory = <_ServiceHistoryItem>[
    _ServiceHistoryItem(
      dateText: '12 Ago 2025',
      reportId: '#REP-1042',
      technician: 'Ing. Carlos M.',
      notes:
          'Se limpio sensor de ribbon, se ajusto presion de cabezal y se valido impresion continua sin errores.',
      counterText: '1,450,200 in',
      type: _ServiceType.preventivo,
    ),
    _ServiceHistoryItem(
      dateText: '03 Jul 2025',
      reportId: '#REP-1018',
      technician: 'Ing. Laura R.',
      notes:
          'Correctivo por atasco recurrente en salida. Se reemplazo rodillo y se recalibraron sensores.',
      counterText: '1,420,950 in',
      type: _ServiceType.correctivo,
    ),
    _ServiceHistoryItem(
      dateText: '22 May 2025',
      reportId: '#REP-0986',
      technician: 'Ing. Carlos M.',
      notes:
          'Diagnostico de fallas intermitentes en sensor de papel y pruebas de validacion con diferentes materiales.',
      counterText: '1,398,410 in',
      type: _ServiceType.diagnostico,
    ),
    _ServiceHistoryItem(
      dateText: '09 Abr 2025',
      reportId: '#REP-0943',
      technician: 'Ing. Fernanda T.',
      notes:
          'Instalacion inicial en linea de produccion, calibracion de parametros y pruebas de rendimiento.',
      counterText: '1,372,080 in',
      type: _ServiceType.instalacion,
    ),
    _ServiceHistoryItem(
      dateText: '18 Feb 2025',
      reportId: '#REP-0891',
      technician: 'Ing. Omar V.',
      notes:
          'Servicio preventivo de rutina. Se ejecutaron pruebas de impresion y verificacion de componentes.',
      counterText: '1,340,300 in',
      type: _ServiceType.preventivo,
    ),
  ];

  _ServiceType? _selectedFilter;

  List<_ServiceHistoryItem> get _filteredHistory {
    if (_selectedFilter == null) {
      return _mockHistory;
    }
    return _mockHistory
        .where((_ServiceHistoryItem item) => item.type == _selectedFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final String displayModel = widget.model.toLowerCase().contains('zebra')
        ? widget.model
        : 'Zebra ${widget.model}';
    final List<_ServiceHistoryItem> visibleItems = _filteredHistory;

    return Scaffold(
      backgroundColor: _screenBg,
      appBar: AppBar(
        backgroundColor: _screenBg,
        title: const Text('Historial de Servicios'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Filtrar servicios',
            onPressed: _openFilterSheet,
            icon: const Icon(Icons.filter_alt_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Container(
              margin: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: _headerBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _cardBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          displayModel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'S/N: ${widget.serialNumber}',
                          style: const TextStyle(
                            color: _serialBlue,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${widget.printerId}',
                          style: const TextStyle(
                            color: _mutedText,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      const Text(
                        'Total: 12 servicios',
                        style: TextStyle(
                          color: _mutedText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Filtro: ${_selectedFilter?.label ?? 'Todos'}',
                        style: const TextStyle(
                          color: _accentBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: visibleItems.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay servicios para este filtro',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                      itemCount: visibleItems.length,
                      itemBuilder: (BuildContext context, int index) {
                        final _ServiceHistoryItem item = visibleItems[index];
                        final bool isLast = index == visibleItems.length - 1;
                        final _TimelineStyle style = _styleFor(item.type);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              SizedBox(
                                width: 34,
                                child: Column(
                                  children: <Widget>[
                                    Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: style.iconBg,
                                        shape: BoxShape.circle,
                                        border:
                                            Border.all(color: style.iconBorder),
                                      ),
                                      child: Icon(
                                        style.icon,
                                        size: 15,
                                        color: style.iconFg,
                                      ),
                                    ),
                                    if (!isLast)
                                      Container(
                                        width: 2,
                                        height: 132,
                                        margin: const EdgeInsets.only(top: 4),
                                        color: _lineColor,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                  decoration: BoxDecoration(
                                    color: _cardBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _cardBorder),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Text(
                                            item.dateText,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            item.reportId,
                                            style: const TextStyle(
                                              color: _accentBlue,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        item.technician,
                                        style: const TextStyle(
                                          color: _mutedText,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        item.notes,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _infoPillBg,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: _infoPillBorder,
                                          ),
                                        ),
                                        child: Text(
                                          'Contador: ${item.counterText}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: () => _showSnackBar(
                                            context,
                                            'Abriendo PDF de ${item.reportId} (mock)',
                                          ),
                                          child: const Text(
                                            'Ver PDF',
                                            style: TextStyle(
                                              color: _accentBlue,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
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
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    final _ServiceType? result = await showModalBottomSheet<_ServiceType?>(
      context: context,
      backgroundColor: _headerBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 8),
              const Text(
                'Filtrar por tipo de servicio',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              ListTile(
                leading: Icon(
                  Icons.filter_alt_outlined,
                  color: _selectedFilter == null ? _accentBlue : _mutedText,
                ),
                title: const Text(
                  'Todos',
                  style: TextStyle(color: Colors.white),
                ),
                trailing: Icon(
                  _selectedFilter == null
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color:
                      _selectedFilter == null ? _accentBlue : const Color(0xFF6D7B90),
                ),
                onTap: () => Navigator.of(context).pop(null),
              ),
              ..._ServiceType.values.map(( _ServiceType type) {
                final bool selected = _selectedFilter == type;
                final _TimelineStyle style = _styleFor(type);
                return ListTile(
                  leading: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: style.iconBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: style.iconBorder),
                    ),
                    child: Icon(
                      style.icon,
                      size: 14,
                      color: style.iconFg,
                    ),
                  ),
                  title: Text(
                    type.label,
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected ? _accentBlue : const Color(0xFF6D7B90),
                  ),
                  onTap: () => Navigator.of(context).pop(type),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    setState(() {
      _selectedFilter = result;
    });
    _showSnackBar(
      context,
      'Filtro activo: ${_selectedFilter?.label ?? 'Todos'}',
    );
  }

  _TimelineStyle _styleFor(_ServiceType type) {
    switch (type) {
      case _ServiceType.preventivo:
        return const _TimelineStyle(
          icon: Icons.check_circle_rounded,
          iconBg: Color(0xFF143C2B),
          iconBorder: Color(0xFF1E6E4A),
          iconFg: Color(0xFF4CFF8C),
        );
      case _ServiceType.correctivo:
        return const _TimelineStyle(
          icon: Icons.build_rounded,
          iconBg: Color(0xFF471C1C),
          iconBorder: Color(0xFF753434),
          iconFg: Color(0xFFFF8F8F),
        );
      case _ServiceType.diagnostico:
        return const _TimelineStyle(
          icon: Icons.troubleshoot_rounded,
          iconBg: Color(0xFF2E3F17),
          iconBorder: Color(0xFF56782B),
          iconFg: Color(0xFFD6FF91),
        );
      case _ServiceType.instalacion:
        return const _TimelineStyle(
          icon: Icons.settings_input_component_rounded,
          iconBg: Color(0xFF1E304D),
          iconBorder: Color(0xFF355A8C),
          iconFg: Color(0xFF8EC5FF),
        );
    }
  }

  static void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

enum _ServiceType {
  preventivo('Preventivo'),
  correctivo('Correctivo'),
  diagnostico('Diagnostico'),
  instalacion('Instalacion');

  const _ServiceType(this.label);
  final String label;
}

@immutable
class _ServiceHistoryItem {
  const _ServiceHistoryItem({
    required this.dateText,
    required this.reportId,
    required this.technician,
    required this.notes,
    required this.counterText,
    required this.type,
  });

  final String dateText;
  final String reportId;
  final String technician;
  final String notes;
  final String counterText;
  final _ServiceType type;
}

class _TimelineStyle {
  const _TimelineStyle({
    required this.icon,
    required this.iconBg,
    required this.iconBorder,
    required this.iconFg,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconBorder;
  final Color iconFg;
}
