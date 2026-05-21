import 'dart:io' as io;
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:industrial_service_reports/core/utils/date_utils.dart' show formatLocalCDMX;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/data/local/local_database.dart';
import 'package:industrial_service_reports/features/auth/providers/auth_provider.dart';
import 'package:industrial_service_reports/features/auth/providers/session_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';

class TechnicianProfileScreen extends ConsumerStatefulWidget {
  const TechnicianProfileScreen({super.key});

  static const Color _screenBg = Color(0xFF0D1117);
  static const Color _cardBg = Color(0xFF161B22);
  static const Color _cardBorder = Color(0xFF293445);
  static const Color _mutedText = Color(0xFFA2ADBC);
  static const Color _softBlue = Color(0xFF8EC5FF);

  @override
  ConsumerState<TechnicianProfileScreen> createState() =>
      _TechnicianProfileScreenState();
}

class _TechnicianProfileScreenState
    extends ConsumerState<TechnicianProfileScreen> {
  String? _signaturePath;
  DateTime? _lastSyncAt;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final String userId = ref.read(sessionProvider).userId;
    if (userId.isEmpty) return;
    final User? user = await (localDatabase.select(localDatabase.users)
          ..where((u) => u.id.equals(userId)))
        .getSingleOrNull();
    if (mounted) {
      setState(() {
        _signaturePath = user?.signaturePath;
        _lastSyncAt = user?.lastSyncAt;
      });
    }
  }

  String _formatLastSync(DateTime dt) => formatLocalCDMX(dt, showTime: true);

  @override
  Widget build(BuildContext context) {
    final SessionState session = ref.watch(sessionProvider);
    final String initials = _buildInitials(session.userName);
    final String lastSyncText = _lastSyncAt != null
        ? _formatLastSync(_lastSyncAt!)
        : 'Sin sincronización aún';

    final bool hasSignature = _signaturePath != null &&
        io.File(_signaturePath!).existsSync();

    return Scaffold(
      backgroundColor: TechnicianProfileScreen._screenBg,
      appBar: AppBar(
        backgroundColor: TechnicianProfileScreen._screenBg,
        title: const Text('Mi Perfil'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                children: <Widget>[
                  const SizedBox(height: 6),
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: const Color(0xFF1E304D),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: TechnicianProfileScreen._softBlue,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    session.userName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    session.email,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: TechnicianProfileScreen._mutedText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _ProfileCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'FIRMA DIGITAL DEL TÉCNICO',
                          style: TextStyle(
                            color: TechnicianProfileScreen._softBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Esta firma se adjuntará automáticamente como tu autorización en los reportes de servicio.',
                          style: TextStyle(
                            color: TechnicianProfileScreen._mutedText,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: hasSignature
                                ? Colors.white
                                : const Color(0xFF1E242C),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: TechnicianProfileScreen._cardBorder,
                            ),
                          ),
                          child: hasSignature
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.file(
                                    io.File(_signaturePath!),
                                    fit: BoxFit.contain,
                                  ),
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Icon(
                                      Icons.draw_rounded,
                                      size: 42,
                                      color: Colors.white54,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Firma Configurada',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _openSignaturePad(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: TechnicianProfileScreen._softBlue,
                            ),
                            foregroundColor:
                                TechnicianProfileScreen._softBlue,
                          ),
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          label: const Text(
                            'Actualizar Firma',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ProfileCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _SystemRow(
                          label: 'Versión de la App',
                          value: '1.0.0 (Build 12)',
                        ),
                        const SizedBox(height: 12),
                        _SystemRow(
                          label: 'Última Sincronización',
                          value: lastSyncText,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () {
                        ref.read(authProvider.notifier).logout();
                        context.go('/login');
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4B1F1F),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        'CERRAR SESIÓN',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cerrar sesión borrará los datos locales no sincronizados.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: TechnicianProfileScreen._mutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openSignaturePad(BuildContext context) async {
    final Uint8List? signatureBytes = await showModalBottomSheet<Uint8List?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SignaturePadSheet(),
    );
    if (signatureBytes == null || signatureBytes.isEmpty) return;

    final String userId = ref.read(sessionProvider).userId;
    final io.Directory appDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${appDir.path}/signatures';
    final io.Directory dir = io.Directory(dirPath);
    if (!await dir.exists()) await dir.create(recursive: true);
    final String filePath = '$dirPath/$userId.png';
    await io.File(filePath).writeAsBytes(signatureBytes);

    await (localDatabase.update(localDatabase.users)
          ..where((u) => u.id.equals(userId)))
        .write(UsersCompanion(signaturePath: Value(filePath)));

    if (mounted) {
      setState(() => _signaturePath = filePath);
    }
  }

  String _buildInitials(String name) {
    final List<String> parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TechnicianProfileScreen._cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TechnicianProfileScreen._cardBorder),
      ),
      child: child,
    );
  }
}

class _SignaturePadSheet extends StatefulWidget {
  const _SignaturePadSheet();

  @override
  State<_SignaturePadSheet> createState() => _SignaturePadSheetState();
}

class _SignaturePadSheetState extends State<_SignaturePadSheet> {
  late final SignatureController _ctrl;
  bool _isEmpty = true;

  @override
  void initState() {
    super.initState();
    _ctrl = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black87,
      exportBackgroundColor: Colors.white,
    );
    _ctrl.addListener(() => setState(() => _isEmpty = _ctrl.isEmpty));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'FIRMA DEL TÉCNICO',
            style: TextStyle(
              color: Color(0xFF8EC5FF),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Dibuja tu firma en el recuadro de abajo',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isEmpty
                    ? const Color(0xFF293445)
                    : const Color(0xFF8EC5FF),
                width: _isEmpty ? 1 : 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Signature(
                controller: _ctrl,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _ctrl.clear();
                }),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  side: const BorderSide(color: Colors.white24),
                ),
                icon: const Icon(Icons.cleaning_services_rounded, size: 16),
                label: const Text('Limpiar'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _isEmpty
                    ? null
                    : () async {
                        final Uint8List? bytes = await _ctrl.toPngBytes();
                        if (context.mounted) Navigator.pop(context, bytes);
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8EC5FF),
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.save_rounded, size: 16),
                label: const Text(
                  'Guardar Firma',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SystemRow extends StatelessWidget {
  const _SystemRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            '$label:',
            style: const TextStyle(
              color: TechnicianProfileScreen._mutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
