import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:industrial_service_reports/core/router/app_routes.dart';
import 'package:industrial_service_reports/core/router/route_args.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/features/printers/models/printer_summary.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({
    super.key,
    required this.database,
  });

  final AppDatabase database;

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final TextEditingController _serialController = TextEditingController();
  List<PrinterSummary> _recentSearches = <PrinterSummary>[];
  bool _loadingRecents = true;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _serialController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    try {
      // Obtener los últimos 20 reportes para extraer printerIds únicos (máx 5)
      final List<Report> recentReports =
          await (widget.database.select(widget.database.reports)
                ..orderBy([(r) => OrderingTerm.desc(r.createdAt)])
                ..limit(20))
              .get();

      final List<String> seenIds = <String>[];
      for (final Report report in recentReports) {
        if (!seenIds.contains(report.printerId)) {
          seenIds.add(report.printerId);
          if (seenIds.length >= 5) break;
        }
      }

      final List<PrinterSummary> summaries = <PrinterSummary>[];
      for (final String printerId in seenIds) {
        final PrinterSummary? summary = await _buildSummaryForId(printerId);
        if (summary != null) summaries.add(summary);
      }

      if (mounted) {
        setState(() {
          _recentSearches = summaries;
          _loadingRecents = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRecents = false);
    }
  }

  Future<PrinterSummary?> _buildSummaryForId(String printerId) async {
    final result = await (widget.database.select(widget.database.printers)
          ..where((p) => p.id.equals(printerId)))
        .join([
          innerJoin(
            widget.database.catalogModels,
            widget.database.catalogModels.id
                .equalsExp(widget.database.printers.modelId),
          ),
          innerJoin(
            widget.database.clients,
            widget.database.clients.id
                .equalsExp(widget.database.printers.clientId),
          ),
          innerJoin(
            widget.database.plants,
            widget.database.plants.id
                .equalsExp(widget.database.printers.plantId),
          ),
          innerJoin(
            widget.database.areas,
            widget.database.areas.id
                .equalsExp(widget.database.printers.areaId),
          ),
        ])
        .getSingleOrNull();

    if (result == null) return null;

    final Printer printer = result.readTable(widget.database.printers);
    final CatalogModel model = result.readTable(widget.database.catalogModels);
    final Client client = result.readTable(widget.database.clients);
    final Plant plant = result.readTable(widget.database.plants);
    final Area area = result.readTable(widget.database.areas);

    final bool hasActivePolicy = await _checkActivePolicy(printerId);

    return PrinterSummary(
      printerId: printer.id,
      serialNumber: printer.serialNumber,
      modelWithDpi: '${model.modelName} - ${model.dpi}dpi',
      clientName: client.name,
      plantName: plant.name,
      areaName: area.name,
      hasActivePolicy: hasActivePolicy,
    );
  }

  Future<bool> _checkActivePolicy(String printerId) async {
    try {
      final List<PolicyPrinter> policyPrinters =
          await (widget.database.select(widget.database.policyPrinters)
                ..where((pp) => pp.printerId.equals(printerId)))
              .get();
      if (policyPrinters.isEmpty) return false;

      final List<String> policyIds =
          policyPrinters.map((pp) => pp.policyId).toList();
      final DateTime now = DateTime.now();
      final List<Policy> activePolicies =
          await (widget.database.select(widget.database.policies)
                ..where(
                    (p) => p.id.isIn(policyIds) & p.endDate.isBiggerOrEqualValue(now)))
              .get();
      return activePolicies.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _onSearchPressed() async {
    final String serial = _serialController.text.trim();
    if (serial.isEmpty) return;

    setState(() => _searching = true);

    try {
      final results = await (widget.database.select(widget.database.printers)
            ..where((p) => p.serialNumber.like('%$serial%')))
          .join([
            innerJoin(
              widget.database.catalogModels,
              widget.database.catalogModels.id
                  .equalsExp(widget.database.printers.modelId),
            ),
            innerJoin(
              widget.database.clients,
              widget.database.clients.id
                  .equalsExp(widget.database.printers.clientId),
            ),
            innerJoin(
              widget.database.plants,
              widget.database.plants.id
                  .equalsExp(widget.database.printers.plantId),
            ),
            innerJoin(
              widget.database.areas,
              widget.database.areas.id
                  .equalsExp(widget.database.printers.areaId),
            ),
          ])
          .get();

      final result = results.isEmpty ? null : results.first;

      if (!mounted) return;
      setState(() => _searching = false);

      if (result == null) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontró ninguna impresora con ese serial.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final Printer printer = result.readTable(widget.database.printers);
      final CatalogModel model =
          result.readTable(widget.database.catalogModels);
      final Client client = result.readTable(widget.database.clients);
      final Plant plant = result.readTable(widget.database.plants);
      final Area area = result.readTable(widget.database.areas);
      final bool hasActivePolicy = await _checkActivePolicy(printer.id);

      final PrinterSummary summary = PrinterSummary(
        printerId: printer.id,
        serialNumber: printer.serialNumber,
        modelWithDpi: '${model.modelName} - ${model.dpi}dpi',
        clientName: client.name,
        plantName: plant.name,
        areaName: area.name,
        hasActivePolicy: hasActivePolicy,
      );

      if (!mounted) return;
      _openPrinterConfirmation(summary);
    } catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al buscar: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openPrinterConfirmation(PrinterSummary printer) {
    context.pushNamed(
      AppRoutes.printerConfirm,
      extra: PrinterConfirmArgs(printer: printer),
    );
  }

  void _openQuickAddPrinter() {
    context.pushNamed(AppRoutes.quickAddPrinter);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Identificar Impresora'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool isWide = constraints.maxWidth >= 900;
            final double scannerHeight = constraints.maxHeight * 0.4;

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    height: scannerHeight,
                    child: _ScannerMock(
                      onSimulateScan: _recentSearches.isNotEmpty
                          ? () => _openPrinterConfirmation(_recentSearches.first)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: const <Widget>[
                      Expanded(child: Divider(color: AppPalette.surfaceDarkHighlight)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'O buscar manualmente',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppPalette.backgroundLight,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: AppPalette.surfaceDarkHighlight)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (isWide)
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _SearchField(controller: _serialController),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: _searching ? null : _onSearchPressed,
                            icon: _searching
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppPalette.backgroundLight),
                                  )
                                : const Icon(Icons.search_rounded, size: 22),
                            label: const Text(
                              'Buscar',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: <Widget>[
                        _SearchField(controller: _serialController),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: _searching ? null : _onSearchPressed,
                            icon: _searching
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppPalette.backgroundLight),
                                  )
                                : const Icon(Icons.search_rounded, size: 22),
                            label: const Text(
                              'Buscar',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 18),
                  Text(
                    'Busquedas Recientes',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _loadingRecents
                        ? const Center(
                            child: CircularProgressIndicator(),
                          )
                        : _recentSearches.isEmpty
                            ? const Center(
                                child: Text(
                                  'Sin búsquedas recientes',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _recentSearches.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder:
                                    (BuildContext context, int index) {
                                  final PrinterSummary printer =
                                      _recentSearches[index];
                                  return Card(
                                    color: AppPalette.surfaceDark,
                                    child: ListTile(
                                      minTileHeight: 72,
                                      leading: const Icon(
                                        Icons.history_rounded,
                                        size: 28,
                                        color: AppPalette.primary,
                                      ),
                                      title: Text(
                                        'Serial: ${printer.serialNumber} - ${printer.modelWithDpi.split(' - ').first}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${printer.clientName} | ${printer.areaName}',
                                        style: const TextStyle(
                                            color: Colors.white70),
                                      ),
                                      onTap: () =>
                                          _openPrinterConfirmation(printer),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: _openQuickAddPrinter,
              icon: const Icon(Icons.add_box_rounded, size: 22),
              label: const Text(
                'Crear Nueva Impresora',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
  });

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        decoration: const InputDecoration(
          hintText: 'Ingrese numero de serie...',
          prefixIcon: Icon(Icons.search_rounded, size: 22),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}

class _ScannerMock extends StatelessWidget {
  const _ScannerMock({
    required this.onSimulateScan,
  });

  final VoidCallback? onSimulateScan;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.backgroundDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.surfaceDarkHighlight, width: 1.2),
      ),
      child: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: _ViewfinderCorners(),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const <Widget>[
                Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 110,
                  color: AppPalette.primary,
                ),
                SizedBox(height: 14),
                Text(
                  'Apunte la camara al QR de la impresora',
                  style: TextStyle(
                    color: AppPalette.backgroundLight,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (onSimulateScan != null)
            Positioned(
              right: 12,
              bottom: 12,
              child: FilledButton.tonalIcon(
                onPressed: onSimulateScan,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Simular Escaneo'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.surfaceDarkHighlight,
                  foregroundColor: AppPalette.backgroundLight,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ViewfinderCorners extends StatelessWidget {
  const _ViewfinderCorners();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(26),
      child: Stack(
        children: const <Widget>[
          Positioned(top: 0, left: 0, child: _CornerMarker(top: true, left: true)),
          Positioned(
            top: 0,
            right: 0,
            child: _CornerMarker(top: true, left: false),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: _CornerMarker(top: false, left: true),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: _CornerMarker(top: false, left: false),
          ),
        ],
      ),
    );
  }
}

class _CornerMarker extends StatelessWidget {
  const _CornerMarker({
    required this.top,
    required this.left,
  });

  final bool top;
  final bool left;

  @override
  Widget build(BuildContext context) {
    const Color cornerColor = AppPalette.primary;
    const double size = 44;
    const double thickness = 4;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: <Widget>[
          if (top)
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: thickness,
                width: size,
                color: cornerColor,
              ),
            )
          else
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: thickness,
                width: size,
                color: cornerColor,
              ),
            ),
          if (left)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: thickness,
                height: size,
                color: cornerColor,
              ),
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: thickness,
                height: size,
                color: cornerColor,
              ),
            ),
        ],
      ),
    );
  }
}
