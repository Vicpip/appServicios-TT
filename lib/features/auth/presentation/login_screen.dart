import 'package:flutter/material.dart';
import 'package:industrial_service_reports/app.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _screenBg = Color(0xFF0D1117);
  static const Color _cardBg = Color(0xFF161B22);
  static const Color _cardBorder = Color(0xFF293445);
  static const Color _primaryBlue = Color(0xFF136DEC);
  static const Color _mutedText = Color(0xFFA2ADBC);
  static const Color _softText = Color(0xFFD7DCE3);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _userController =
      TextEditingController(text: 'juan.perez@empresa.com');
  final TextEditingController _pinController =
      TextEditingController(text: '1234');

  bool _isLoading = false;

  @override
  void dispose() {
    _userController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                                    keyboardType: TextInputType.number,
                                    obscureText: true,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'PIN de Acceso (4 dígitos)',
                                      prefixIcon: Icon(Icons.lock_rounded),
                                    ),
                                    validator: _pinValidator,
                                    onFieldSubmitted: (_) => _onLoginPressed(),
                                  ),
                                  const SizedBox(height: 26),
                                  SizedBox(
                                    height: 52,
                                    child: FilledButton(
                                      onPressed:
                                          _isLoading ? null : _onLoginPressed,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: _primaryBlue,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.4,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text(
                                              'INICIAR SESIÓN',
                                              style: TextStyle(
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
                                            'Contacta a soporte para restablecer tu PIN.',
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      '¿Olvidaste tu PIN? Contacta a soporte',
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
            Container(
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
                  const Icon(
                    Icons.cloud_done_rounded,
                    color: Color(0xFF4CFF8C),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Base de Datos Local: Lista',
                          style: TextStyle(
                            color: _softText,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Última sincronización: Hoy, 07:30 AM',
                          style: TextStyle(
                            color: _mutedText,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 36,
                    child: FilledButton.tonalIcon(
                      onPressed: _onForceSyncPressed,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF243041),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.sync_rounded, size: 16),
                      label: const Text(
                        'Forzar Sync',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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

  String? _pinValidator(String? value) {
    final String trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Campo obligatorio';
    }
    if (trimmed.length < 4) {
      return 'Ingresa al menos 4 dígitos';
    }
    return null;
  }

  Future<void> _onLoginPressed() async {
    final bool valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() {
      _isLoading = true;
    });

    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    Navigator.of(context).pushReplacementNamed(ServiceReportsApp.dashboardRoute);
  }

  void _onForceSyncPressed() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sincronizando catálogos desde el servidor...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
