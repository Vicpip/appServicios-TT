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

  // Sección de email (Tarea 2): solo se muestra si el GET de contact-emails
  // llegó a completarse (con o sin conectividad al cargar la pantalla).
  bool _emailSectionLoaded = false;
  List<String> _contactEmails = <String>[];
  bool _showExtraEmailField = false;
  final TextEditingController _extraEmailController = TextEditingController();
  final GlobalKey<FormState> _extraEmailFormKey = GlobalKey<FormState>();

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
    _loadGroupReports().then((_) => _loadContactEmails());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _signatureController.dispose();
    _extraEmailController.dispose();
    super.dispose();
  }

  /// Carga los correos de contacto del cliente (usando el clientId del
  /// primer reporte del grupo) para mostrarlos en la sección informativa
  /// antes del botón de firma. Si no hay conectividad, se omite en silencio.
  Future<void> _loadContactEmails() async {
    try {
      if (_groupReports.isEmpty) return;
      final String printerId = _groupReports.first.printerId;
      final Printer? printer = await (localDatabase.select(localDatabase.printers)
            ..where((Printers t) => t.id.equals(printerId)))
          .getSingleOrNull();
      if (printer == null) return;

      final String? authToken = await AuthService().getToken();
      final http.Response response = await http
          .get(
            Uri.parse(
                '$kServerBaseUrlDevice/api/admin/clients/${printer.clientId}/contact-emails'),
            headers: <String, String>{
              if (authToken != null) 'Authorization': 'Bearer $authToken',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;

      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      final List<String> emails = data
          .map((dynamic e) => (e as Map<String, dynamic>)['email'] as String)
          .toList();

      if (!mounted) return;
      setState(() {
        _contactEmails = emails;
        _emailSectionLoaded = true;
      });
    } catch (_) {
      // Sin conectividad u otro error: se omite la sección silenciosamente.
    }
  }

  /// Email adicional válido capturado en la sección de correo, o null si
  /// está vacío o no tiene formato de email.
  String? get _pendingEmailValue {
    final String value = _extraEmailController.text.trim();
    if (value.isEmpty) return null;
    final RegExp emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(value) ? value : null;
  }

  Widget _buildEmailSection() {
    final bool hasContacts = _contactEmails.isNotEmpty;
    return _SectionCard(
      title: 'Envío por correo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                hasContacts ? Icons.check_circle : Icons.warning_amber_rounded,
                color: hasContacts ? AppPalette.success : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasContacts
                      ? 'Se enviará a: ${_contactEmails.join(', ')}'
                      : 'Sin correos registrados',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
          if (hasContacts && !_showExtraEmailField) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _showExtraEmailField = true),
                child: const Text('Agregar otro'),
              ),
            ),
          ],
          if (!hasContacts || _showExtraEmailField) ...<Widget>[
            const SizedBox(height: 10),
            Form(
              key: _extraEmailFormKey,
              child: TextFormField(
                controller: _extraEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo adicional',
                  isDense: true,
                ),
                validator: (String? v) {
                  final String value = (v ?? '').trim();
                  if (value.isEmpty) return null;
                  final RegExp emailRegex =
                      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                  if (!emailRegex.hasMatch(value)) return 'Correo inválido';
                  return null;
                },
              ),
            ),
          ],
        ],
      ),
    );
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
      final String? pendingEmail = _pendingEmailValue;

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
          pendingEmail: Value<String?>(pendingEmail),
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
                        if (_emailSectionLoaded) ...<Widget>[
                          const SizedBox(height: 16),
                          _buildEmailSection(),
                        ],
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
