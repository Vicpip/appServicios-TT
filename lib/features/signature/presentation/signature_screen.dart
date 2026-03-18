import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/data/local/local_database.dart';
import 'package:industrial_service_reports/features/auth/providers/session_provider.dart';
import 'package:industrial_service_reports/features/reports/providers/capture_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';
import 'package:uuid/uuid.dart';

class SignatureScreen extends ConsumerStatefulWidget {
  const SignatureScreen({super.key});

  @override
  ConsumerState<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends ConsumerState<SignatureScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _signerNameController = TextEditingController();
  final TextEditingController _signerRoleController = TextEditingController();
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
    _signerNameController.dispose();
    _signerRoleController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firma de Conformidad'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                children: <Widget>[
                  _SignatureCard(
                    title: 'Firma del Cliente',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Container(
                          height: 270,
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
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _signatureController.clear();
                            },
                            icon: const Icon(
                              Icons.cleaning_services_rounded,
                              size: 18,
                            ),
                            label: const Text('Limpiar Firma'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SignatureCard(
                    title: 'Datos del Firmante',
                    child: Column(
                      children: <Widget>[
                        TextFormField(
                          controller: _signerNameController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre completo de quien firma',
                          ),
                          validator: _requiredValidator,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _signerRoleController,
                          decoration: const InputDecoration(
                            labelText: 'Cargo / Puesto',
                          ),
                          validator: _requiredValidator,
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
              onPressed: _isSaving ? null : _onFinishPressed,
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
                  : const Text(
                      'Finalizar y Guardar Reporte',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onFinishPressed() async {
    final bool formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) {
      final ThemeData theme = Theme.of(context);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: theme.colorScheme.error,
          content: Text(
            'Complete los campos obligatorios',
            style: TextStyle(color: theme.colorScheme.onError),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text(
            'Se requiere la firma del cliente',
            style:
                TextStyle(color: Theme.of(context).colorScheme.onError),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final CaptureState captureState = ref.read(captureProvider);
      final SessionState sessionState = ref.read(sessionProvider);

      final String? printerId = captureState.printerId;
      if (printerId == null || printerId.isEmpty) {
        throw Exception('No hay impresora asociada al reporte.');
      }

      // Obtener techId real; si no hay sesión activa, crear usuario por defecto
      String techId = sessionState.userId;
      if (techId.isEmpty) {
        const String defaultTechId = '00000000-0000-0000-0000-000000000001';
        final User? existingUser =
            await (localDatabase.select(localDatabase.users)
                  ..where((u) => u.id.equals(defaultTechId)))
                .getSingleOrNull();
        if (existingUser == null) {
          await localDatabase.into(localDatabase.users).insert(
                UsersCompanion.insert(
                  id: defaultTechId,
                  name: sessionState.userName.isEmpty
                      ? 'Técnico'
                      : sessionState.userName,
                  email: sessionState.email.isEmpty
                      ? 'tecnico@empresa.com'
                      : sessionState.email,
                  role: 'technician',
                ),
              );
        }
        techId = defaultTechId;
      }

      // Guardar firma como PNG en almacenamiento local
      final String? signatureImagePath = await _saveSignatureImage();

      // Buscar labelTypeId en catálogo
      final CatalogLabelType? labelTypeRow = await (localDatabase
              .select(localDatabase.catalogLabelTypes)
            ..where((t) => t.name.equals(captureState.selectedLabelType)))
          .getSingleOrNull();

      // Parsear valores numéricos
      final int counterValue =
          int.tryParse(captureState.counterValue.replaceAll(',', '')) ?? 0;
      final int? darknessValue = captureState.darknessValue.isNotEmpty
          ? int.tryParse(captureState.darknessValue)
          : null;

      // Serializar rutas de fotos como JSON
      final String photoPathsJson = jsonEncode(captureState.photoPaths);

      // Generar código legible para el reporte
      final int reportCount = await (localDatabase.select(localDatabase.reports))
          .get()
          .then((List<Report> l) => l.length);
      final String reportCode =
          'R-${(reportCount + 1).toString().padLeft(3, '0')}';

      // Insertar reporte en DB
      final String reportId = const Uuid().v4();
      await localDatabase.into(localDatabase.reports).insert(
            ReportsCompanion.insert(
              id: reportId,
              printerId: printerId,
              techId: techId,
              serviceType: captureState.selectedServiceType,
              status: 'Signed',
              serviceDate: DateTime.now(),
              linearInchesCounter: counterValue,
              technicalCheckboxes: captureState.checkValues,
              darknessLevel: Value(darknessValue),
              labelTypeId: Value(labelTypeRow?.id),
              notes:
                  Value(captureState.notes.isEmpty ? null : captureState.notes),
              signatureName: Value(_signerNameController.text.trim()),
              signatureRole: Value(_signerRoleController.text.trim()),
              photoPaths: Value(photoPathsJson),
              photoCount: Value(captureState.photoPaths.length),
              signatureImagePath: Value(signatureImagePath),
              code: Value(reportCode),
            ),
          );

      // Encolar para sincronización
      await localDatabase.into(localDatabase.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: const Uuid().v4(),
              methodHttp: 'POST',
              endpointDestino: '/api/reports',
              payloadJson: jsonEncode(<String, dynamic>{
                'id': reportId,
                'printerId': printerId,
                'techId': techId,
                'serviceType': captureState.selectedServiceType,
                'status': 'Signed',
                'serviceDate': DateTime.now().toIso8601String(),
                'linearInchesCounter': counterValue,
                'technicalCheckboxes': captureState.checkValues,
                'notes': captureState.notes,
                'signatureName': _signerNameController.text.trim(),
                'signatureRole': _signerRoleController.text.trim(),
                'photoPaths': captureState.photoPaths,
                'signatureImagePath': signatureImagePath,
                'photoCount': captureState.photoPaths.length,
                'code': reportCode,
              }),
              entityType: 'report',
              entityId: reportId,
            ),
          );

      // Encolar fotos
      for (final String photoPath in captureState.photoPaths) {
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
            entityId: reportId,
          ),
        );
      }

      // Encolar firma
      if (signatureImagePath != null) {
        await localDatabase.into(localDatabase.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: const Uuid().v4(),
            methodHttp: 'POST',
            endpointDestino: '/api/files',
            payloadJson: jsonEncode(<String, dynamic>{
              'localPath': signatureImagePath,
              'fileCategory': 'signature',
            }),
            entityType: 'signature',
            entityId: reportId,
          ),
        );
      }

      // Resetear estado de captura
      ref.read(captureProvider.notifier).resetCapture();

      if (!mounted) return;
      setState(() => _isSaving = false);

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Reporte Guardado'),
            content: const Text(
              'El reporte se guardó correctamente en la base local.',
            ),
            actions: <Widget>[
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  context.go('/dashboard');
                },
                child: const Text('Ir al Inicio'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text('Error al guardar: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Captura la firma del pad y la guarda como PNG
  Future<String?> _saveSignatureImage() async {
    try {
      final Uint8List? signatureBytes =
          await _signatureController.toPngBytes();
      if (signatureBytes == null) return null;

      final io.Directory appDir = await getApplicationDocumentsDirectory();
      final String signaturesDir =
          '${appDir.path}/reports/signatures';
      final io.Directory dir = io.Directory(signaturesDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final String signatureId = const Uuid().v4();
      final String filePath = '$signaturesDir/signature_$signatureId.png';
      final io.File file = io.File(filePath);
      await file.writeAsBytes(signatureBytes);

      return filePath;
    } catch (e) {
      return null;
    }
  }

  String? _requiredValidator(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Campo obligatorio';
    }
    return null;
  }
}

class _SignatureCard extends StatelessWidget {
  const _SignatureCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppPalette.surfaceDark,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppPalette.backgroundLight,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
