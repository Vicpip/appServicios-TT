import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:industrial_service_reports/core/router/app_routes.dart';
import 'package:industrial_service_reports/core/router/route_args.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/features/printers/models/printer_summary.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({
    super.key,
    required this.database,
  });

  final AppDatabase database;

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with WidgetsBindingObserver {
  final TextEditingController _serialController = TextEditingController();
  late final MobileScannerController _scannerController;

  List<PrinterSummary> _recentSearches = <PrinterSummary>[];
  List<PrinterSummary> _searchResults = <PrinterSummary>[];
  bool _loadingRecents = true;
  bool _searching = false;
  bool _hasSearched = false;
  bool _scannerActive = true;
  bool _processingQr = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
    _loadRecentSearches();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_scannerController.value.isInitialized) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (_scannerActive) _scannerController.start();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _scannerController.stop();
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _serialController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onQrDetected(BarcodeCapture capture) {
    if (_processingQr) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() => _processingQr = true);

    // Parse QR format: "{serial}|{model}" — extract the serial part
    final String serial =
        rawValue.contains('|') ? rawValue.split('|').first : rawValue;

    _serialController.text = serial;
    _scannerController.stop();
    setState(() => _scannerActive = false);

    _onSearchPressed().then((_) {
      if (mounted) setState(() => _processingQr = false);
    });
  }

  Future<void> _loadRecentSearches() async {
    try {
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
        .join(<Join>[
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

  Future<List<PrinterSummary>> _queryBySerial(String serial) async {
    final results = await (widget.database.select(widget.database.printers)
          ..where((p) => p.serialNumber.like('%$serial%')))
        .join(<Join>[
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

    final List<PrinterSummary> summaries = <PrinterSummary>[];

    // Sort: exact matches first, then partial
    final String lowerSerial = serial.toLowerCase();
    final exactMatches = results.where((r) {
      final Printer p = r.readTable(widget.database.printers);
      return p.serialNumber.toLowerCase() == lowerSerial;
    }).toList();
    final partialMatches = results.where((r) {
      final Printer p = r.readTable(widget.database.printers);
      return p.serialNumber.toLowerCase() != lowerSerial;
    }).toList();

    for (final row in [...exactMatches, ...partialMatches]) {
      final Printer printer = row.readTable(widget.database.printers);
      final CatalogModel model =
          row.readTable(widget.database.catalogModels);
      final Client client = row.readTable(widget.database.clients);
      final Plant plant = row.readTable(widget.database.plants);
      final Area area = row.readTable(widget.database.areas);
      final bool hasActivePolicy = await _checkActivePolicy(printer.id);

      summaries.add(PrinterSummary(
        printerId: printer.id,
        serialNumber: printer.serialNumber,
        modelWithDpi: '${model.modelName} - ${model.dpi}dpi',
        clientName: client.name,
        plantName: plant.name,
        areaName: area.name,
        hasActivePolicy: hasActivePolicy,
      ));
    }

    return summaries;
  }

  Future<void> _onSearchPressed() async {
    final String serial = _serialController.text.trim();
    if (serial.isEmpty) return;

    setState(() {
      _searching = true;
      _hasSearched = false;
      _searchResults = <PrinterSummary>[];
    });

    try {
      final List<PrinterSummary> results = await _queryBySerial(serial);

      if (!mounted) return;
      setState(() {
        _searching = false;
        _hasSearched = true;
        _searchResults = results;
      });

      if (results.isEmpty) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontró ninguna impresora con ese serial.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (results.length == 1) {
        // Single match → navigate directly
        _openPrinterConfirmation(results.first);
      }
      // Multiple results → show list below (handled in build)
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

  void _toggleScanner() {
    setState(() {
      _scannerActive = !_scannerActive;
      if (_scannerActive) {
        _scannerController.start();
      } else {
        _scannerController.stop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Identificar Impresora'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _toggleScanner,
              icon: Icon(
                _scannerActive
                    ? Icons.keyboard_rounded
                    : Icons.qr_code_scanner_rounded,
                size: 20,
              ),
              label: Text(
                _scannerActive ? 'Manual' : 'Escanear',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool isWide = constraints.maxWidth >= 900;
            final double scannerHeight = constraints.maxHeight * 0.38;

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // --- Scanner / Placeholder ---
                  SizedBox(
                    height: scannerHeight,
                    child: _scannerActive
                        ? _RealScanner(
                            controller: _scannerController,
                            onDetect: _onQrDetected,
                            processingQr: _processingQr,
                          )
                        : _ScannerPlaceholder(
                            onToggle: _toggleScanner,
                          ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: const <Widget>[
                      Expanded(
                          child: Divider(color: AppPalette.surfaceDarkHighlight)),
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
                      Expanded(
                          child: Divider(color: AppPalette.surfaceDarkHighlight)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // --- Search bar ---
                  if (isWide)
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _SearchField(
                            controller: _serialController,
                            onSubmitted: (_) => _onSearchPressed(),
                          ),
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
                                      color: AppPalette.backgroundLight,
                                    ),
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
                        _SearchField(
                          controller: _serialController,
                          onSubmitted: (_) => _onSearchPressed(),
                        ),
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
                                      color: AppPalette.backgroundLight,
                                    ),
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
                  // --- Results / Recents label ---
                  Row(
                    children: <Widget>[
                      Text(
                        _hasSearched && _searchResults.length > 1
                            ? 'Coincidencias (${_searchResults.length})'
                            : 'Búsquedas Recientes',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_hasSearched && _searchResults.length > 1) ...<Widget>[
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _hasSearched = false;
                              _searchResults = <PrinterSummary>[];
                              _serialController.clear();
                            });
                          },
                          child: const Text('Limpiar'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  // --- List ---
                  Expanded(
                    child: _buildResultsList(theme),
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

  Widget _buildResultsList(ThemeData theme) {
    // If user searched and got multiple results, show search results
    if (_hasSearched && _searchResults.length > 1) {
      return ListView.separated(
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (BuildContext context, int index) {
          final PrinterSummary printer = _searchResults[index];
          final bool isExact = printer.serialNumber.toLowerCase() ==
              _serialController.text.trim().toLowerCase();
          return _PrinterResultTile(
            printer: printer,
            isExact: isExact,
            onTap: () => _openPrinterConfirmation(printer),
          );
        },
      );
    }

    // Otherwise show recent searches
    if (_loadingRecents) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_recentSearches.isEmpty) {
      return const Center(
        child: Text(
          'Sin búsquedas recientes',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.separated(
      itemCount: _recentSearches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (BuildContext context, int index) {
        final PrinterSummary printer = _recentSearches[index];
        return _PrinterResultTile(
          printer: printer,
          isRecent: true,
          onTap: () => _openPrinterConfirmation(printer),
        );
      },
    );
  }
}

// ─── Real Scanner Widget ──────────────────────────────────────────────────────

class _RealScanner extends StatelessWidget {
  const _RealScanner({
    required this.controller,
    required this.onDetect,
    required this.processingQr,
  });

  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final bool processingQr;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.surfaceDarkHighlight, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: MobileScanner(
              controller: controller,
              onDetect: onDetect,
            ),
          ),
          const Positioned.fill(child: _ViewfinderCorners()),
          if (processingQr)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      CircularProgressIndicator(color: AppPalette.primary),
                      SizedBox(height: 12),
                      Text(
                        'Procesando QR...',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Apunte la cámara al QR de la impresora',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Scanner Placeholder (when toggled off) ──────────────────────────────────

class _ScannerPlaceholder extends StatelessWidget {
  const _ScannerPlaceholder({required this.onToggle});

  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.backgroundDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.surfaceDarkHighlight, width: 1.2),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.qr_code_scanner_rounded,
              size: 90,
              color: AppPalette.primary,
            ),
            const SizedBox(height: 14),
            const Text(
              'Cámara desactivada',
              style: TextStyle(
                color: AppPalette.backgroundLight,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onToggle,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text('Activar escáner'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Printer Result Tile ──────────────────────────────────────────────────────

class _PrinterResultTile extends StatelessWidget {
  const _PrinterResultTile({
    required this.printer,
    required this.onTap,
    this.isExact = false,
    this.isRecent = false,
  });

  final PrinterSummary printer;
  final VoidCallback onTap;
  final bool isExact;
  final bool isRecent;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppPalette.surfaceDark,
      child: ListTile(
        minTileHeight: 72,
        leading: Icon(
          isRecent ? Icons.history_rounded : Icons.print_rounded,
          size: 28,
          color: isExact ? AppPalette.success : AppPalette.primary,
        ),
        title: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'S/N: ${printer.serialNumber}  ·  ${printer.modelWithDpi.split(' - ').first}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (isExact)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppPalette.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppPalette.success.withValues(alpha: 0.4),
                  ),
                ),
                child: const Text(
                  'EXACTO',
                  style: TextStyle(
                    color: AppPalette.success,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${printer.clientName}  |  ${printer.plantName}  ·  ${printer.areaName}',
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: printer.hasActivePolicy
            ? Tooltip(
                message: 'Tiene póliza activa',
                child: Icon(
                  Icons.verified_rounded,
                  size: 20,
                  color: AppPalette.success,
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}

// ─── Search Field ─────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        decoration: const InputDecoration(
          hintText: 'Ingrese número de serie...',
          prefixIcon: Icon(Icons.search_rounded, size: 22),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}

// ─── Viewfinder Corners ───────────────────────────────────────────────────────

class _ViewfinderCorners extends StatelessWidget {
  const _ViewfinderCorners();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(26),
      child: Stack(
        children: const <Widget>[
          Positioned(
              top: 0, left: 0, child: _CornerMarker(top: true, left: true)),
          Positioned(
              top: 0,
              right: 0,
              child: _CornerMarker(top: true, left: false)),
          Positioned(
              bottom: 0,
              left: 0,
              child: _CornerMarker(top: false, left: true)),
          Positioned(
              bottom: 0,
              right: 0,
              child: _CornerMarker(top: false, left: false)),
        ],
      ),
    );
  }
}

class _CornerMarker extends StatelessWidget {
  const _CornerMarker({required this.top, required this.left});

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
              child: Container(height: thickness, width: size, color: cornerColor),
            )
          else
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(height: thickness, width: size, color: cornerColor),
            ),
          if (left)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(width: thickness, height: size, color: cornerColor),
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: Container(width: thickness, height: size, color: cornerColor),
            ),
        ],
      ),
    );
  }
}
