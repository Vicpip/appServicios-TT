import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:industrial_service_reports/core/router/app_routes.dart';
import 'package:industrial_service_reports/core/router/route_args.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';

class PolicyDeliverySuccessScreen extends StatelessWidget {
  const PolicyDeliverySuccessScreen({
    super.key,
    required this.reportCount,
    this.isDelivery = true,
    this.deliveryId,
    this.policyFolio,
  });

  final int reportCount;
  final bool isDelivery;
  final String? deliveryId;
  final String? policyFolio;

  @override
  Widget build(BuildContext context) {
    final String title =
        isDelivery ? 'Entrega registrada' : 'Servicio registrado';
    final String subtitle = isDelivery
        ? '$reportCount equipo${reportCount == 1 ? '' : 's'} '
            'firmado${reportCount == 1 ? '' : 's'}'
        : 'Reporte guardado correctamente';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) {
        if (!didPop) context.go('/');
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppPalette.success.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppPalette.success,
                      size: 60,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppPalette.backgroundLight,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isDelivery
                        ? 'La entrega se sincronizará con el servidor en el próximo ciclo de sync.'
                        : 'El reporte se sincronizará con el servidor en el próximo ciclo de sync.',
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  // Botón ver resumen (solo en flujo de entrega global con deliveryId)
                  if (isDelivery && deliveryId != null) ...<Widget>[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => context.pushNamed(
                          AppRoutes.visitSummary,
                          extra: VisitSummaryArgs(
                            deliveryId: deliveryId!,
                            policyFolio: policyFolio ?? '',
                          ),
                        ),
                        icon: const Icon(Icons.summarize_rounded, size: 18),
                        label: const Text(
                          'Ver resumen de visita',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppPalette.backgroundLight,
                          side: const BorderSide(color: AppPalette.primary),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Botón volver
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () => context.go('/'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppPalette.primary,
                        foregroundColor: AppPalette.backgroundLight,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Ir al inicio',
                        style:
                            TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
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
}
