import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:industrial_service_reports/core/utils/date_utils.dart' show formatLocalCDMX;
import 'package:go_router/go_router.dart';
import 'package:industrial_service_reports/core/router/app_routes.dart';
import 'package:industrial_service_reports/core/router/route_args.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/data/local/local_database.dart';
import 'package:industrial_service_reports/features/reports/services/pdf_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart' as printing_pkg;
import 'package:uuid/uuid.dart';

class VisitSummaryScreen extends StatefulWidget {
  const VisitSummaryScreen({super.key, required this.args});

  final VisitSummaryArgs args;

  @override
  State<VisitSummaryScreen> createState() => _VisitSummaryScreenState();
}

class _VisitSummaryScreenState extends State<VisitSummaryScreen> {
  bool _loading = true;
  bool _isDownloadingDeliveryPdf = false;
  bool _isEnqueuingDeliveryPdf = false;
  PolicyDelivery? _delivery;
  List<_ReportRow> _rows = const <_ReportRow>[];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final AppDatabase db = localDatabase;

      final PolicyDelivery? delivery = await (db.select(db.policyDeliveries)
            ..where((PolicyDeliveries d) => d.id.equals(widget.args.deliveryId)))
          .getSingleOrNull();

      if (delivery == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final List<PolicyDeliveryReport> deliveryReports =
          await (db.select(db.policyDeliveryReports)
                ..where((PolicyDeliveryReports r) =>
                    r.deliveryId.equals(widget.args.deliveryId)))
              .get();

      final List<_ReportRow> rows = <_ReportRow>[];
      for (final PolicyDeliveryReport dr in deliveryReports) {
        final Report? report = await (db.select(db.reports)
              ..where((Reports r) => r.id.equals(dr.reportId)))
            .getSingleOrNull();
        if (report == null) continue;

        final Printer? printer = await (db.select(db.printers)
              ..where((Printers p) => p.id.equals(report.printerId)))
            .getSingleOrNull();

        final CatalogModel? model = printer == null
            ? null
            : await (db.select(db.catalogModels)
                  ..where((CatalogModels m) => m.id.equals(printer.modelId)))
                .getSingleOrNull();

        const List<String> _damageKeys = <String>[
          'Rodillo dañado',
          'Cabezal dañado',
          'Sensor ribbon dañado',
          'Sensor papel dañado',
          'Otros',
        ];
        final bool hasWarning = _damageKeys.any(
          (String k) => report.technicalCheckboxes[k] == true,
        );

        rows.add(_ReportRow(
          reportId: report.id,
          serial: printer?.serialNumber ?? report.printerId.substring(0, 8),
          model: model != null
              ? '${model.brand} ${model.modelName}'
              : 'Modelo desconocido',
          serviceType: report.serviceType,
          status: report.status,
          hasWarning: hasWarning,
        ));
      }

      if (mounted) {
        setState(() {
          _delivery = delivery;
          _rows = rows;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[VisitSummary] Error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Generate report PDF locally ─────────────────────────────────────────────

  Future<void> _fetchReportPdf(String reportId) async {
    try {
      final bytes = await PdfService.generateReportPdf(
        reportId: reportId,
        database: localDatabase,
      );
      if (!mounted) return;
      await printing_pkg.Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'reporte_$reportId',
      );
    } catch (e) {
      if (!mounted) return;
      final String message = e.toString().contains('no encontrado')
          ? 'Reporte no encontrado'
          : 'Error al generar PDF';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  // ── Generate delivery PDF locally ────────────────────────────────────────────

  Future<void> _fetchDeliveryPdf() async {
    setState(() => _isDownloadingDeliveryPdf = true);
    try {
      final AppDatabase db = localDatabase;
      final PolicyDelivery delivery = _delivery!;

      final Policy? policy = await (db.select(db.policies)
            ..where((Policies p) => p.id.equals(delivery.policyId)))
          .getSingleOrNull();

      if (policy == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Datos no disponibles')),
          );
        }
        return;
      }

      final List<PolicyDeliveryReport> deliveryReports =
          await (db.select(db.policyDeliveryReports)
                ..where((PolicyDeliveryReports r) =>
                    r.deliveryId.equals(widget.args.deliveryId)))
              .get();

      final List<Report> reports = <Report>[];
      for (final PolicyDeliveryReport dr in deliveryReports) {
        final Report? report = await (db.select(db.reports)
              ..where((Reports r) => r.id.equals(dr.reportId)))
            .getSingleOrNull();
        if (report != null) reports.add(report);
      }

      final bytes = await PdfService.generateDeliveryPdf(
        delivery: delivery,
        reports: reports,
        policy: policy,
        database: db,
      );

      if (!mounted) return;

      await printing_pkg.Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'entrega_${widget.args.policyFolio}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al generar PDF')),
      );
    } finally {
      if (mounted) setState(() => _isDownloadingDeliveryPdf = false);
    }
  }

  // ── Encolar PDF de entrega para sync ────────────────────────────────────────

  Future<void> _enqueueDeliveryPdf() async {
    setState(() => _isEnqueuingDeliveryPdf = true);
    try {
      final AppDatabase db = localDatabase;
      final User? technician = await (db.select(db.users)
            ..where((Users u) => u.id.equals(_delivery!.techId)))
          .getSingleOrNull();
      final String fileName =
          PdfService.deliveryPdfName(widget.args.policyFolio, technician);
      final io.Directory dir = await getApplicationDocumentsDirectory();
      final String summaryPath = '${dir.path}/deliveries/$fileName';
      if (!io.File(summaryPath).existsSync()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF no encontrado en el dispositivo')),
        );
        return;
      }
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: const Uuid().v4(),
          methodHttp: 'POST',
          endpointDestino: '/api/files',
          payloadJson: jsonEncode(<String, dynamic>{
            'localPath': summaryPath,
            'fileCategory': 'delivery_pdf',
          }),
          entityType: 'delivery_pdf',
          entityId: _delivery!.id,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('PDF encolado — sincroniza para subirlo')),
      );
    } catch (e) {
      debugPrint('[VisitSummary] _enqueueDeliveryPdf error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isEnqueuingDeliveryPdf = false);
    }
  }

  String _formatDate(DateTime date) => formatLocalCDMX(date);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            const Icon(Icons.summarize_rounded, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Resumen — ${widget.args.policyFolio}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _delivery == null
              ? const Center(
                  child: Text(
                    'No se encontró la entrega',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _buildHeaderCard(),
                          const SizedBox(height: 16),
                          _buildProgressCard(),
                          const SizedBox(height: 16),
                          _buildReportsList(),
                          const SizedBox(height: 16),
                          _buildPdfButton(),
                          const SizedBox(height: 8),
                          _buildEnqueuePdfButton(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeaderCard() {
    final PolicyDelivery d = _delivery!;
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.surfaceDarkHighlight),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.assignment_rounded,
                  color: AppPalette.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.args.policyFolio,
                  style: const TextStyle(
                    color: AppPalette.backgroundLight,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppPalette.successDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppPalette.success),
                ),
                child: const Text(
                  'ENTREGADA',
                  style: TextStyle(
                    color: AppPalette.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _HeaderRow(
            icon: Icons.calendar_today_rounded,
            label: 'Fecha de entrega',
            value: _formatDate(d.deliveryDate),
          ),
          const SizedBox(height: 6),
          _HeaderRow(
            icon: Icons.person_rounded,
            label: 'Firmó',
            value: '${d.signatureName} (${d.signatureRole})',
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    final int total = _rows.length;
    final int signed =
        _rows.where((r) => r.status == 'signed' || r.status == 'Signed').length;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C2E4A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.primary),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: <Widget>[
          const Icon(Icons.check_circle_rounded,
              color: AppPalette.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$signed de $total equipos atendidos',
              style: const TextStyle(
                color: AppPalette.backgroundLight,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 80,
              child: LinearProgressIndicator(
                value: total > 0 ? signed / total : 0,
                minHeight: 8,
                backgroundColor: AppPalette.surfaceDarkHighlight,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppPalette.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Equipos en esta entrega',
          style: TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        ..._rows.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ReportCard(
                row: r,
                onViewReport: () => context.pushNamed(
                  AppRoutes.reportView,
                  extra: ReportViewArgs(reportId: r.reportId),
                ),
                onViewPdf: () => _fetchReportPdf(r.reportId),
              ),
            )),
      ],
    );
  }

  Widget _buildPdfButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: _isDownloadingDeliveryPdf ? null : _fetchDeliveryPdf,
        icon: _isDownloadingDeliveryPdf
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.picture_as_pdf_rounded, size: 20),
        label: const Text(
          'Ver / Compartir PDF de resumen',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.primary,
          foregroundColor: AppPalette.backgroundLight,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildEnqueuePdfButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed:
            _isEnqueuingDeliveryPdf ? null : _enqueueDeliveryPdf,
        icon: _isEnqueuingDeliveryPdf
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.upload_rounded, size: 18),
        label: const Text(
          'Subir PDF de entrega',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.primary,
          side: const BorderSide(color: AppPalette.primary),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ─── Data model ──────────────────────────────────────────────────────────────

class _ReportRow {
  const _ReportRow({
    required this.reportId,
    required this.serial,
    required this.model,
    required this.serviceType,
    required this.status,
    required this.hasWarning,
  });

  final String reportId;
  final String serial;
  final String model;
  final String serviceType;
  final String status;
  final bool hasWarning;
}

// ─── Subwidgets ───────────────────────────────────────────────────────────────

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 16, color: Colors.white54),
        const SizedBox(width: 8),
        Flexible(
          child: RichText(
            text: TextSpan(
              children: <TextSpan>[
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                      color: AppPalette.backgroundLight,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportCard extends StatefulWidget {
  const _ReportCard({
    required this.row,
    required this.onViewReport,
    required this.onViewPdf,
  });

  final _ReportRow row;
  final VoidCallback onViewReport;
  final Future<void> Function() onViewPdf;

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  bool _isPdfLoading = false;

  Future<void> _handleViewPdf() async {
    setState(() => _isPdfLoading = true);
    try {
      await widget.onViewPdf();
    } finally {
      if (mounted) setState(() => _isPdfLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSigned =
        widget.row.status == 'signed' || widget.row.status == 'Signed';

    return Container(
      decoration: BoxDecoration(
        color: widget.row.hasWarning
            ? const Color(0xFF2A2500)
            : AppPalette.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.row.hasWarning
              ? AppPalette.warning
              : AppPalette.surfaceDarkHighlight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.row.model,
                      style: const TextStyle(
                        color: AppPalette.backgroundLight,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'S/N: ${widget.row.serial}',
                      style: const TextStyle(
                        color: AppPalette.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSigned
                      ? const Color(0xFF0D1F3C)
                      : AppPalette.warningDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSigned ? AppPalette.primary : AppPalette.warning,
                  ),
                ),
                child: Text(
                  isSigned ? 'Firmado' : 'Pendiente',
                  style: TextStyle(
                    color: isSigned ? AppPalette.primary : AppPalette.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              const Icon(Icons.build_rounded, size: 14, color: Colors.white54),
              const SizedBox(width: 6),
              Text(
                widget.row.serviceType,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              if (widget.row.hasWarning) ...<Widget>[
                const SizedBox(width: 10),
                const Icon(Icons.warning_amber_rounded,
                    size: 14, color: AppPalette.warning),
                const SizedBox(width: 4),
                const Text(
                  'Con advertencias',
                  style: TextStyle(
                      color: AppPalette.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              // Ver PDF — fetches fresh from server
              SizedBox(
                height: 32,
                child: TextButton.icon(
                  onPressed: _isPdfLoading ? null : _handleViewPdf,
                  icon: _isPdfLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined, size: 15),
                  label: const Text('Ver PDF'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppPalette.primary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Ver reporte — navigates to detail screen
              SizedBox(
                height: 32,
                child: OutlinedButton.icon(
                  onPressed: widget.onViewReport,
                  icon: const Icon(Icons.visibility_outlined, size: 15),
                  label: const Text('Ver reporte'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppPalette.backgroundLight,
                    side: const BorderSide(
                        color: AppPalette.surfaceDarkHighlight),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
