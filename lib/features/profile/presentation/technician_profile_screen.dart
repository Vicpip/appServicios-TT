import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:industrial_service_reports/features/auth/providers/auth_provider.dart';
import 'package:industrial_service_reports/features/auth/providers/session_provider.dart';

class TechnicianProfileScreen extends ConsumerWidget {
  const TechnicianProfileScreen({super.key});

  static const Color _screenBg = Color(0xFF0D1117);
  static const Color _cardBg = Color(0xFF161B22);
  static const Color _cardBorder = Color(0xFF293445);
  static const Color _mutedText = Color(0xFFA2ADBC);
  static const Color _softBlue = Color(0xFF8EC5FF);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionState session = ref.watch(sessionProvider);
    final String initials = _buildInitials(session.userName);

    return Scaffold(
      backgroundColor: _screenBg,
      appBar: AppBar(
        backgroundColor: _screenBg,
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
                        color: _softBlue,
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
                      color: _mutedText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _ProfileCard(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 2,
                      ),
                      leading: const Icon(
                        Icons.lock_outline_rounded,
                        color: _softBlue,
                      ),
                      title: const Text(
                        'Cambiar PIN de Acceso',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text(
                        'Actualiza tu código de 4 dígitos para acceso offline',
                        style: TextStyle(
                          color: _mutedText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white54,
                      ),
                      onTap: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cambio de PIN (mock)'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ProfileCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'FIRMA DIGITAL DEL TÉCNICO',
                          style: TextStyle(
                            color: _softBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Esta firma se adjuntará automáticamente como tu autorización en los reportes de servicio.',
                          style: TextStyle(
                            color: _mutedText,
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
                            color: const Color(0xFF1E242C),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _cardBorder),
                          ),
                          child: const Column(
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
                          onPressed: () {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Abriendo lienzo de firma...'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: _softBlue),
                            foregroundColor: _softBlue,
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
                  const _ProfileCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _SystemRow(
                          label: 'Versión de la App',
                          value: '1.0.0 (Build 12)',
                        ),
                        SizedBox(height: 12),
                        _SystemRow(
                          label: 'Última Sincronización',
                          value: 'Hoy, 07:30 AM',
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
                      color: _mutedText,
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
