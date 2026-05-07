import 'package:drift/drift.dart' show OrderingTerm, OrderingMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:industrial_service_reports/core/router/app_routes.dart';
import 'package:industrial_service_reports/core/router/route_args.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:qr_flutter/qr_flutter.dart';

enum _PrinterStatus { ok, needsAttention, noHistory }

class PrinterDetailScreen extends StatefulWidget {
  const PrinterDetailScreen({
    super.key,
    required this.serialNumber,
    required this.model,
    required this.client,
    required this.printerId,
    required this.database,
  });

  final String serialNumber;
  final String model;
  final String client;
  final String printerId;
  final AppDatabase database;

  @override
  State<PrinterDetailScreen> createState() => _PrinterDetailScreenState();
}

class _PrinterDetailScreenState extends State<PrinterDetailScreen> {
  String? _plantName;
  String? _areaName;
  Report? _lastService;
  String? _technicianName;
  String? _printerCode;

  @override
  void initState() {
    super.initState();
    _loadPrinterDetails();
  }

  Future<void> _loadPrinterDetails() async {
    try {
      // Obtener datos de la impresora
      final Printer? printer = await (widget.database.select(widget.database.printers)
            ..where((p) => p.id.equals(widget.printerId)))
          .getSingleOrNull();

      if (printer != null) {
        // Obtener planta
        final Plant? plant = await (widget.database.select(widget.database.plants)
              ..where((p) => p.id.equals(printer.plantId)))
            .getSingleOrNull();

        // Obtener área
        final Area? area = await (widget.database.select(widget.database.areas)
              ..where((a) => a.id.equals(printer.areaId)))
            .getSingleOrNull();

        // Obtener último reporte
        final List<Report> reports = await (widget.database.select(widget.database.reports)
              ..where((r) => r.printerId.equals(widget.printerId))
              ..orderBy([(r) => OrderingTerm(expression: r.serviceDate, mode: OrderingMode.desc)])
              ..limit(1))
            .get();

        Report? lastReport;
        String? techName;
        if (reports.isNotEmpty) {
          final Report report = reports.first;
          lastReport = report;
          // Obtener nombre del técnico
          final User? technician = await (widget.database.select(widget.database.users)
                ..where((u) => u.id.equals(report.techId)))
              .getSingleOrNull();
          techName = technician?.name;
        }

        if (mounted) {
          setState(() {
            _plantName = plant?.name;
            _areaName = area?.name;
            _lastService = lastReport;
            _technicianName = techName;
            _printerCode = printer.code;
          });
        }
      }
    } catch (_) {
      // Handle error silently
    }
  }

  _PrinterStatus _computeStatus() {
    if (_lastService == null) return _PrinterStatus.noHistory;
    final Map<String, dynamic> checkboxes = _lastService!.technicalCheckboxes;
    const List<String> damageItems = <String>[
      'Rodillo dañado',
      'Cabezal dañado',
      'Sensor ribbon dañado',
      'Sensor papel dañado',
    ];
    for (final String item in damageItems) {
      if (checkboxes[item] == true) {
        return _PrinterStatus.needsAttention;
      }
    }
    return _PrinterStatus.ok;
  }

  @override
  Widget build(BuildContext context) {
    const Color screenBg = Color(0xFF0D1117);
    const Color cardBg = Color(0xFF101826);
    const Color cardBorder = Color(0xFF243245);
    const Color textMuted = Color(0xFF8BA0BC);
    const Color infoBlue = Color(0xFF2A8BFF);
    const Color successBg = Color(0xFF103A27);
    const Color successText = Color(0xFF33E98A);
    const Color warningBg = Color(0xFF4A3A12);
    const Color warningText = Color(0xFFFFD166);
    const Color noHistoryBg = Color(0xFF242E3D);

    final _PrinterStatus printerStatus = _computeStatus();
    final String displayModel =
        widget.model.toLowerCase().contains('zebra') ? widget.model : 'Zebra ${widget.model}';
    final String lastServiceType = _lastService?.serviceType ?? 'Preventivo';
    final _ServiceTypeVisual lastServiceVisual =
        _serviceTypeVisual(lastServiceType);
    final String lastServiceDate = _lastService != null ? _formatDate(_lastService!.serviceDate) : 'Sin registros';
    final String counter = _lastService != null
        ? _lastService!.linearInchesCounter.toString()
        : 'N/A';
    final String displayCode = _printerCode ?? widget.printerId.substring(0, 8);

    return Scaffold(
      backgroundColor: screenBg,
      appBar: AppBar(
        backgroundColor: screenBg,
        title: const Text('Ficha Tecnica'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              children: const <Widget>[
                Icon(Icons.offline_bolt_rounded, size: 13, color: Color(0xFF5DC9FF)),
                SizedBox(width: 4),
                Text(
                  'OFFLINE READY',
                  style: TextStyle(
                    color: Color(0xFF5DC9FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 140),
          child: Column(
            children: <Widget>[
              _DetailCard(
                bgColor: cardBg,
                borderColor: cardBorder,
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFF152133),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cardBorder),
                      ),
                      child: const Icon(
                        Icons.print_rounded,
                        size: 32,
                        color: Color(0xFFC6D2E4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            displayModel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'S/N: ${widget.serialNumber}',
                            style: const TextStyle(
                              color: infoBlue,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Código: $displayCode',
                            style: const TextStyle(
                              color: textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'CONTADOR ACTUAL',
                            style: TextStyle(
                              color: textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.7,
                            ),
                          ),
                          Text(
                            _lastService != null ? '$counter in' : counter,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _DetailCard(
                bgColor: cardBg,
                borderColor: cardBorder,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'ESTADO DE LA IMPRESORA',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Text(
                          printerStatus == _PrinterStatus.ok
                              ? 'Correcta'
                              : printerStatus == _PrinterStatus.needsAttention
                                  ? 'Atencion'
                                  : 'Sin historial',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: printerStatus == _PrinterStatus.ok
                                ? successBg
                                : printerStatus == _PrinterStatus.needsAttention
                                    ? warningBg
                                    : noHistoryBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: printerStatus == _PrinterStatus.ok
                                  ? successText.withValues(alpha: 0.45)
                                  : printerStatus == _PrinterStatus.needsAttention
                                      ? warningText.withValues(alpha: 0.45)
                                      : Colors.white54.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Icons.circle_rounded,
                                size: 9,
                                color: printerStatus == _PrinterStatus.ok
                                    ? successText
                                    : printerStatus == _PrinterStatus.needsAttention
                                        ? warningText
                                        : Colors.white54,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                printerStatus == _PrinterStatus.ok
                                    ? 'EN LINEA'
                                    : printerStatus == _PrinterStatus.needsAttention
                                        ? 'ATENCION'
                                        : 'SIN HISTORIAL',
                                style: TextStyle(
                                  color: printerStatus == _PrinterStatus.ok
                                      ? successText
                                      : printerStatus == _PrinterStatus.needsAttention
                                          ? warningText
                                          : Colors.white54,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _DetailCard(
                bgColor: cardBg,
                borderColor: cardBorder,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'DATOS DEL CLIENTE',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.business_center_rounded,
                          size: 16,
                          color: Color(0xFFA4B6CE),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.client,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFFA4B6CE)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _plantName ?? 'Planta desconocida',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.grid_view_rounded, size: 16, color: Color(0xFFA4B6CE)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _areaName ?? 'Area desconocida',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _DetailCard(
                bgColor: cardBg,
                borderColor: cardBorder,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'ULTIMO SERVICIO',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Icon(
                                    lastServiceVisual.icon,
                                    size: 18,
                                    color: lastServiceVisual.color,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Mantenimiento $lastServiceType',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                lastServiceDate,
                                style: const TextStyle(
                                  color: Color(0xFF8FA3BE),
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
                              'CONTADOR',
                              style: TextStyle(
                                color: textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$counter\nin',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: infoBlue,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                height: 1.05,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: cardBorder, height: 1),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        const CircleAvatar(
                          radius: 16,
                          backgroundColor: Color(0xFF2B3D56),
                          child: Icon(
                            Icons.engineering_rounded,
                            size: 18,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _technicianName ?? 'Sin registros',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Tecnico Certificado',
                                style: TextStyle(
                                  color: textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            if (_lastService != null) {
                              context.pushNamed(
                                AppRoutes.reportView,
                                extra: ReportViewArgs(reportId: _lastService!.id),
                              );
                            } else {
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Esta impresora no tiene reportes aún'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          child: const Text(
                            'VER REPORTE',
                            style: TextStyle(
                              color: infoBlue,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: screenBg,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.pushNamed(
                      AppRoutes.capture,
                      extra: CaptureArgs(printerId: widget.printerId),
                    ),
                    icon: const Icon(Icons.playlist_add_check_circle_rounded),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    label: const Text(
                      'Crear reporte de servicio',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: FilledButton.tonalIcon(
                          onPressed: () => _showQrDialog(context, widget.serialNumber, widget.model),
                          icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF242E3D),
                            foregroundColor: Colors.white,
                          ),
                          label: const Text('Mostrar QR'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: FilledButton.tonalIcon(
                          onPressed: () => context.pushNamed(
                            AppRoutes.serviceHistory,
                            pathParameters: <String, String>{
                              'serialNumber': widget.serialNumber,
                            },
                            extra: ServiceHistoryArgs(
                              model: widget.model,
                              serialNumber: widget.serialNumber,
                              printerId: widget.printerId,
                            ),
                          ),
                          icon: const Icon(Icons.history_rounded, size: 18),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF242E3D),
                            foregroundColor: Colors.white,
                          ),
                          label: const Text('Ver Historial'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final List<String> monthNames = <String>[
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${date.day.toString().padLeft(2, '0')} de ${monthNames[date.month - 1]}, ${date.year}';
  }

  static void _showQrDialog(
    BuildContext context,
    String serialNumber,
    String model,
  ) {
    final String qrData = '$serialNumber|$model';
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF101826),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF243245)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Código QR de Impresora',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF152133),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF243245)),
                  ),
                  child: Column(
                    children: <Widget>[
                      const Text(
                        'FORMATO DEL QR',
                        style: TextStyle(
                          color: Color(0xFF8BA0BC),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        qrData,
                        style: const TextStyle(
                          color: Color(0xFF2A8BFF),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF242E3D),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Cerrar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  _ServiceTypeVisual _serviceTypeVisual(String serviceType) {
    switch (serviceType) {
      case 'Preventivo':
        return const _ServiceTypeVisual(
          icon: Icons.check_circle_rounded,
          color: AppPalette.success,
        );
      case 'Correctivo':
        return const _ServiceTypeVisual(
          icon: Icons.build_rounded,
          color: Color(0xFFE57373),
        );
      case 'Diagnostico':
        return const _ServiceTypeVisual(
          icon: Icons.troubleshoot_rounded,
          color: AppPalette.warning,
        );
      case 'Instalacion':
        return const _ServiceTypeVisual(
          icon: Icons.settings_input_component_rounded,
          color: Color(0xFF8EC5FF),
        );
      default:
        return const _ServiceTypeVisual(
          icon: Icons.miscellaneous_services_rounded,
          color: Colors.white70,
        );
    }
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.bgColor,
    required this.borderColor,
    required this.child,
  });

  final Color bgColor;
  final Color borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class _ServiceTypeVisual {
  const _ServiceTypeVisual({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;
}
