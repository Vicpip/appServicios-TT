import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:drift/drift.dart' show Expression, Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:industrial_service_reports/core/constants.dart';
import 'package:industrial_service_reports/core/router/app_routes.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/core/utils/date_utils.dart'
    show formatLocalCDMX;
import 'package:industrial_service_reports/core/router/route_args.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/data/local/local_database.dart';
import 'package:industrial_service_reports/features/auth/services/auth_service.dart';
import 'package:industrial_service_reports/features/reports/providers/group_signature_provider.dart';
import 'package:industrial_service_reports/features/reports/services/pdf_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';
import 'package:uuid/uuid.dart';

class GroupSignatureScreen extends ConsumerStatefulWidget {
  const GroupSignatureScreen({super.key, required this.args});

  final GroupSignatureArgs args;

  @override
  ConsumerState<GroupSignatureScreen> createState() =>
      _GroupSignatureScreenState();
}

class _GroupSignatureScreenState extends ConsumerState<GroupSignatureScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();
  late final SignatureController _signatureController;
  bool _isSaving = false;
  bool _signatureEmpty = true;

  List<Report> _groupReports = <Report>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black87,
      exportBackgroundColor: Colors.white,
    );
    _signatureController.addListener(() {
      setState(() => _signatureEmpty = _signatureController.isEmpty);
    });
    _loadGroupReports();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupReports() async {
    final List<Report> reports = await (localDatabase.select(localDatabase.reports)
          ..where((Reports r) => Expression.and(<Expression<bool>>[
                r.signatureBlockId.equals(widget.args.signatureBlockId),
                r.reportBlockStatus.equals('open'),
              ])))
        .get();
    if (mounted) {
      setState(() {
        _groupReports = reports;
        _loading = false;
      });
    }
  }

  Future<String?> _saveSignature() async {
    final Uint8List? pngBytes = await _signatureController.toPngBytes();
    if (pngBytes == null) return null;
    final io.Directory appDir = await getApplicationDocumentsDirectory();
    final String dir = '${appDir.path}/reports/signatures';
    await io.Directory(dir).create(recursive: true);
    final String path = '$dir/group_${const Uuid().v4()}_sig.png';
    await io.File(path).writeAsBytes(pngBytes);
    return path;
  }

  Future<void> _onConfirm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: const Text('Se requiere la firma del cliente'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final String? sigPath = await _saveSignature();
      final String signerName = _nameController.text.trim();
      final String signerRole = _roleController.text.trim();

      // 1. Update all group reports to Signed + closed
      for (final Report r in _groupReports) {
        await (localDatabase.update(localDatabase.reports)
              ..where((Reports row) => row.id.equals(r.id)))
            .write(ReportsCompanion(
          status: const Value<String>('Signed'),
          reportBlockStatus: const Value<String>('closed'),
          signatureName: Value<String?>(signerName),
          signatureRole: Value<String?>(signerRole),
          signatureImagePath: Value<String?>(sigPath),
        ));
      }

      // 2. Enqueue each report for sync + its files
      final io.Directory pdfsDir = io.Directory(
        '${(await getApplicationDocumentsDirectory()).path}/reports/pdfs',
      );
      await pdfsDir.create(recursive: true);

      for (final Report r in _groupReports) {
        // Enqueue report JSON
        final Report updated = await (localDatabase.select(localDatabase.reports)
              ..where((Reports row) => row.id.equals(r.id)))
            .getSingle();

        await localDatabase.into(localDatabase.syncQueue).insert(
              SyncQueueCompanion.insert(
                id: const Uuid().v4(),
                methodHttp: 'POST',
                endpointDestino: '/api/reports',
                payloadJson: jsonEncode(<String, dynamic>{
                  'id': updated.id,
                  'printerId': updated.printerId,
                  'techId': updated.techId,
                  'serviceType': updated.serviceType,
                  'status': 'Signed',
                  'serviceDate': updated.serviceDate.toIso8601String(),
                  'linearInchesCounter': updated.linearInchesCounter,
                  'darknessLevel': updated.darknessLevel,
                  'technicalCheckboxes': updated.technicalCheckboxes,
                  'notes': updated.notes,
                  'signatureName': signerName,
                  'signatureRole': signerRole,
                  'signatureBlockId': widget.args.signatureBlockId,
                  'reportBlockStatus': 'closed',
                  'photoPaths': jsonDecode(updated.photoPaths),
                  'signatureImagePath': sigPath,
                  'photoCount': updated.photoCount,
                  'code': updated.code,
                }),
                entityType: 'report',
                entityId: updated.id,
              ),
            );

        // Enqueue photos
        try {
          final List<dynamic> photos =
              jsonDecode(updated.photoPaths) as List<dynamic>;
          for (final dynamic ph in photos) {
            final String photoPath = ph as String;
            await localDatabase.into(localDatabase.syncQueue).insert(
                  SyncQueueCompanion.insert(
                    id: const Uuid().v4(),
                    methodHttp: 'POST',
                    endpointDestino: '/api/files',
                    payloadJson: jsonEncode(<String, dynamic>{
                      'localPath': photoPath,
                      'fileCategory': 'photo',
                    }),
                    entityType: 'file',
                    entityId: updated.id,
                  ),
                );
          }
        } catch (_) {}

        // Enqueue signature (linked to this report)
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
                  entityId: updated.id,
                ),
              );
        }

        // Generate + enqueue PDF
        try {
          final Uint8List pdfBytes = await PdfService.generateReportPdf(
            reportId: updated.id,
            database: localDatabase,
          );
          final User? tech = await (localDatabase.select(localDatabase.users)
                ..where((Users u) => u.id.equals(updated.techId)))
              .getSingleOrNull();
          final String pdfPath =
              '${pdfsDir.path}/${PdfService.reportPdfName(updated, tech)}';
          await io.File(pdfPath).writeAsBytes(pdfBytes);

          await localDatabase.into(localDatabase.syncQueue).insert(
                SyncQueueCompanion.insert(
                  id: const Uuid().v4(),
                  methodHttp: 'POST',
                  endpointDestino: '/api/files',
                  payloadJson: jsonEncode(<String, dynamic>{
                    'localPath': pdfPath,
                    'fileCategory': 'pdf',
                  }),
                  entityType: 'pdf',
                  entityId: updated.id,
                ),
              );
        } catch (e) {
          debugPrint('[GroupSignature] PDF no fatal: $e');
        }
      }

      if (!mounted) return;

      // Invalidate so banners update
      ref.invalidate(pendingGroupProvider);

      // Enviar cada reporte del grupo por email a los contactos del cliente
      // (no bloqueante)
      await _sendGroupReportEmails();

      if (!mounted) return;

      context.go(
        '/policy-delivery-success',
        extra: <String, dynamic>{
          'count': _groupReports.length,
          'isDelivery': false,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Envía por email cada reporte del grupo a los contactos del cliente.
  /// No bloqueante: cualquier error solo muestra un SnackBar naranja.
  Future<void> _sendGroupReportEmails() async {
    try {
      if (_groupReports.isEmpty) return;

      final Printer? printer = await (localDatabase.select(localDatabase.printers)
            ..where((Printers t) =>
                t.id.equals(_groupReports.first.printerId)))
          .getSingleOrNull();
      if (printer == null) return;

      final String? authToken = await AuthService().getToken();
      final http.Response contactsResponse = await http.get(
        Uri.parse(
            '$kServerBaseUrlDevice/api/admin/clients/${printer.clientId}/contact-emails'),
        headers: <String, String>{
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
      );
      if (contactsResponse.statusCode != 200) {
        throw Exception('HTTP ${contactsResponse.statusCode}');
      }

      final List<dynamic> contacts =
          jsonDecode(contactsResponse.body) as List<dynamic>;

      if (contacts.isNotEmpty) {
        for (final Report r in _groupReports) {
          await _postSendEmail(r.id, null, authToken);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppPalette.success,
            content: Text(
              'Reporte(s) enviado(s) por email a ${contacts.length} contacto${contacts.length == 1 ? '' : 's'}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (!mounted) return;
      await _promptExtraEmailAndSendGroup(authToken);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('No se pudo enviar el email'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _postSendEmail(
    String reportId,
    String? extraEmail,
    String? authToken,
  ) async {
    final http.Response response = await http.post(
      Uri.parse('$kServerBaseUrlDevice/api/reports/$reportId/send-email'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(<String, dynamic>{'extra_email': extraEmail}),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  Future<void> _promptExtraEmailAndSendGroup(String? authToken) async {
    final TextEditingController emailController = TextEditingController();
    final GlobalKey<FormState> dialogFormKey = GlobalKey<FormState>();

    final bool? shouldSend = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Sin correos registrados'),
          content: Form(
            key: dialogFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'El cliente no tiene correos de contacto. Ingresa un correo para enviar el reporte:',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      const InputDecoration(labelText: 'Correo electrónico'),
                  validator: (String? value) {
                    final String v = (value ?? '').trim();
                    if (v.isEmpty) return 'Campo obligatorio';
                    final RegExp emailRegex =
                        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    if (!emailRegex.hasMatch(v)) return 'Correo inválido';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Omitir'),
            ),
            FilledButton(
              onPressed: () {
                if (dialogFormKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );

    if (shouldSend != true) return;

    final String extraEmail = emailController.text.trim();
    for (final Report r in _groupReports) {
      await _postSendEmail(r.id, extraEmail, authToken);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppPalette.success,
        content: Text('Reporte(s) enviado(s) por email'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Firma grupal — ${widget.args.clientName}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      children: <Widget>[
                        // List of reports in the group
                        _SectionCard(
                          title:
                              'Reportes en este grupo (${_groupReports.length})',
                          child: _groupReports.isEmpty
                              ? const Text(
                                  'No hay reportes en este grupo.',
                                  style: TextStyle(color: Colors.white70),
                                )
                              : Column(
                                  children: _groupReports
                                      .map((Report r) => _ReportRow(
                                            report: r,
                                            onView: () => context.pushNamed(
                                              AppRoutes.reportView,
                                              extra: ReportViewArgs(
                                                  reportId: r.id),
                                            ),
                                          ))
                                      .toList(),
                                ),
                        ),
                        const SizedBox(height: 16),
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
                                    backgroundColor:
                                        const Color(0xFFF3F4F6),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (_signatureEmpty)
                                const Text(
                                  'Dibuje la firma en el área de arriba',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  onPressed: _signatureController.clear,
                                  icon: const Icon(
                                      Icons.cleaning_services_rounded,
                                      size: 18),
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
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Requerido'
                                        : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _roleController,
                                decoration: const InputDecoration(
                                    labelText: 'Cargo / Puesto'),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
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
              onPressed:
                  (_isSaving || _groupReports.isEmpty) ? null : _onConfirm,
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
                        color: AppPalette.backgroundLight,
                      ),
                    )
                  : Text(
                      'Firmar grupo (${_groupReports.length} reporte${_groupReports.length == 1 ? '' : 's'})',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.report, required this.onView});

  final Report report;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.backgroundDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppPalette.surfaceDarkHighlight),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  report.code ?? report.id.substring(0, 8),
                  style: const TextStyle(
                    color: AppPalette.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${report.serviceType}  •  ${formatLocalCDMX(report.serviceDate)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.visibility_outlined,
                color: Colors.white54, size: 20),
            onPressed: onView,
            tooltip: 'Ver reporte',
          ),
        ],
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
