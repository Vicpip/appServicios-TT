import 'package:flutter/material.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/features/printers/presentation/printer_detail_screen.dart';
import 'package:industrial_service_reports/features/printers/presentation/quick_add_printer_screen.dart';
import 'package:industrial_service_reports/features/reports/presentation/express_capture_screen.dart';

enum _InventoryFilter {
  all,
  byClient,
  byPlant,
  byContact,
}

enum _InventoryStatus {
  inPolicy,
  noPolicy,
}

class PrinterInventoryScreen extends StatefulWidget {
  const PrinterInventoryScreen({
    super.key,
    required this.database,
  });

  final AppDatabase database;

  @override
  State<PrinterInventoryScreen> createState() => _PrinterInventoryScreenState();
}

class _PrinterInventoryScreenState extends State<PrinterInventoryScreen> {
  static const Color _screenBg = Color(0xFF0D1117);
  static const Color _cardBg = Color(0xFF161B22);
  static const Color _blueSoft = Color(0xFF8EC5FF);
  static const Color _bronzeSoft = Color(0xFFC7A86B);
  static const Color _orangeSoft = Color(0xFFF1A85A);

  final TextEditingController _searchController = TextEditingController();
  _InventoryFilter _selectedFilter = _InventoryFilter.all;
  String? _selectedClient;
  String? _selectedPlant;
  String? _selectedContact;

  static const List<_InventoryPrinter> _mockPrinters = <_InventoryPrinter>[
    _InventoryPrinter(
      serialNumber: 'Z7J214500982',
      model: 'ZT411',
      dpi: 300,
      client: 'Logistics Corp MX',
      plant: 'Planta Norte',
      area: 'Linea de Empaque A4',
      contact: 'Juan Perez',
      status: _InventoryStatus.inPolicy,
    ),
    _InventoryPrinter(
      serialNumber: 'X5T338100214',
      model: 'ZT610',
      dpi: 600,
      client: 'Beautyge Mexico',
      plant: 'Sede Principal',
      area: 'Empaque Final B2',
      contact: 'Daniela Rios',
      status: _InventoryStatus.noPolicy,
    ),
    _InventoryPrinter(
      serialNumber: 'Q9M119430778',
      model: 'ZD421',
      dpi: 203,
      client: 'Norte Industrial Group',
      plant: 'Planta Sur',
      area: 'Linea A1',
      contact: 'Mariana Soto',
      status: _InventoryStatus.inPolicy,
    ),
    _InventoryPrinter(
      serialNumber: 'M2R446900531',
      model: 'ZT231',
      dpi: 300,
      client: 'Empaques del Centro',
      plant: 'Nave 2',
      area: 'Recepcion de Material',
      contact: 'Luis Torres',
      status: _InventoryStatus.noPolicy,
    ),
    _InventoryPrinter(
      serialNumber: 'B4K802200667',
      model: 'ZT410',
      dpi: 203,
      client: 'Global Trade Operations',
      plant: 'Monterrey Hub',
      area: 'Linea C3',
      contact: 'Paola Nunez',
      status: _InventoryStatus.inPolicy,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<_InventoryPrinter> results = _filteredResults();

    return Scaffold(
      backgroundColor: _screenBg,
      appBar: AppBar(
        backgroundColor: _screenBg,
        title: Row(
          children: const <Widget>[
            Icon(Icons.print_rounded, size: 22),
            SizedBox(width: 8),
            Text('Impresoras'),
          ],
        ),
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
                    hintText: 'Buscar',
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
                    _InventoryChip(
                      label: 'Todos',
                      selected: _selectedFilter == _InventoryFilter.all,
                      onTap: () => setState(() {
                        _selectedFilter = _InventoryFilter.all;
                      }),
                    ),
                    const SizedBox(width: 8),
                    _InventoryChip(
                      label: 'Por Cliente',
                      selected: _selectedFilter == _InventoryFilter.byClient,
                      onTap: () => setState(() {
                        _selectedFilter = _InventoryFilter.byClient;
                        _selectedPlant = null;
                        _selectedContact = null;
                      }),
                    ),
                    const SizedBox(width: 8),
                    _InventoryChip(
                      label: 'Planta',
                      selected: _selectedFilter == _InventoryFilter.byPlant,
                      onTap: () => setState(() {
                        _selectedFilter = _InventoryFilter.byPlant;
                        _selectedClient = null;
                        _selectedContact = null;
                      }),
                    ),
                    const SizedBox(width: 8),
                    _InventoryChip(
                      label: 'Contacto',
                      selected: _selectedFilter == _InventoryFilter.byContact,
                      onTap: () => setState(() {
                        _selectedFilter = _InventoryFilter.byContact;
                        _selectedClient = null;
                        _selectedPlant = null;
                      }),
                    ),
                  ],
                ),
              ),
              if (_selectedFilter != _InventoryFilter.all) ...<Widget>[
                const SizedBox(height: 8),
                _buildEntityFilterChips(),
              ],
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Text(
                    'RESULTADOS (${results.length})',
                    style: const TextStyle(
                      color: _bronzeSoft,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 34,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                QuickAddPrinterScreen(database: widget.database),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text(
                        'Agregar Impresora',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (BuildContext context, int index) {
                    final _InventoryPrinter item = results[index];
                    return _InventoryPrinterCard(
                      printer: item,
                      cardBg: _cardBg,
                      blueSoft: _blueSoft,
                      orangeSoft: _orangeSoft,
                      onCreateReport: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ExpressCaptureScreen(),
                          ),
                        );
                      },
                      onViewDetail: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PrinterDetailScreen(
                              serialNumber: item.serialNumber,
                              model: item.model,
                              client: item.client,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_InventoryPrinter> _filteredResults() {
    final String query = _searchController.text.trim().toLowerCase();

    bool matchesEntityFilter(_InventoryPrinter p) {
      switch (_selectedFilter) {
        case _InventoryFilter.byClient:
          if (_selectedClient == null) return true;
          return p.client == _selectedClient;
        case _InventoryFilter.byPlant:
          if (_selectedPlant == null) return true;
          return p.plant == _selectedPlant;
        case _InventoryFilter.byContact:
          if (_selectedContact == null) return true;
          return p.contact == _selectedContact;
        case _InventoryFilter.all:
          return true;
      }
    }

    bool matchesQuery(_InventoryPrinter p) {
      if (query.isEmpty) return true;
      return p.serialNumber.toLowerCase().contains(query) ||
          p.model.toLowerCase().contains(query) ||
          p.client.toLowerCase().contains(query) ||
          p.plant.toLowerCase().contains(query) ||
          p.contact.toLowerCase().contains(query);
    }

    return _mockPrinters
        .where(( _InventoryPrinter p) => matchesEntityFilter(p) && matchesQuery(p))
        .toList();
  }

  Widget _buildEntityFilterChips() {
    final List<String> values = switch (_selectedFilter) {
      _InventoryFilter.byClient => _mockPrinters
          .map(( _InventoryPrinter p) => p.client)
          .toSet()
          .toList()
        ..sort(),
      _InventoryFilter.byPlant => _mockPrinters
          .map(( _InventoryPrinter p) => p.plant)
          .toSet()
          .toList()
        ..sort(),
      _InventoryFilter.byContact => _mockPrinters
          .map(( _InventoryPrinter p) => p.contact)
          .toSet()
          .toList()
        ..sort(),
      _InventoryFilter.all => <String>[],
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          ChoiceChip(
            label: const Text('Todos'),
            selected: (_selectedFilter == _InventoryFilter.byClient &&
                    _selectedClient == null) ||
                (_selectedFilter == _InventoryFilter.byPlant &&
                    _selectedPlant == null) ||
                (_selectedFilter == _InventoryFilter.byContact &&
                    _selectedContact == null),
            onSelected: (_) {
              setState(() {
                _selectedClient = null;
                _selectedPlant = null;
                _selectedContact = null;
              });
            },
            selectedColor: const Color(0xFF2D3D52),
            backgroundColor: const Color(0xFF1A2029),
            side: const BorderSide(color: Color(0xFF2A3342)),
            labelStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          ...values.map((String value) {
            final bool selected = switch (_selectedFilter) {
              _InventoryFilter.byClient => _selectedClient == value,
              _InventoryFilter.byPlant => _selectedPlant == value,
              _InventoryFilter.byContact => _selectedContact == value,
              _InventoryFilter.all => false,
            };
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(value),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    if (_selectedFilter == _InventoryFilter.byClient) {
                      _selectedClient = value;
                    } else if (_selectedFilter == _InventoryFilter.byPlant) {
                      _selectedPlant = value;
                    } else if (_selectedFilter == _InventoryFilter.byContact) {
                      _selectedContact = value;
                    }
                  });
                },
                selectedColor: const Color(0xFF2D3D52),
                backgroundColor: const Color(0xFF1A2029),
                side: const BorderSide(color: Color(0xFF2A3342)),
                labelStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _InventoryChip extends StatelessWidget {
  const _InventoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFF136DEC),
      backgroundColor: const Color(0xFF1A2029),
      side: BorderSide(
        color: selected ? const Color(0xFF136DEC) : const Color(0xFF2A3342),
      ),
      labelStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _InventoryPrinterCard extends StatelessWidget {
  const _InventoryPrinterCard({
    required this.printer,
    required this.cardBg,
    required this.blueSoft,
    required this.orangeSoft,
    required this.onCreateReport,
    required this.onViewDetail,
  });

  final _InventoryPrinter printer;
  final Color cardBg;
  final Color blueSoft;
  final Color orangeSoft;
  final VoidCallback onCreateReport;
  final VoidCallback onViewDetail;

  @override
  Widget build(BuildContext context) {
    final bool hasPolicy = printer.status == _InventoryStatus.inPolicy;
    final Color badgeBg = hasPolicy
        ? const Color(0xFF11351E)
        : const Color(0xFF3A1313);
    final Color badgeText = hasPolicy
        ? const Color(0xFF4CFF8C)
        : const Color(0xFFFF7F7F);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF26303E)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Text(
                  'NUMERO DE SERIE',
                  style: TextStyle(
                    color: Color(0xFF69AFFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hasPolicy
                          ? const Color(0xFF1F5A35)
                          : const Color(0xFF7A2A2A),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        hasPolicy
                            ? Icons.circle_rounded
                            : Icons.warning_amber_rounded,
                        size: hasPolicy ? 9 : 12,
                        color: badgeText,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hasPolicy ? 'EN POLIZA' : 'SIN POLIZA',
                        style: TextStyle(
                          color: badgeText,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              printer.serialNumber,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: _DetailPair(
                    label: 'MODELO / DPI',
                    value: '${printer.model} (${printer.dpi} dpi)',
                    valueColor: blueSoft,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DetailPair(
                    label: 'CLIENTE',
                    value: printer.client,
                    valueColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: hasPolicy ? Colors.white70 : orangeSoft,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${printer.plant} - ${printer.area}',
                    style: TextStyle(
                      color: hasPolicy ? Colors.white : orangeSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: FilledButton.icon(
                      onPressed: onCreateReport,
                      icon: const Icon(Icons.note_alt_rounded, size: 18),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF136DEC),
                        foregroundColor: Colors.white,
                      ),
                      label: const Text(
                        'Crear reporte',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: FilledButton.tonalIcon(
                      onPressed: onViewDetail,
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2A3342),
                        foregroundColor: Colors.white,
                      ),
                      label: const Text(
                        'Ver detalle',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

class _DetailPair extends StatelessWidget {
  const _DetailPair({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

@immutable
class _InventoryPrinter {
  const _InventoryPrinter({
    required this.serialNumber,
    required this.model,
    required this.dpi,
    required this.client,
    required this.plant,
    required this.area,
    required this.contact,
    required this.status,
  });

  final String serialNumber;
  final String model;
  final int dpi;
  final String client;
  final String plant;
  final String area;
  final String contact;
  final _InventoryStatus status;
}
