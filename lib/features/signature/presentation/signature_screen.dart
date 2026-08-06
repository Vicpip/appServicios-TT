import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:drift/drift.dart' show Expression, Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:industrial_service_reports/core/constants.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/data/local/local_database.dart';
import 'package:industrial_service_reports/features/auth/providers/session_provider.dart';
import 'package:industrial_service_reports/features/auth/services/auth_service.dart';
import 'package:industrial_service_reports/features/policies/providers/policy_visit_provider.dart';
import 'package:industrial_service_reports/features/reports/providers/capture_provider.dart';
import 'package:industrial_service_reports/features/reports/providers/group_signature_provider.dart';
import 'package:industrial_service_reports/features/reports/services/pdf_service.dart';
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
  // CAMBIO 1: control para visita activa
  bool _isCheckingVisit = true;
  bool _hasActiveVisit = false;

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
    // CAMBIO 1: verificar visita activa antes de mostrar la firma individual
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _checkAndHandleActiveVisit(),
    );
  }

  @override
  void dispose() {
    _signerNameController.dispose();
    _signerRoleController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  /// CAMBIO 1: Si la impresora tiene una visita activa, guarda el reporte
  /// como pending_delivery sin pedir firma individual y navega al éxito.
  Future<void> _checkAndHandleActiveVisit() async {
    final String? printerId = ref.read(captureProvider).printerId;
    if (printerId != null && printerId.isNotEmpty) {
      final List<PolicyPrinter> pps = await (localDatabase
              .select(localDatabase.policyPrinters)
            ..where((PolicyPrinters t) => t.printerId.equals(printerId)))
          .get();
      PolicyVisit? visit;
      for (final PolicyPrinter candidate in pps) {
        final PolicyVisit? v =
            await ref.read(activeVisitProvider(candidate.policyId).future);
        debugPrint(
          '[SignatureScreen] _checkAndHandleActiveVisit: '
          'policyId=${candidate.policyId} activeVisit=${v?.id}',
        );
        if (v != null) {
          visit = v;
          break;
        }
      }
      if (visit != null && mounted) {
          debugPrint(
            '[SignatureScreen] visita activa ${visit.id} → '
            'auto-guardando como pending_delivery',
          );
          setState(() {
            _hasActiveVisit = true;
            _isSaving = true;
          });
          await _saveAsPendingDelivery();
          return;
        }
    }
    if (mounted) setState(() => _isCheckingVisit = false);
  }

  /// CAMBIO 1: Guarda el reporte con status = 'pending_delivery' sin firma
  /// y navega a la pantalla de éxito que ya existe.
  Future<void> _saveAsPendingDelivery() async {
    try {
      final CaptureState captureState = ref.read(captureProvider);
      final SessionState sessionState = ref.read(sessionProvider);

      final String? printerId = captureState.printerId;
      if (printerId == null || printerId.isEmpty) {
        throw Exception('No hay impresora asociada al reporte.');
      }

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

      final CatalogLabelType? labelTypeRow = await (localDatabase
              .select(localDatabase.catalogLabelTypes)
            ..where(
                (t) => t.name.equals(captureState.selectedLabelType)))
          .getSingleOrNull();

      final int counterValue =
          int.tryParse(captureState.counterValue.replaceAll(',', '')) ?? 0;
      final int? darknessValue = captureState.darknessValue.isNotEmpty
          ? int.tryParse(captureState.darknessValue)
          : null;

      final String photoPathsJson = jsonEncode(captureState.photoPaths);

      final int reportCount = await (localDatabase.select(localDatabase.reports))
          .get()
          .then((List<Report> l) => l.length);
      final String reportCode =
          'R-${(reportCount + 1).toString().padLeft(3, '0')}';

      final String reportId = const Uuid().v4();
      await localDatabase.into(localDatabase.reports).insert(
            ReportsCompanion.insert(
              id: reportId,
              printerId: printerId,
              techId: techId,
              serviceType: captureState.selectedServiceType,
              status: 'pending_delivery',
              serviceDate: DateTime.now(),
              linearInchesCounter: counterValue,
              technicalCheckboxes: captureState.checkValues,
              darknessLevel: Value(darknessValue),
              labelTypeId: Value(labelTypeRow?.id),
              notes: Value(
                  captureState.notes.isEmpty ? null : captureState.notes),
              signatureName: const Value(null),
              signatureRole: const Value(null),
              photoPaths: Value(photoPathsJson),
              photoCount: Value(captureState.photoPaths.length),
              signatureImagePath: const Value(null),
              code: Value(reportCode),
              assignmentOverride: Value(captureState.assignmentOverride),
            ),
          );

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
                'status': 'pending_delivery',
                'serviceDate': DateTime.now().toIso8601String(),
                'linearInchesCounter': counterValue,
                'darknessLevel': darknessValue,
                'technicalCheckboxes': captureState.checkValues,
                'notes': captureState.notes,
                'signatureName': null,
                'signatureRole': null,
                'photoPaths': captureState.photoPaths,
                'signatureImagePath': null,
                'photoCount': captureState.photoPaths.length,
                'code': reportCode,
              }),
              entityType: 'report',
              entityId: reportId,
            ),
          );

      // Copiar fotos a almacenamiento persistente y encolar para sync
      final io.Directory photosDir = io.Directory(
        '${(await getApplicationDocumentsDirectory()).path}/reports/photos',
      );
      await photosDir.create(recursive: true);
      for (final String photoPath in captureState.photoPaths) {
        String persistentPath = photoPath;
        final io.File src = io.File(photoPath);
        if (src.existsSync() && !photoPath.startsWith(photosDir.path)) {
          final String ext = photoPath.contains('.')
              ? photoPath.split('.').last.toLowerCase()
              : 'jpg';
          final String destPath =
              '${photosDir.path}/${const Uuid().v4()}.$ext';
          await src.copy(destPath);
          persistentPath = destPath;
        }
        await localDatabase.into(localDatabase.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: const Uuid().v4(),
            methodHttp: 'POST',
            endpointDestino: '/api/files',
            payloadJson: jsonEncode(<String, dynamic>{
              'localPath': persistentPath,
              'fileCategory': 'photo',
            }),
            entityType: 'file',
            entityId: reportId,
          ),
        );
      }

      ref.read(captureProvider.notifier).resetCapture();

      if (!mounted) return;
      setState(() => _isSaving = false);
      context.go('/policy-delivery-success', extra: <String, dynamic>{'count': 1, 'isDelivery': false});
    } catch (e) {
      debugPrint('[SignatureScreen] Error en _saveAsPendingDelivery: $e');
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _hasActiveVisit = false;
        _isCheckingVisit = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text('Error al guardar: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // CAMBIO 1: Mientras verificamos visita activa o estamos auto-guardando
    if (_isCheckingVisit || _hasActiveVisit) {
      return Scaffold(
        appBar: AppBar(title: const Text('Guardando reporte...')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Guardando reporte de póliza...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                height: 52,
                width: double.infinity,
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
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 46,
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _onGroupPressed,
                  icon: const Icon(Icons.group_work_rounded, size: 18),
                  label: const Text(
                    'Agrupar con otros reportes de este cliente',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppPalette.backgroundLight,
                    side: const BorderSide(
                        color: AppPalette.surfaceDarkHighlight, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Guarda el reporte como pending_group_signature y lo incorpora al grupo
  /// abierto del cliente (o crea uno nuevo si no existe).
  Future<void> _onGroupPressed() async {
    setState(() => _isSaving = true);
    try {
      final CaptureState captureState = ref.read(captureProvider);
      final SessionState sessionState = ref.read(sessionProvider);

      final String? printerId = captureState.printerId;
      if (printerId == null || printerId.isEmpty) {
        throw Exception('No hay impresora asociada al reporte.');
      }

      // Obtener clientId desde la impresora
      final Printer? printer =
          await (localDatabase.select(localDatabase.printers)
                ..where((Printers t) => t.id.equals(printerId)))
              .getSingleOrNull();
      if (printer == null) throw Exception('Impresora no encontrada.');
      final String clientId = printer.clientId;

      // Buscar grupo abierto existente para este cliente
      final List<Printer> clientPrinters =
          await (localDatabase.select(localDatabase.printers)
                ..where((Printers t) => t.clientId.equals(clientId)))
              .get();
      final List<String> clientPrinterIds =
          clientPrinters.map((Printer p) => p.id).toList();

      String? existingBlockId;
      if (clientPrinterIds.isNotEmpty) {
        final Report? openReport =
            await (localDatabase.select(localDatabase.reports)
                  ..where((Reports r) => Expression.and(<Expression<bool>>[
                        r.status.equals('pending_group_signature'),
                        r.reportBlockStatus.equals('open'),
                        r.printerId.isIn(clientPrinterIds),
                      ]))
                  ..limit(1))
                .getSingleOrNull();
        existingBlockId = openReport?.signatureBlockId;
      }
      final String blockId = existingBlockId ?? const Uuid().v4();

      // Obtener techId
      String techId = sessionState.userId;
      if (techId.isEmpty) {
        const String defaultTechId = '00000000-0000-0000-0000-000000000001';
        final User? existingUser =
            await (localDatabase.select(localDatabase.users)
                  ..where((Users u) => u.id.equals(defaultTechId)))
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

      final CatalogLabelType? labelTypeRow =
          await (localDatabase.select(localDatabase.catalogLabelTypes)
                ..where(
                    (t) => t.name.equals(captureState.selectedLabelType)))
              .getSingleOrNull();

      final int counterValue =
          int.tryParse(captureState.counterValue.replaceAll(',', '')) ?? 0;
      final int? darknessValue = captureState.darknessValue.isNotEmpty
          ? int.tryParse(captureState.darknessValue)
          : null;

      final int reportCount =
          await (localDatabase.select(localDatabase.reports))
              .get()
              .then((List<Report> l) => l.length);
      final String reportCode =
          'R-${(reportCount + 1).toString().padLeft(3, '0')}';
      final String reportId = const Uuid().v4();

      // Copiar fotos a almacenamiento persistente antes de guardar el reporte
      final io.Directory photosDir = io.Directory(
        '${(await getApplicationDocumentsDirectory()).path}/reports/photos',
      );
      await photosDir.create(recursive: true);

      final List<String> persistentPhotoPaths = <String>[];
      for (final String photoPath in captureState.photoPaths) {
        String persistentPath = photoPath;
        final io.File src = io.File(photoPath);
        if (src.existsSync() && !photoPath.startsWith(photosDir.path)) {
          final String ext = photoPath.contains('.')
              ? photoPath.split('.').last.toLowerCase()
              : 'jpg';
          final String destPath =
              '${photosDir.path}/${const Uuid().v4()}.$ext';
          await src.copy(destPath);
          persistentPath = destPath;
        }
        persistentPhotoPaths.add(persistentPath);
      }

      final String photoPathsJson = jsonEncode(persistentPhotoPaths);

      // Insertar reporte en BD local
      await localDatabase.into(localDatabase.reports).insert(
            ReportsCompanion.insert(
              id: reportId,
              printerId: printerId,
              techId: techId,
              serviceType: captureState.selectedServiceType,
              status: 'pending_group_signature',
              serviceDate: DateTime.now(),
              linearInchesCounter: counterValue,
              technicalCheckboxes: captureState.checkValues,
              darknessLevel: Value(darknessValue),
              labelTypeId: Value(labelTypeRow?.id),
              notes: Value(
                  captureState.notes.isEmpty ? null : captureState.notes),
              signatureName: const Value(null),
              signatureRole: const Value(null),
              photoPaths: Value(photoPathsJson),
              photoCount: Value(persistentPhotoPaths.length),
              signatureImagePath: const Value(null),
              code: Value(reportCode),
              assignmentOverride: Value(captureState.assignmentOverride),
              signatureBlockId: Value(blockId),
              reportBlockStatus: const Value('open'),
            ),
          );

      ref.read(captureProvider.notifier).resetCapture();
      ref.invalidate(pendingGroupProvider);

      if (!mounted) return;
      setState(() => _isSaving = false);
      context.go(
        '/policy-delivery-success',
        extra: <String, dynamic>{'count': 1, 'isDelivery': false},
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text('Error al agrupar: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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

      // Regla de negocio: reporte va a 'pending_delivery' SOLO si:
      //   1) La impresora pertenece a una póliza, Y
      //   2) Esa póliza tiene una visita con status='in_progress'
      final List<PolicyPrinter> policyPrinterRows = await (localDatabase
              .select(localDatabase.policyPrinters)
            ..where((PolicyPrinters t) => t.printerId.equals(printerId)))
          .get();

      String reportStatus = 'Signed';
      PolicyVisit? activeVisit;
      for (final PolicyPrinter candidate in policyPrinterRows) {
        final PolicyVisit? v =
            await ref.read(activeVisitProvider(candidate.policyId).future);
        debugPrint(
          '[SignatureScreen] _onFinishPressed: '
          'policyId=${candidate.policyId} activeVisit=${v?.id}',
        );
        if (v != null) {
          activeVisit = v;
          break;
        }
      }
      if (activeVisit != null) {
        reportStatus = 'pending_delivery';
        debugPrint('[SignatureScreen] visita activa ${activeVisit.id} → pending_delivery');
      } else if (policyPrinterRows.isNotEmpty) {
        debugPrint('[SignatureScreen] póliza sin visita activa → Signed');
      } else {
        debugPrint('[SignatureScreen] sin póliza → Signed');
      }

      // Insertar reporte en DB
      final String reportId = const Uuid().v4();
      await localDatabase.into(localDatabase.reports).insert(
            ReportsCompanion.insert(
              id: reportId,
              printerId: printerId,
              techId: techId,
              serviceType: captureState.selectedServiceType,
              status: reportStatus,
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
              assignmentOverride: Value(captureState.assignmentOverride),
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
                'status': reportStatus,
                'serviceDate': DateTime.now().toIso8601String(),
                'linearInchesCounter': counterValue,
                'darknessLevel': darknessValue,
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
      final io.Directory photosDir = io.Directory(
        '${(await getApplicationDocumentsDirectory()).path}/reports/photos',
      );
      await photosDir.create(recursive: true);

      for (final String photoPath in captureState.photoPaths) {
        String persistentPath = photoPath;
        final io.File src = io.File(photoPath);
        if (src.existsSync() && !photoPath.startsWith(photosDir.path)) {
          final String ext = photoPath.contains('.')
              ? photoPath.split('.').last.toLowerCase()
              : 'jpg';
          final String destPath =
              '${photosDir.path}/${const Uuid().v4()}.$ext';
          await src.copy(destPath);
          persistentPath = destPath;
        }
        // ignore: avoid_print
        print('[SignatureScreen] Enqueue photo: $persistentPath (original: $photoPath)');
        await localDatabase.into(localDatabase.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: const Uuid().v4(),
            methodHttp: 'POST',
            endpointDestino: '/api/files',
            payloadJson: jsonEncode(<String, dynamic>{
              'localPath': persistentPath,
              'fileCategory': 'photo',
            }),
            entityType: 'file',
            entityId: reportId,
          ),
        );
      }

      // Encolar firma
      if (signatureImagePath != null) {
        // ignore: avoid_print
        print('[SignatureScreen] Enqueue signature: $signatureImagePath');
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
      } else {
        // ignore: avoid_print
        print('[SignatureScreen] Signature image was null — not enqueued for sync');
      }

      // Generar y guardar PDF localmente (no fatal)
      String? pdfPath;
      try {
        final Uint8List pdfBytes = await PdfService.generateReportPdf(
          reportId: reportId,
          database: localDatabase,
        );
        final io.Directory appDir = await getApplicationDocumentsDirectory();
        final String pdfDir = '${appDir.path}/reports/pdfs';
        await io.Directory(pdfDir).create(recursive: true);
        final Report? rptForName = await (localDatabase.select(localDatabase.reports)
              ..where((Reports r) => r.id.equals(reportId)))
            .getSingleOrNull();
        final User? techForName = rptForName == null
            ? null
            : await (localDatabase.select(localDatabase.users)
                  ..where((Users u) => u.id.equals(rptForName.techId)))
                .getSingleOrNull();
        pdfPath = '$pdfDir/${PdfService.reportPdfName(rptForName, techForName)}';
        await io.File(pdfPath).writeAsBytes(pdfBytes);
        // ignore: avoid_print
        print('[SignatureScreen] PDF guardado: $pdfPath');
      } catch (e) {
        // PDF generation failure is non-fatal
        // ignore: avoid_print
        print('[SignatureScreen] PDF generation failed (non-fatal): $e');
      }

      // Encolar PDF para sync
      if (pdfPath != null) {
        // ignore: avoid_print
        print('[SignatureScreen] Enqueue PDF: $pdfPath');
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
            entityId: reportId,
          ),
        );
      } else {
        // ignore: avoid_print
        print('[SignatureScreen] PDF path was null — not enqueued for sync');
      }

      // Resetear estado de captura
      ref.read(captureProvider.notifier).resetCapture();

      if (!mounted) return;
      setState(() => _isSaving = false);

      // Enviar el reporte por email a los contactos del cliente (no bloqueante)
      await _sendReportEmailAfterSignature(reportId, printerId);
      if (!mounted) return;

      // CAMBIO 1: si es pending_delivery, navegar a pantalla de éxito de póliza
      if (reportStatus == 'pending_delivery') {
        context.go('/policy-delivery-success', extra: <String, dynamic>{'count': 1, 'isDelivery': false});
        return;
      }

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

  /// Envía el reporte firmado por email a los contactos del cliente.
  /// No bloqueante: cualquier error solo muestra un SnackBar naranja.
  Future<void> _sendReportEmailAfterSignature(
    String reportId,
    String printerId,
  ) async {
    try {
      final Printer? printer = await (localDatabase.select(localDatabase.printers)
            ..where((Printers t) => t.id.equals(printerId)))
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
        await _postSendEmail(reportId, null, authToken);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppPalette.success,
            content: Text(
              'Reporte enviado por email a ${contacts.length} contacto${contacts.length == 1 ? '' : 's'}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (!mounted) return;
      await _promptExtraEmailAndSend(reportId, authToken);
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

  Future<void> _promptExtraEmailAndSend(
    String reportId,
    String? authToken,
  ) async {
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

    await _postSendEmail(reportId, emailController.text.trim(), authToken);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppPalette.success,
        content: Text('Reporte enviado por email'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
