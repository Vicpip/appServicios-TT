import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:industrial_service_reports/features/auth/providers/auth_provider.dart';
import 'package:industrial_service_reports/features/sync/providers/startup_sync_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const Color _screenBg = Color(0xFF0D1117);
  static const Color _cardBg = Color(0xFF161B22);
  static const Color _cardBorder = Color(0xFF293445);
  static const Color _primaryBlue = Color(0xFF136DEC);
  static const Color _mutedText = Color(0xFFA2ADBC);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  @override
  void dispose() {
    _userController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isAuthLoading = ref.watch(authProvider).isLoading;
    final StartupSyncState syncState = ref.watch(startupSyncProvider);
    // Block login while a sync is in flight (capped at 10 s by the notifier).
    final bool isBlocked = isAuthLoading || syncState.isRunning;

    ref.listen<AsyncValue<void>>(authProvider, (_, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error.toString().replaceFirst('Exception: ', '')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: _screenBg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: <Widget>[
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            child: Column(
                              children: <Widget>[
                                SizedBox(
                                  height: 220,
                                  child: Image.asset(
                                    'lib/img/logo_smp.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) {
                                      return const Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: <Widget>[
                                          Icon(
                                            Icons.business_rounded,
                                            size: 88,
                                            color: Color(0xFF8EC5FF),
                                          ),
                                          SizedBox(height: 10),
                                          Text(
                                            'Logo no disponible',
                                            style: TextStyle(
                                              color: _mutedText,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Field Service Management',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _mutedText,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              color: _cardBg,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: _cardBorder),
                              boxShadow: const <BoxShadow>[
                                BoxShadow(
                                  color: Color(0x66000000),
                                  blurRadius: 16,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  TextFormField(
                                    controller: _userController,
                                    textInputAction: TextInputAction.next,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText:
                                          'Correo Electrónico o ID de Técnico',
                                      prefixIcon: Icon(Icons.person_rounded),
                                    ),
                                    validator: _requiredValidator,
                                  ),
                                  const SizedBox(height: 22),
                                  TextFormField(
                                    controller: _pinController,
                                    textInputAction: TextInputAction.done,
                                    obscureText: true,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Contraseña',
                                      prefixIcon: Icon(Icons.lock_rounded),
                                    ),
                                    validator: _requiredValidator,
                                    onFieldSubmitted: (_) => _onLoginPressed(),
                                  ),
                                  const SizedBox(height: 26),
                                  SizedBox(
                                    height: 52,
                                    child: FilledButton(
                                      onPressed:
                                          isBlocked ? null : _onLoginPressed,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: _primaryBlue,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: isAuthLoading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.4,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(
                                              syncState.isRunning
                                                  ? 'Sincronizando...'
                                                  : 'INICIAR SESIÓN',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextButton(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context)
                                          .hideCurrentSnackBar();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Contacta a soporte para restablecer tu contraseña.',
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      '¿Olvidaste tu contraseña? Contacta a soporte',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _mutedText,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _SyncStatusCard(syncState: syncState, onSync: _onForceSyncPressed),
          ],
        ),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Campo obligatorio';
    }
    return null;
  }

  Future<void> _onLoginPressed() async {
    final bool valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    await ref.read(authProvider.notifier).login(
          email: _userController.text,
          password: _pinController.text,
        );
  }

  void _onForceSyncPressed() {
    ref.read(startupSyncProvider.notifier).runAutoSync();
  }
}

// ---------------------------------------------------------------------------
// Sync status card (bottom of login screen)
// ---------------------------------------------------------------------------

class _SyncStatusCard extends StatelessWidget {
  const _SyncStatusCard({
    required this.syncState,
    required this.onSync,
  });

  static const Color _cardBg = Color(0xFF161B22);
  static const Color _cardBorder = Color(0xFF293445);
  static const Color _softText = Color(0xFFD7DCE3);
  static const Color _mutedText = Color(0xFFA2ADBC);

  final StartupSyncState syncState;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final bool isRunning = syncState.isRunning;

    final IconData iconData;
    final Color iconColor;
    final String title;
    final String subtitle;

    switch (syncState.phase) {
      case StartupSyncPhase.running:
        iconData = Icons.sync_rounded;
        iconColor = const Color(0xFF60A5FA);
        title = 'Sincronizando datos...';
        subtitle = 'Descargando catálogos del servidor';
      case StartupSyncPhase.done:
        iconData = Icons.cloud_done_rounded;
        iconColor = const Color(0xFF4CFF8C);
        title = 'Base de Datos Local: Lista';
        subtitle = syncState.syncedThisSession
            ? 'Datos actualizados correctamente'
            : 'Usando datos almacenados localmente';
      case StartupSyncPhase.failed:
        iconData = Icons.wifi_off_rounded;
        iconColor = const Color(0xFFF59E0B);
        title = 'Sin conexión al servidor';
        subtitle = syncState.message.isNotEmpty
            ? syncState.message
            : 'Usando datos locales almacenados';
      case StartupSyncPhase.idle:
        iconData = Icons.cloud_done_rounded;
        iconColor = const Color(0xFF4CFF8C);
        title = 'Base de Datos Local';
        subtitle = 'Verificando conexión...';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: <Widget>[
          if (isRunning)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF60A5FA),
              ),
            )
          else
            Icon(iconData, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: _softText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 36,
            child: FilledButton.tonalIcon(
              onPressed: isRunning ? null : onSync,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF243041),
                foregroundColor: Colors.white,
              ),
              icon: isRunning
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync_rounded, size: 16),
              label: Text(
                isRunning ? 'En curso' : 'Forzar Sync',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
