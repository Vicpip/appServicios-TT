import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/features/reports/presentation/report_summary_screen.dart';

class ExpressCaptureScreen extends StatefulWidget {
  const ExpressCaptureScreen({super.key});

  @override
  State<ExpressCaptureScreen> createState() => _ExpressCaptureScreenState();
}

class _ExpressCaptureScreenState extends State<ExpressCaptureScreen> {
  static const List<String> _serviceTypes = <String>[
    'Preventivo',
    'Correctivo',
    'Diagnostico',
    'Instalacion',
  ];

  static const List<String> _labelTypes = <String>[
    'Papel TT',
    'Papel TD',
    'Plastica (BOPP/Poliester)',
  ];

  static const List<String> _checklistItems = <String>[
    'Mantenimiento general',
    'Calibracion sensores',
    'Rodillo danado',
    'Cabezal danado',
    'Sensor ribbon danado',
    'Sensor papel danado',
    'Pruebas',
    'Otros',
  ];

  final TextEditingController _counterController = TextEditingController();
  final TextEditingController _darknessController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final Map<String, bool> _checkValues = <String, bool>{};

  String _selectedServiceType = _serviceTypes.first;
  String _selectedLabelType = _labelTypes.first;

  @override
  void initState() {
    super.initState();
    for (final String item in _checklistItems) {
      _checkValues[item] = false;
    }
  }

  @override
  void dispose() {
    _counterController.dispose();
    _darknessController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _confirmCancelReport,
        ),
        title: const Text('Captura de Servicio'),
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'cancel_report') {
                _confirmCancelReport();
              }
            },
            itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'cancel_report',
                child: Text(
                  'Cancelar Reporte',
                  style: TextStyle(color: Color(0xFFE57373)),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                children: <Widget>[
                _SectionCard(
                  title: 'Informacion Basica',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Tipo de Servicio',
                        style: theme.textTheme.titleMedium?.copyWith(fontSize: 17),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SegmentedButton<String>(
                          segments: _serviceTypes
                              .map(
                                (String type) => ButtonSegment<String>(
                                  value: type,
                                  label: Text(type),
                                ),
                              )
                              .toList(),
                          selected: <String>{_selectedServiceType},
                          onSelectionChanged: (Set<String> values) {
                            setState(() {
                              _selectedServiceType = values.first;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Contador de Pulgadas *',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 17,
                          color: AppPalette.primary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (isWide)
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _buildCounterField(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDarknessField(),
                            ),
                          ],
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _buildCounterField(),
                            const SizedBox(height: 12),
                            _buildDarknessField(),
                          ],
                        ),
                      const SizedBox(height: 18),
                      Text(
                        'Tipo de Etiqueta',
                        style: theme.textTheme.titleMedium?.copyWith(fontSize: 17),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _labelTypes
                            .map(
                              (String type) => ChoiceChip(
                                label: Text(type),
                                selected: _selectedLabelType == type,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedLabelType = type;
                                  });
                                },
                                selectedColor: AppPalette.primary,
                                backgroundColor: AppPalette.surfaceDarkHighlight,
                                labelStyle: TextStyle(
                                  color: _selectedLabelType == type
                                      ? AppPalette.backgroundLight
                                      : AppPalette.backgroundLight,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Revision Tecnica',
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _checklistItems.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisExtent: isWide ? 52 : 48,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 8,
                    ),
                    itemBuilder: (BuildContext context, int index) {
                      final String item = _checklistItems[index];
                      final bool currentValue = _checkValues[item] ?? false;

                      return InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          setState(() {
                            _checkValues[item] = !currentValue;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Row(
                            children: <Widget>[
                              Checkbox(
                                value: currentValue,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                onChanged: (bool? value) {
                                  setState(() {
                                    _checkValues[item] = value ?? false;
                                  });
                                },
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: isWide ? 16 : 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Evidencia Fotografica',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(
                        height: 130,
                        child: CustomPaint(
                          painter: _DashedRectPainter(
                            color: AppPalette.surfaceDarkHighlight,
                          ),
                          child: const Center(
                            child: Text(
                              'Minimo 1 foto de prueba de impresion requerida',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          SizedBox(
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: _showMockUploadSnackBar,
                              icon: const Icon(Icons.photo_camera_rounded),
                              label: const Text(
                                'Tomar Foto (Camara)',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 48,
                            child: FilledButton.tonalIcon(
                              onPressed: _showMockUploadSnackBar,
                              icon: const Icon(Icons.photo_library_rounded),
                              label: const Text(
                                'Subir de Galeria',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Observaciones',
                    child: TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Notas adicionales del tecnico',
                      ),
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
              onPressed: _onContinuePressed,
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.primary,
                foregroundColor: AppPalette.backgroundLight,
              ),
              child: const Text(
                'Revisar Reporte',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMockUploadSnackBar() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Funcion de evidencia en modo mock'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildCounterField() {
    return TextFormField(
      controller: _counterController,
      keyboardType: TextInputType.number,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      decoration: const InputDecoration(
        hintText: 'Ejemplo: 125000',
        prefixIcon: Icon(Icons.confirmation_number_rounded),
      ),
      validator: _validateCounter,
    );
  }

  Widget _buildDarknessField() {
    return TextFormField(
      controller: _darknessController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      decoration: const InputDecoration(
        labelText: 'Nivel de Darkness',
        hintText: 'Ejemplo: 18.5',
        prefixIcon: Icon(Icons.brightness_medium),
      ),
      validator: _validateDarkness,
    );
  }

  String? _validateCounter(String? value) {
    final String trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Campo obligatorio';
    }
    if (int.tryParse(trimmed) == null) {
      return 'Ingrese un numero valido';
    }
    return null;
  }

  String? _validateDarkness(String? value) {
    final String trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final String normalized = trimmed.replaceAll(',', '.');
    if (double.tryParse(normalized) == null) {
      return 'Ingrese un numero valido';
    }
    return null;
  }

  void _onContinuePressed() {
    final bool formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) {
      _showValidationSnackBar('Complete los campos obligatorios');
      return;
    }

    final bool hasTechnicalSelection = _checkValues.values.any(
      (bool value) => value,
    );
    if (!hasTechnicalSelection) {
      _showValidationSnackBar('Debe seleccionar al menos una opcion tecnica');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ReportSummaryScreen(),
      ),
    );
  }

  void _showValidationSnackBar(String message) {
    final ThemeData theme = Theme.of(context);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: theme.colorScheme.error,
        content: Text(
          message,
          style: TextStyle(color: theme.colorScheme.onError),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmCancelReport() async {
    final bool? shouldCancel = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Cancelar Reporte'),
          content: const Text(
            'Se perderan los cambios no guardados. Desea cancelar este reporte?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Seguir editando'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Si, cancelar'),
            ),
          ],
        );
      },
    );

    if (shouldCancel == true && mounted) {
      Navigator.of(context).pop();
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
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
                fontSize: 21,
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

class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const double dashWidth = 8;
    const double dashSpace = 5;
    const double stroke = 1.6;

    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    void drawDashedLine(Offset start, Offset end) {
      final double dx = end.dx - start.dx;
      final double dy = end.dy - start.dy;
      final double distance = math.sqrt(dx * dx + dy * dy);
      if (distance == 0) return;
      final double vx = dx / distance;
      final double vy = dy / distance;
      double progress = 0;

      while (progress < distance) {
        final double next = (progress + dashWidth).clamp(0, distance);
        canvas.drawLine(
          Offset(start.dx + vx * progress, start.dy + vy * progress),
          Offset(start.dx + vx * next, start.dy + vy * next),
          paint,
        );
        progress += dashWidth + dashSpace;
      }
    }

    const double inset = stroke;
    final Offset topLeft = const Offset(inset, inset);
    final Offset topRight = Offset(size.width - inset, inset);
    final Offset bottomLeft = Offset(inset, size.height - inset);
    final Offset bottomRight = Offset(size.width - inset, size.height - inset);

    drawDashedLine(topLeft, topRight);
    drawDashedLine(topRight, bottomRight);
    drawDashedLine(bottomRight, bottomLeft);
    drawDashedLine(bottomLeft, topLeft);
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      oldDelegate.color != color;
}
