import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:industrial_service_reports/features/reports/services/pdf_service.dart';

import 'package:drift/drift.dart' show Expression, Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:industrial_service_reports/core/router/app_routes.dart';
import 'package:industrial_service_reports/core/router/route_args.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/data/local/local_database.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';
import 'package:uuid/uuid.dart';

class PolicyDeliverySignatureScreen extends ConsumerStatefulWidget {
  const PolicyDeliverySignatureScreen({super.key, required this.args});

  final PolicyDeliverySignatureArgs args;

  @override
  ConsumerState<PolicyDeliverySignatureScreen> createState() =>
      _PolicyDeliverySignatureScreenState();
}

class _PolicyDeliverySignatureScreenState
    extends ConsumerState<PolicyDeliverySignatureScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();
  late final SignatureController _signatureController;
  bool _isSaving = false;
  bool _signatureEmpty = true;

  @override
  void initState() {
    super.initState();
    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black87,
      exportBackgroundColor: Colors.white,
    );
    _signatureController.addListener(() {
      setState(() {
        _signatureEmpty = _signatureController.isEmpty;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<String?> _saveSignature() async {
    final Uint8List? pngBytes = await _signatureController.toPngBytes();
    if (pngBytes == null) return null;
    final io.Directory appDir = await getApplicationDocumentsDirectory();
    final String deliveriesDir = '${appDir.path}/deliveries';
    await io.Directory(deliveriesDir).create(recursive: true);
    final String sigPath =
        '$deliveriesDir/${const Uuid().v4()}_sig.png';
    await io.File(sigPath).writeAsBytes(pngBytes);
    return sigPath;
  }

  Future<void> _onConfirm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: const Text('Se requiere la firma del cliente'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final String? sigPath = await _saveSignature();
      final String deliveryId = const Uuid().v4();
      final DateTime now = DateTime.now();

      // Create PolicyDelivery in local DB
      await localDatabase.into(localDatabase.policyDeliveries).insert(
            PolicyDeliveriesCompanion.insert(
              id: deliveryId,
              policyId: widget.args.policyId,
              deliveryDate: now,
              signatureName: _nameController.text.trim(),
              signatureRole: _roleController.text.trim(),
              techId: widget.args.techId,
              signatureImagePath: Value(sigPath),
            ),
          );

      // Create PolicyDeliveryReport rows + mark reports as 'signed'
      for (final String reportId in widget.args.reportIds) {
        await localDatabase.into(localDatabase.policyDeliveryReports).insert(
              PolicyDeliveryReportsCompanion.insert(
                id: const Uuid().v4(),
                deliveryId: deliveryId,
                reportId: reportId,
              ),
            );
        await (localDatabase.update(localDatabase.reports)
              ..where((Reports r) => r.id.equals(reportId)))
            .write(const ReportsCompanion(status: Value('signed')));
      }

      // Auto-completar visita si ya no quedan reportes pending_delivery en la póliza
      try {
        final List<PolicyPrinter> allPolicyPrinters =
            await (localDatabase.select(localDatabase.policyPrinters)
                  ..where((PolicyPrinters pp) =>
                      pp.policyId.equals(widget.args.policyId)))
                .get();
        bool anyPending = false;
        for (final PolicyPrinter pp in allPolicyPrinters) {
          final int count = await (localDatabase.select(localDatabase.reports)
                ..where((Reports r) => Expression.and(<Expression<bool>>[
                      r.printerId.equals(pp.printerId),
                      r.status.equals('pending_delivery'),
                    ])))
              .get()
              .then((List<Report> l) => l.length);
          if (count > 0) {
            anyPending = true;
            break;
          }
        }
        if (!anyPending && allPolicyPrinters.isNotEmpty && widget.args.reportIds.isNotEmpty) {
          final List<PolicyVisit> activeVisits =
              await (localDatabase.select(localDatabase.policyVisits)
                    ..where((PolicyVisits v) => Expression.and(<Expression<bool>>[
                          v.policyId.equals(widget.args.policyId),
                          v.status.equals('in_progress'),
                        ]))
                    ..limit(1))
                  .get();
          if (activeVisits.isNotEmpty) {
            await (localDatabase.update(localDatabase.policyVisits)
                  ..where((PolicyVisits v) =>
                      v.id.equals(activeVisits.first.id)))
                .write(PolicyVisitsCompanion(
              status: const Value<String>('completed'),
              completedAt: Value<DateTime>(DateTime.now()),
            ));
            debugPrint(
                '[PolicyDeliverySignature] Visita auto-completada: ${activeVisits.first.id}');
          }
        }
      } catch (e) {
        debugPrint(
            '[PolicyDeliverySignature] Auto-completar visita (no fatal): $e');
      }

      // Enqueue sync
      await localDatabase.into(localDatabase.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: const Uuid().v4(),
              methodHttp: 'POST',
              endpointDestino: '/api/policy-deliveries',
              payloadJson: jsonEncode(<String, dynamic>{
                'policy_id': widget.args.policyId,
                'delivery_date': now.toIso8601String(),
                'signature_name': _nameController.text.trim(),
                'signature_role': _roleController.text.trim(),
                'tech_id': widget.args.techId,
                'report_ids': widget.args.reportIds,
                'signature_image_path': sigPath,
              }),
              entityType: 'policy_delivery',
              entityId: deliveryId,
            ),
          );

      // CAMBIO 4: Generar PDF de resumen global (no fatal)
      try {
        final Policy? policy = await (localDatabase.select(localDatabase.policies)
              ..where((Policies p) => p.id.equals(widget.args.policyId)))
            .getSingleOrNull();
        if (policy != null) {
          final PolicyDelivery? delivery = await (localDatabase
                  .select(localDatabase.policyDeliveries)
                ..where((PolicyDeliveries d) => d.id.equals(deliveryId)))
              .getSingleOrNull();
          if (delivery != null) {
            final List<Report> reports = await (localDatabase
                    .select(localDatabase.reports)
                  ..where((Reports r) => r.id.isIn(widget.args.reportIds)))
                .get();
            final Uint8List pdfBytes = await PdfService.generateDeliveryPdf(
              delivery: delivery,
              reports: reports,
              policy: policy,
              database: localDatabase,
            );
            final io.Directory appDir = await getApplicationDocumentsDirectory();
            final String deliveriesDir = '${appDir.path}/deliveries';
            await io.Directory(deliveriesDir).create(recursive: true);
            final String summaryPath =
                '$deliveriesDir/delivery_${deliveryId}_resumen.pdf';
            await io.File(summaryPath).writeAsBytes(pdfBytes);
            debugPrint(
                '[PolicyDeliverySignature] PDF resumen guardado: $summaryPath');
          }
        }
      } catch (e) {
        debugPrint(
            '[PolicyDeliverySignature] PDF resumen falló (no fatal): $e');
      }

      // Generar PDFs individuales de cada reporte (P6b) y encolar para sync (P6c)
      final io.Directory reportPdfsDir = io.Directory(
        '${(await getApplicationDocumentsDirectory()).path}/reports/pdfs',
      );
      await reportPdfsDir.create(recursive: true);

      for (final String reportId in widget.args.reportIds) {
        try {
          final Uint8List reportPdfBytes = await PdfService.generateReportPdf(
            reportId: reportId,
            database: localDatabase,
          );
          final String reportPdfPath = '${reportPdfsDir.path}/report_$reportId.pdf';
          await io.File(reportPdfPath).writeAsBytes(reportPdfBytes);
          debugPrint('[PolicyDeliverySignature] PDF individual guardado: $reportPdfPath');
          await localDatabase.into(localDatabase.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: const Uuid().v4(),
              methodHttp: 'POST',
              endpointDestino: '/api/files',
              payloadJson: jsonEncode(<String, dynamic>{
                'localPath': reportPdfPath,
                'fileCategory': 'pdf',
              }),
              entityType: 'pdf',
              entityId: reportId,
            ),
          );
        } catch (e) {
          debugPrint(
              '[PolicyDeliverySignature] PDF individual reportId=$reportId falló (no fatal): $e');
        }
      }

      // Encolar firma de entrega para sync (P6c)
      if (sigPath != null) {
        await localDatabase.into(localDatabase.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: const Uuid().v4(),
            methodHttp: 'POST',
            endpointDestino: '/api/files',
            payloadJson: jsonEncode(<String, dynamic>{
              'localPath': sigPath,
              'fileCategory': 'signature',
            }),
            entityType: 'signature',
            entityId: deliveryId,
          ),
        );
        debugPrint('[PolicyDeliverySignature] Firma encolada para sync: $sigPath');
      }

      if (!mounted) return;
      context.pushReplacementNamed(
        AppRoutes.policyDeliverySuccess,
        extra: <String, dynamic>{
          'count': widget.args.reportIds.length,
          'isDelivery': true,
          'deliveryId': deliveryId,
          'policyFolio': widget.args.policyFolio,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text('Error: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Firma — ${widget.args.policyFolio}'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: <Widget>[
                  // Signature canvas
                  _SectionCard(
                    title: 'Firma del Cliente',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Container(
                          height: 240,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _signatureEmpty
                                  ? const Color(0xFFCFD3DA)
                                  : AppPalette.primary,
                              width: _signatureEmpty ? 1.0 : 1.5,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Signature(
                              controller: _signatureController,
                              backgroundColor: const Color(0xFFF3F4F6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (_signatureEmpty)
                          const Text(
                            'Dibuje la firma en el área de arriba',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _signatureController.clear,
                            icon: const Icon(
                                Icons.cleaning_services_rounded, size: 18),
                            label: const Text('Limpiar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Signer data
                  _SectionCard(
                    title: 'Datos del Firmante',
                    child: Column(
                      children: <Widget>[
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                              labelText: 'Nombre completo'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Requerido'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _roleController,
                          decoration: const InputDecoration(
                              labelText: 'Cargo / Puesto'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Requerido'
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: const BoxDecoration(
            color: AppPalette.surfaceDark,
            border:
                Border(top: BorderSide(color: AppPalette.surfaceDarkHighlight)),
          ),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _isSaving ? null : _onConfirm,
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.success,
                foregroundColor: AppPalette.backgroundLight,
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppPalette.backgroundLight),
                    )
                  : const Text(
                      'Confirmar Entrega',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.surfaceDarkHighlight),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: AppPalette.backgroundLight,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
