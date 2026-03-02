import 'package:flutter/material.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/features/reports/presentation/express_capture_screen.dart';
import 'package:industrial_service_reports/features/printers/presentation/service_history_screen.dart';

class PrinterDetailScreen extends StatelessWidget {
  const PrinterDetailScreen({
    super.key,
    required this.serialNumber,
    required this.model,
    required this.client,
  });

  final String serialNumber;
  final String model;
  final String client;

  @override
  Widget build(BuildContext context) {
    const Color screenBg = Color(0xFF0D1117);
    const Color cardBg = Color(0xFF101826);
    const Color cardBorder = Color(0xFF243245);
    const Color textMuted = Color(0xFF8BA0BC);
    const Color infoBlue = Color(0xFF2A8BFF);
    const Color successBg = Color(0xFF103A27);
    const Color successText = Color(0xFF33E98A);
    const Color warningBg = Color(0xFF4A3A12);
    const Color warningText = Color(0xFFFFD166);
    final bool isHealthy = serialNumber.hashCode.isEven;
    final String displayModel =
        model.toLowerCase().contains('zebra') ? model : 'Zebra $model';
    const String lastServiceType = 'Preventivo';
    final _ServiceTypeVisual lastServiceVisual =
        _serviceTypeVisual(lastServiceType);

    return Scaffold(
      backgroundColor: screenBg,
      appBar: AppBar(
        backgroundColor: screenBg,
        title: const Text('Ficha Tecnica'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              children: const <Widget>[
                Icon(Icons.offline_bolt_rounded, size: 13, color: Color(0xFF5DC9FF)),
                SizedBox(width: 4),
                Text(
                  'OFFLINE READY',
                  style: TextStyle(
                    color: Color(0xFF5DC9FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 140),
          child: Column(
            children: <Widget>[
              _DetailCard(
                bgColor: cardBg,
                borderColor: cardBorder,
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFF152133),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cardBorder),
                      ),
                      child: const Icon(
                        Icons.print_rounded,
                        size: 32,
                        color: Color(0xFFC6D2E4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            displayModel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'S/N: $serialNumber',
                            style: const TextStyle(
                              color: infoBlue,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'CONTADOR ACTUAL',
                            style: TextStyle(
                              color: textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.7,
                            ),
                          ),
                          const Text(
                            '145,000 in',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _DetailCard(
                bgColor: cardBg,
                borderColor: cardBorder,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'ESTADO DE LA IMPRESORA',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Text(
                          isHealthy ? 'Correcta' : 'Atencion',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isHealthy ? successBg : warningBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isHealthy
                                  ? successText.withValues(alpha: 0.45)
                                  : warningText.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Icons.circle_rounded,
                                size: 9,
                                color: isHealthy ? successText : warningText,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isHealthy ? 'EN LINEA' : 'ATENCION',
                                style: TextStyle(
                                  color: isHealthy ? successText : warningText,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _DetailCard(
                bgColor: cardBg,
                borderColor: cardBorder,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'DATOS DEL CLIENTE',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.business_center_rounded,
                          size: 16,
                          color: Color(0xFFA4B6CE),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            client,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: <Widget>[
                        Icon(Icons.location_on_outlined, size: 16, color: Color(0xFFA4B6CE)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Planta A',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Icon(Icons.grid_view_rounded, size: 16, color: Color(0xFFA4B6CE)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Linea Ensamble 4',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _DetailCard(
                bgColor: cardBg,
                borderColor: cardBorder,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'ULTIMO SERVICIO',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Icon(
                                    lastServiceVisual.icon,
                                    size: 18,
                                    color: lastServiceVisual.color,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Mantenimiento $lastServiceType',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '05 de Noviembre, 2023',
                                style: TextStyle(
                                  color: Color(0xFF8FA3BE),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: const <Widget>[
                            Text(
                              'CONTADOR',
                              style: TextStyle(
                                color: textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              '145,000\nin',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: infoBlue,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                height: 1.05,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: cardBorder, height: 1),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        const CircleAvatar(
                          radius: 16,
                          backgroundColor: Color(0xFF2B3D56),
                          child: Icon(
                            Icons.engineering_rounded,
                            size: 18,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Ing. John Doe',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Tecnico Certificado',
                                style: TextStyle(
                                  color: textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showMockSnack(context, 'Abrira el ultimo reporte'),
                          child: const Text(
                            'VER REPORTE',
                            style: TextStyle(
                              color: infoBlue,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: screenBg,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ExpressCaptureScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.playlist_add_check_circle_rounded),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    label: const Text(
                      'Crear reporte de servicio',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: FilledButton.tonalIcon(
                          onPressed: () => _showMockSnack(context, 'Mostrando QR...'),
                          icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF242E3D),
                            foregroundColor: Colors.white,
                          ),
                          label: const Text('Mostrar QR'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: FilledButton.tonalIcon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ServiceHistoryScreen(
                                  printerId: 'PRN-$serialNumber',
                                  model: model,
                                  serialNumber: serialNumber,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.history_rounded, size: 18),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF242E3D),
                            foregroundColor: Colors.white,
                          ),
                          label: const Text('Ver Historial'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _showMockSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  _ServiceTypeVisual _serviceTypeVisual(String serviceType) {
    switch (serviceType) {
      case 'Preventivo':
        return const _ServiceTypeVisual(
          icon: Icons.check_circle_rounded,
          color: AppPalette.success,
        );
      case 'Correctivo':
        return const _ServiceTypeVisual(
          icon: Icons.build_rounded,
          color: Color(0xFFE57373),
        );
      case 'Diagnostico':
        return const _ServiceTypeVisual(
          icon: Icons.troubleshoot_rounded,
          color: AppPalette.warning,
        );
      case 'Instalacion':
        return const _ServiceTypeVisual(
          icon: Icons.settings_input_component_rounded,
          color: Color(0xFF8EC5FF),
        );
      default:
        return const _ServiceTypeVisual(
          icon: Icons.miscellaneous_services_rounded,
          color: Colors.white70,
        );
    }
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.bgColor,
    required this.borderColor,
    required this.child,
  });

  final Color bgColor;
  final Color borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class _ServiceTypeVisual {
  const _ServiceTypeVisual({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;
}
