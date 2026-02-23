import 'package:flutter/material.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/features/printers/presentation/printer_confirmation_screen.dart';
import 'package:industrial_service_reports/features/printers/presentation/quick_add_printer_screen.dart';

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

  static const List<PrinterSummary> _mockRecentSearches = <PrinterSummary>[
    PrinterSummary(
      serialNumber: '710232000196',
      modelWithDpi: 'ZT610 - 600dpi',
      clientName: 'BEAUTYGE MEXICO',
      plantName: 'Principal',
      areaName: 'Linea 3',
      hasActivePolicy: true,
    ),
    PrinterSummary(
      serialNumber: '710232000211',
      modelWithDpi: 'ZT411 - 300dpi',
      clientName: 'BEAUTYGE MEXICO',
      plantName: 'Principal',
      areaName: 'Linea 1',
      hasActivePolicy: false,
    ),
    PrinterSummary(
      serialNumber: '710232000258',
      modelWithDpi: 'ZD621 - 203dpi',
      clientName: 'BEAUTYGE MEXICO',
      plantName: 'Secundaria',
      areaName: 'Linea 4',
      hasActivePolicy: true,
    ),
  ];

  @override
  void dispose() {
    _serialController.dispose();
    super.dispose();
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
                      onSimulateScan: () =>
                          _openPrinterConfirmation(_mockRecentSearches.first),
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
                            onPressed: _showMockLookupSnackBar,
                            icon: const Icon(Icons.search_rounded, size: 22),
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
                            onPressed: _showMockLookupSnackBar,
                            icon: const Icon(Icons.search_rounded, size: 22),
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
                    child: ListView.separated(
                      itemCount: _mockRecentSearches.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (BuildContext context, int index) {
                        final PrinterSummary printer = _mockRecentSearches[index];

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
                              style: const TextStyle(color: Colors.white70),
                            ),
                            onTap: () => _openPrinterConfirmation(printer),
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

  void _showMockLookupSnackBar([_]) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Buscando en base de datos local...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openPrinterConfirmation(PrinterSummary printer) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PrinterConfirmationScreen(printer: printer),
      ),
    );
  }

  void _openQuickAddPrinter() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuickAddPrinterScreen(database: widget.database),
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

  final VoidCallback onSimulateScan;

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
