import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:industrial_service_reports/core/router/app_routes.dart';
import 'package:industrial_service_reports/core/router/route_args.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/features/printers/providers/printer_inventory_provider.dart';

enum _InventoryStatus {
  inPolicy,
  noPolicy,
}

class PrinterInventoryScreen extends ConsumerStatefulWidget {
  const PrinterInventoryScreen({
    super.key,
    required this.database,
  });

  final AppDatabase database;

  @override
  ConsumerState<PrinterInventoryScreen> createState() =>
      _PrinterInventoryScreenState();
}

class _PrinterInventoryScreenState
    extends ConsumerState<PrinterInventoryScreen> {
  static const Color _screenBg = Color(0xFF0D1117);
  static const Color _cardBg = Color(0xFF161B22);
  static const Color _blueSoft = Color(0xFF8EC5FF);
  static const Color _bronzeSoft = Color(0xFFC7A86B);
  static const Color _orangeSoft = Color(0xFFF1A85A);

  final TextEditingController _searchController = TextEditingController();
  List<_InventoryPrinter> _printers = <_InventoryPrinter>[];

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    try {
      final List<_InventoryPrinter> printers = await _buildInventoryPrinters();
      if (mounted) setState(() => _printers = printers);
    } catch (_) {
      // Handle error silently
    }
  }

  Future<List<_InventoryPrinter>> _buildInventoryPrinters() async {
    final AppDatabase db = widget.database;
    final List<_InventoryPrinter> items = <_InventoryPrinter>[];

    final List<Printer> allPrinters = await (db.select(db.printers)
          ..where((p) => p.isActive.equals(true)))
        .get();

    for (final Printer printer in allPrinters) {
      // Obtener modelo del catálogo
      final CatalogModel? model = await (db.select(db.catalogModels)
            ..where((m) => m.id.equals(printer.modelId)))
          .getSingleOrNull();
      final String modelName = model?.modelName ?? 'Modelo desconocido';

      // Obtener cliente
      final Client? client = await (db.select(db.clients)
            ..where((c) => c.id.equals(printer.clientId)))
          .getSingleOrNull();
      final String clientName = client?.name ?? 'Cliente desconocido';

      // Obtener planta
      final Plant? plant = await (db.select(db.plants)
            ..where((p) => p.id.equals(printer.plantId)))
          .getSingleOrNull();
      final String plantName = plant?.name ?? 'Planta desconocida';

      // Obtener área
      final Area? area = await (db.select(db.areas)
            ..where((a) => a.id.equals(printer.areaId)))
          .getSingleOrNull();
      final String areaName = area?.name ?? 'Área desconocida';

      // Obtener contacto de planta
      final String contact = plant?.contactName ?? 'Sin contacto';

      // Determinar status: revisar si está en alguna póliza
      final List<PolicyPrinter> policyPrinters = await (db.select(db.policyPrinters)
            ..where((pp) => pp.printerId.equals(printer.id)))
          .get();
      final _InventoryStatus status = policyPrinters.isNotEmpty
          ? _InventoryStatus.inPolicy
          : _InventoryStatus.noPolicy;

      items.add(_InventoryPrinter(
        serialNumber: printer.serialNumber,
        model: modelName,
        dpi: model?.dpi ?? 0,
        client: clientName,
        plant: plantName,
        area: areaName,
        contact: contact,
        status: status,
        printerId: printer.id,
      ));
    }

    return items;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PrinterInventoryState inventoryState =
        ref.watch(printerInventoryProvider);
    final List<_InventoryPrinter> results = _filteredResults(inventoryState);

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
                  onChanged: (String value) {
                    ref
                        .read(printerInventoryProvider.notifier)
                        .setSearchQuery(value);
                  },
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
                      selected: inventoryState.selectedFilter ==
                          PrinterFilter.all,
                      onTap: () => ref
                          .read(printerInventoryProvider.notifier)
                          .setFilter(PrinterFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _InventoryChip(
                      label: 'Por Cliente',
                      selected: inventoryState.selectedFilter ==
                          PrinterFilter.byClient,
                      onTap: () => ref
                          .read(printerInventoryProvider.notifier)
                          .setFilter(PrinterFilter.byClient),
                    ),
                    const SizedBox(width: 8),
                    _InventoryChip(
                      label: 'Planta',
                      selected: inventoryState.selectedFilter ==
                          PrinterFilter.byPlant,
                      onTap: () => ref
                          .read(printerInventoryProvider.notifier)
                          .setFilter(PrinterFilter.byPlant),
                    ),
                    const SizedBox(width: 8),
                    _InventoryChip(
                      label: 'Contacto',
                      selected: inventoryState.selectedFilter ==
                          PrinterFilter.byContact,
                      onTap: () => ref
                          .read(printerInventoryProvider.notifier)
                          .setFilter(PrinterFilter.byContact),
                    ),
                  ],
                ),
              ),
              if (inventoryState.selectedFilter != PrinterFilter.all) ...<Widget>[
                const SizedBox(height: 8),
                _buildEntityFilterChips(inventoryState),
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
                      onPressed: () => context.pushNamed(AppRoutes.quickAddPrinter),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text(
                        'Agregar Impresora',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800),
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
                      onCreateReport: () => context.pushNamed(
                        AppRoutes.capture,
                        extra: CaptureArgs(printerId: item.printerId),
                      ),
                      onViewDetail: () => context.pushNamed(
                        AppRoutes.printerDetail,
                        pathParameters: <String, String>{
                          'serialNumber': item.serialNumber,
                        },
                        extra: PrinterDetailArgs(
                          serialNumber: item.serialNumber,
                          model: item.model,
                          client: item.client,
                          printerId: item.printerId,
                        ),
                      ),
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

  List<_InventoryPrinter> _filteredResults(PrinterInventoryState state) {
    final String query = state.searchQuery.trim().toLowerCase();

    bool matchesEntityFilter(_InventoryPrinter p) {
      switch (state.selectedFilter) {
        case PrinterFilter.byClient:
          if (state.selectedClient == null) return true;
          return p.client == state.selectedClient;
        case PrinterFilter.byPlant:
          if (state.selectedPlant == null) return true;
          return p.plant == state.selectedPlant;
        case PrinterFilter.byContact:
          if (state.selectedContact == null) return true;
          return p.contact == state.selectedContact;
        case PrinterFilter.all:
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

    return _printers
        .where((_InventoryPrinter p) =>
            matchesEntityFilter(p) && matchesQuery(p))
        .toList();
  }

  Widget _buildEntityFilterChips(PrinterInventoryState state) {
    final List<String> values = switch (state.selectedFilter) {
      PrinterFilter.byClient => _printers
          .map((_InventoryPrinter p) => p.client)
          .toSet()
          .toList()
        ..sort(),
      PrinterFilter.byPlant => _printers
          .map((_InventoryPrinter p) => p.plant)
          .toSet()
          .toList()
        ..sort(),
      PrinterFilter.byContact => _printers
          .map((_InventoryPrinter p) => p.contact)
          .toSet()
          .toList()
        ..sort(),
      PrinterFilter.all => <String>[],
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          ChoiceChip(
            label: const Text('Todos'),
            selected: (state.selectedFilter == PrinterFilter.byClient &&
                    state.selectedClient == null) ||
                (state.selectedFilter == PrinterFilter.byPlant &&
                    state.selectedPlant == null) ||
                (state.selectedFilter == PrinterFilter.byContact &&
                    state.selectedContact == null),
            onSelected: (_) {
              ref
                  .read(printerInventoryProvider.notifier)
                  .setClientFilter(null);
              ref.read(printerInventoryProvider.notifier).setPlantFilter(null);
              ref
                  .read(printerInventoryProvider.notifier)
                  .setContactFilter(null);
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
            final bool selected = switch (state.selectedFilter) {
              PrinterFilter.byClient => state.selectedClient == value,
              PrinterFilter.byPlant => state.selectedPlant == value,
              PrinterFilter.byContact => state.selectedContact == value,
              PrinterFilter.all => false,
            };
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(value),
                selected: selected,
                onSelected: (_) {
                  switch (state.selectedFilter) {
                    case PrinterFilter.byClient:
                      ref
                          .read(printerInventoryProvider.notifier)
                          .setClientFilter(value);
                    case PrinterFilter.byPlant:
                      ref
                          .read(printerInventoryProvider.notifier)
                          .setPlantFilter(value);
                    case PrinterFilter.byContact:
                      ref
                          .read(printerInventoryProvider.notifier)
                          .setContactFilter(value);
                    case PrinterFilter.all:
                      break;
                  }
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
    final Color badgeBg =
        hasPolicy ? const Color(0xFF11351E) : const Color(0xFF3A1313);
    final Color badgeText =
        hasPolicy ? const Color(0xFF4CFF8C) : const Color(0xFFFF7F7F);

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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    required this.printerId,
  });

  final String serialNumber;
  final String model;
  final int dpi;
  final String client;
  final String plant;
  final String area;
  final String contact;
  final _InventoryStatus status;
  final String printerId;
}
