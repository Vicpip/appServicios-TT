import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/data/local/local_database.dart';
import 'package:industrial_service_reports/features/auth/providers/session_provider.dart';
import 'package:industrial_service_reports/features/reports/providers/capture_provider.dart';
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
  bool _isSaving = false;

  @override
  void dispose() {
    _signerNameController.dispose();
    _signerRoleController.dispose();
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
                            border: Border.all(color: const Color(0xFFCFD3DA)),
                          ),
                          child: const Center(
                            child: Text(
                              'Lienzo de firma (Simulado por ahora)',
                              style: TextStyle(
                                color: Color(0xFF7D8794),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Firma limpiada (simulado)'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
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
            border: Border(top: BorderSide(color: AppPalette.surfaceDarkHighlight)),
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
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
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
        final User? existingUser = await (localDatabase.select(localDatabase.users)
              ..where((u) => u.id.equals(defaultTechId)))
            .getSingleOrNull();
        if (existingUser == null) {
          await localDatabase.into(localDatabase.users).insert(
                UsersCompanion.insert(
                  id: defaultTechId,
                  name: sessionState.userName.isEmpty ? 'Técnico' : sessionState.userName,
                  email: sessionState.email.isEmpty
                      ? 'tecnico@empresa.com'
                      : sessionState.email,
                  role: 'technician',
                ),
              );
        }
        techId = defaultTechId;
      }

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

      // Insertar reporte en DB
      final String reportId = const Uuid().v4();
      await localDatabase.into(localDatabase.reports).insert(
            ReportsCompanion.insert(
              id: reportId,
              printerId: printerId,
              techId: techId,
              serviceType: captureState.selectedServiceType,
              status: 'pendiente_sync',
              serviceDate: DateTime.now(),
              linearInchesCounter: counterValue,
              technicalCheckboxes: captureState.checkValues,
              darknessLevel: Value(darknessValue),
              labelTypeId: Value(labelTypeRow?.id),
              notes: Value(captureState.notes.isEmpty ? null : captureState.notes),
              signatureName: Value(_signerNameController.text.trim()),
              signatureRole: Value(_signerRoleController.text.trim()),
            ),
          );

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
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Generando PDF...'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Text('Compartir PDF'),
              ),
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
