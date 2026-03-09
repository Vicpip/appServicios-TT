import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:industrial_service_reports/core/router/app_routes.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/features/reports/providers/capture_provider.dart';

class ReportSummaryScreen extends ConsumerWidget {
  const ReportSummaryScreen({super.key});

  // Datos de impresora: permanecen mock hasta conectar con BD
  static const String _serial = '99J882';
  static const String _model = 'ZT610';
  static const String _counterPrevious = '100,000';
  static const String _previousServiceDate = '12 Feb 2025';
  static const String _currentServiceDate = '12 Ago 2025';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CaptureState capture = ref.watch(captureProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumen del Reporte'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1024),
            child: Column(
              children: <Widget>[
                const _StatusBanner(),
                const SizedBox(height: 12),
                _GeneralSummaryCard(
                  serial: _serial,
                  model: _model,
                  serviceType: capture.selectedServiceType,
                  counter: capture.counterValue,
                  darkness: capture.darknessValue,
                  labelType: capture.selectedLabelType,
                ),
                const SizedBox(height: 12),
                _UsageChartCard(
                  previousCounter: _counterPrevious,
                  currentCounter: capture.counterValue,
                  previousDate: _previousServiceDate,
                  currentDate: _currentServiceDate,
                ),
                const SizedBox(height: 12),
                _DiagnosticCard(
                  diagnostics: capture.selectedDiagnostics,
                  notes: capture.notes.isEmpty
                      ? 'Sin observaciones adicionales.'
                      : capture.notes,
                ),
                const SizedBox(height: 12),
                const _EvidenceCard(),
              ],
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
            height: 50,
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.pushNamed(AppRoutes.signature),
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.success,
                foregroundColor: AppPalette.backgroundLight,
              ),
              child: const Text(
                'Proceder a Firma',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppPalette.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.surfaceDarkHighlight),
      ),
      child: Row(
        children: <Widget>[
          RichText(
            text: const TextSpan(
              children: <TextSpan>[
                TextSpan(
                  text: 'Estado: ',
                  style: TextStyle(
                    color: AppPalette.backgroundLight,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: 'Por firmar',
                  style: TextStyle(
                    color: AppPalette.warning,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Chip(
            backgroundColor: AppPalette.warningDark,
            side: const BorderSide(color: AppPalette.warning),
            avatar: const Icon(
              Icons.cloud_upload_rounded,
              color: AppPalette.warning,
              size: 18,
            ),
            label: const Text(
              'Pendiente de Sync',
              style: TextStyle(
                color: AppPalette.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneralSummaryCard extends StatelessWidget {
  const _GeneralSummaryCard({
    required this.serial,
    required this.model,
    required this.serviceType,
    required this.counter,
    required this.darkness,
    required this.labelType,
  });

  final String serial;
  final String model;
  final String serviceType;
  final String counter;
  final String darkness;
  final String labelType;

  _ServiceTypeVisual _serviceTypeVisual() {
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
      case 'Diagnóstico':
        return const _ServiceTypeVisual(
          icon: Icons.troubleshoot_rounded,
          color: AppPalette.warning,
        );
      case 'Instalación':
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

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      title: '1. Información del Equipo',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppPalette.surfaceDarkHighlight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF27364D)),
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxWidth < 760;

            final Widget leftColumn = Column(
              children: <Widget>[
                _InfoLineCompact(label: 'Serial', value: serial),
                const SizedBox(height: 10),
                _InfoLineCompact(label: 'Modelo', value: '$model - 600dpi'),
                const SizedBox(height: 10),
                _ServiceTypeLine(
                  serviceType: serviceType,
                  visual: _serviceTypeVisual(),
                ),
              ],
            );

            final Widget rightColumn = Column(
              children: <Widget>[
                _InfoLineCompact(
                  label: 'Contador Actual',
                  value: counter.isEmpty ? '-' : '$counter in',
                ),
                const SizedBox(height: 10),
                _InfoLineCompact(
                  label: 'Nivel de Darkness',
                  value: darkness.isEmpty ? '-' : darkness,
                ),
                const SizedBox(height: 10),
                _InfoLineCompact(label: 'Etiqueta', value: labelType),
              ],
            );

            if (compact) {
              return Column(
                children: <Widget>[
                  leftColumn,
                  const SizedBox(height: 12),
                  const Divider(
                    color: AppPalette.surfaceDark,
                    height: 1,
                    thickness: 1,
                  ),
                  const SizedBox(height: 12),
                  rightColumn,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: leftColumn),
                Container(
                  width: 1,
                  height: 84,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  color: AppPalette.surfaceDark,
                ),
                Expanded(child: rightColumn),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _UsageChartCard extends StatelessWidget {
  const _UsageChartCard({
    required this.previousCounter,
    required this.currentCounter,
    required this.previousDate,
    required this.currentDate,
  });

  final String previousCounter;
  final String currentCounter;
  final String previousDate;
  final String currentDate;

  int _parseCounter(String value) =>
      int.tryParse(value.replaceAll(',', '')) ?? 0;

  String _formatCounter(int value) {
    final String raw = value.toString();
    final bool negative = raw.startsWith('-');
    final String digits = negative ? raw.substring(1) : raw;
    final StringBuffer buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }

    return negative ? '-${buffer.toString()}' : buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final int previousValue = _parseCounter(previousCounter);
    final int currentValue = _parseCounter(currentCounter);
    final int currentIncrease = currentValue - previousValue;

    final List<_CounterBarPoint> points = <_CounterBarPoint>[
      _CounterBarPoint(
        x: 0,
        label: 'Anterior',
        date: previousDate,
        counter: previousValue,
        increase: 0,
        color: AppPalette.primaryHover,
      ),
      _CounterBarPoint(
        x: 1,
        label: 'Actual',
        date: currentDate,
        counter: currentValue,
        increase: currentIncrease,
        color: AppPalette.primary,
      ),
    ];

    return _PremiumCard(
      title: 'Evolución de Impresion (Contador)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: 170,
            child: _UsageBarChart(points: points),
          ),
          const SizedBox(height: 8),
          Text(
            'Servicio Anterior: ${_formatCounter(previousValue)} in   |   Actual: ${_formatCounter(currentValue)} in',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageBarChart extends StatelessWidget {
  const _UsageBarChart({
    required this.points,
  });

  final List<_CounterBarPoint> points;

  String _formatCounter(int value) {
    final String raw = value.toString();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(raw[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    double maxCounter = 0;
    for (final _CounterBarPoint item in points) {
      final double normalized = item.counter / 1000;
      if (normalized > maxCounter) {
        maxCounter = normalized;
      }
    }
    final double maxY = maxCounter <= 0 ? 130 : (maxCounter * 1.1);

    return BarChart(
      BarChartData(
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppPalette.surfaceDarkHighlight,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBorder:
                const BorderSide(color: AppPalette.surfaceDarkHighlight),
            getTooltipColor: (_) => const Color(0xFF0E1522),
            getTooltipItem: (
              BarChartGroupData group,
              int groupIndex,
              BarChartRodData rod,
              int rodIndex,
            ) {
              final int x = group.x;
              if (x < 0 || x >= points.length) {
                return null;
              }

              final _CounterBarPoint point = points[x];
              final String sign = point.increase >= 0 ? '+' : '-';
              final int magnitude = point.increase.abs();

              return BarTooltipItem(
                '${point.date}\nIncremento: $sign${_formatCounter(magnitude)} in',
                const TextStyle(
                  color: AppPalette.backgroundLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 25,
              reservedSize: 30,
              getTitlesWidget: (double value, _) => Text(
                value.toInt().toString(),
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, _) {
                final int x = value.toInt();
                if (x < 0 || x >= points.length) {
                  return const SizedBox.shrink();
                }
                const TextStyle style = TextStyle(
                  color: AppPalette.backgroundLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                );
                return Text(points[x].label, style: style);
              },
            ),
          ),
        ),
        barGroups: List<BarChartGroupData>.generate(
          points.length,
          (int index) {
            final _CounterBarPoint point = points[index];
            return BarChartGroupData(
              x: point.x,
              barRods: <BarChartRodData>[
                BarChartRodData(
                  toY: point.counter / 1000,
                  color: point.color,
                  width: 26,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DiagnosticCard extends StatelessWidget {
  const _DiagnosticCard({
    required this.diagnostics,
    required this.notes,
  });

  final List<String> diagnostics;
  final String notes;

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      title: 'Diagnóstico Técnico',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (diagnostics.isEmpty)
            const Text(
              'Sin diagnósticos seleccionados.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            )
          else
            ...diagnostics.map((String item) {
              final _DiagnosticStyle style = _styleFor(item);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: <Widget>[
                    Icon(style.icon, color: style.color, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          color: style.color,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppPalette.surfaceDarkHighlight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppPalette.primaryHover),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Observaciones del Técnico',
                  style: TextStyle(
                    color: AppPalette.backgroundLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  notes,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _DiagnosticStyle _styleFor(String item) {
    const Set<String> greenItems = <String>{
      'Mantenimiento general',
      'Calibración sensores',
      'Pruebas',
    };
    const Set<String> yellowItems = <String>{
      'Otros',
    };
    const Set<String> redItems = <String>{
      'Rodillo dañado',
      'Cabezal dañado',
      'Sensor ribbon dañado',
      'Sensor papel dañado',
    };

    if (greenItems.contains(item)) {
      return const _DiagnosticStyle(
        icon: Icons.check_circle_rounded,
        color: AppPalette.success,
      );
    }
    if (yellowItems.contains(item)) {
      return const _DiagnosticStyle(
        icon: Icons.warning_amber_rounded,
        color: AppPalette.warning,
      );
    }
    if (redItems.contains(item)) {
      return const _DiagnosticStyle(
        icon: Icons.error_rounded,
        color: Color(0xFFE57373),
      );
    }
    return const _DiagnosticStyle(
      icon: Icons.info_rounded,
      color: AppPalette.backgroundLight,
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard();

  @override
  Widget build(BuildContext context) {
    const List<String> labels = <String>[
      'Prueba de impresión',
      'Cabezal dañado',
      'Rodillo',
    ];

    return _PremiumCard(
      title: 'Evidencia Capturada',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: labels
            .map(
              (String label) => SizedBox(
                width: 190,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppPalette.surfaceDarkHighlight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppPalette.primaryHover),
                  ),
                  child: Column(
                    children: <Widget>[
                      Container(
                        height: 88,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7B8390),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.image_rounded,
                            color: AppPalette.backgroundLight,
                            size: 34,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppPalette.backgroundLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppPalette.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppPalette.surfaceDarkHighlight),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
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

class _InfoLineCompact extends StatelessWidget {
  const _InfoLineCompact({
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
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white60,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppPalette.backgroundLight,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}

class _ServiceTypeLine extends StatelessWidget {
  const _ServiceTypeLine({
    required this.serviceType,
    required this.visual,
  });

  final String serviceType;
  final _ServiceTypeVisual visual;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 340;

        final Widget badge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: AppPalette.surfaceDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: visual.color.withValues(alpha: 0.55)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(visual.icon, size: 14, color: visual.color),
              const SizedBox(width: 6),
              Text(
                serviceType,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppPalette.backgroundLight,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Tipo de Servicio',
                style: TextStyle(
                  color: Colors.white60,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              badge,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Expanded(
              child: Text(
                'Tipo de Servicio',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white60,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: badge,
                ),
              ),
            ),
          ],
        );
      },
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

class _DiagnosticStyle {
  const _DiagnosticStyle({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;
}

@immutable
class _CounterBarPoint {
  const _CounterBarPoint({
    required this.x,
    required this.label,
    required this.date,
    required this.counter,
    required this.increase,
    required this.color,
  });

  final int x;
  final String label;
  final String date;
  final int counter;
  final int increase;
  final Color color;
}
