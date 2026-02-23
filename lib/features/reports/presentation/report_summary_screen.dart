import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/features/signature/presentation/signature_screen.dart';

class ReportSummaryScreen extends StatelessWidget {
  const ReportSummaryScreen({super.key});

  static const String _serial = '99J882';
  static const String _model = 'ZT610';
  static const String _serviceType = 'Preventivo';
  static const String _counterCurrent = '125,000';
  static const String _counterPrevious = '100,000';
  static const String _darkness = '18.5';
  static const String _labelType = 'Papel TT';

  static const List<String> _selectedDiagnostics = <String>[
    'Mantenimiento general',
    'Pruebas',
    'Cabezal danado',
    'Otros',
  ];

  @override
  Widget build(BuildContext context) {
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
                const _GeneralSummaryCard(
                  serial: _serial,
                  model: _model,
                  serviceType: _serviceType,
                  counter: _counterCurrent,
                  darkness: _darkness,
                  labelType: _labelType,
                ),
                const SizedBox(height: 12),
                const _UsageChartCard(
                  previousCounter: _counterPrevious,
                  currentCounter: _counterCurrent,
                ),
                const SizedBox(height: 12),
                const _DiagnosticCard(
                  diagnostics: _selectedDiagnostics,
                  notes:
                      'Se realizo mantenimiento preventivo completo y pruebas de impresion. '
                      'Se detecto desgaste en cabezal, recomendado reemplazo en siguiente visita.',
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
            border: Border(top: BorderSide(color: AppPalette.surfaceDarkHighlight)),
          ),
          child: SizedBox(
            height: 50,
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SignatureScreen(),
                  ),
                );
              },
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

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      title: '1. Informacion del Equipo',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppPalette.surfaceDarkHighlight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF27364D)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                children: <Widget>[
                  _InfoLineCompact(label: 'Serial', value: serial),
                  const SizedBox(height: 10),
                  _InfoLineCompact(label: 'Modelo', value: '$model - 600dpi'),
                  const SizedBox(height: 10),
                  _InfoLineCompact(label: 'Tipo de Servicio', value: serviceType),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 84,
              margin: const EdgeInsets.symmetric(horizontal: 14),
              color: AppPalette.surfaceDark,
            ),
            Expanded(
              child: Column(
                children: <Widget>[
                  _InfoLineCompact(
                    label: 'Contador Actual',
                    value: '$counter in',
                  ),
                  const SizedBox(height: 10),
                  _InfoLineCompact(label: 'Nivel de Darkness', value: darkness),
                  const SizedBox(height: 10),
                  _InfoLineCompact(label: 'Etiqueta', value: labelType),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageChartCard extends StatelessWidget {
  const _UsageChartCard({
    required this.previousCounter,
    required this.currentCounter,
  });

  final String previousCounter;
  final String currentCounter;

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      title: 'Evolucion de Impresion (Contador)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(
            height: 170,
            child: _UsageBarChart(),
          ),
          const SizedBox(height: 8),
          Text(
            'Servicio Anterior: $previousCounter   |   Actual: $currentCounter',
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
  const _UsageBarChart();

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        maxY: 130,
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
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                const TextStyle style = TextStyle(
                  color: AppPalette.backgroundLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                );
                switch (value.toInt()) {
                  case 0:
                    return const Text('Anterior', style: style);
                  case 1:
                    return const Text('Actual', style: style);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        barGroups: <BarChartGroupData>[
          BarChartGroupData(
            x: 0,
            barRods: <BarChartRodData>[
              BarChartRodData(
                toY: 100,
                color: AppPalette.primaryHover,
                width: 26,
                borderRadius: BorderRadius.circular(6),
              ),
            ],
          ),
          BarChartGroupData(
            x: 1,
            barRods: <BarChartRodData>[
              BarChartRodData(
                toY: 125,
                color: AppPalette.primary,
                width: 26,
                borderRadius: BorderRadius.circular(6),
              ),
            ],
          ),
        ],
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
      title: 'Diagnostico Tecnico',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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
                  'Observaciones del Tecnico',
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
      'Calibracion sensores',
      'Pruebas',
    };
    const Set<String> yellowItems = <String>{
      'Otros',
    };
    const Set<String> redItems = <String>{
      'Rodillo danado',
      'Cabezal danado',
      'Sensor ribbon danado',
      'Sensor papel danado',
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
      'Prueba de impresion',
      'Cabezal danado',
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
            style: const TextStyle(
              color: Colors.white60,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
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

class _DiagnosticStyle {
  const _DiagnosticStyle({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;
}
