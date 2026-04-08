import 'dart:io' as io;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:industrial_service_reports/core/router/app_routes.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/features/reports/providers/capture_provider.dart';
import 'package:industrial_service_reports/features/reports/services/image_capture_service.dart';

class ExpressCaptureScreen extends ConsumerStatefulWidget {
  const ExpressCaptureScreen({
    super.key,
    this.printerId,
    this.assignmentOverride = false,
  });

  final String? printerId;
  final bool assignmentOverride;

  @override
  ConsumerState<ExpressCaptureScreen> createState() =>
      _ExpressCaptureScreenState();
}

class _ExpressCaptureScreenState extends ConsumerState<ExpressCaptureScreen> {
  final TextEditingController _counterController = TextEditingController();
  final TextEditingController _darknessController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.printerId != null) {
        ref.read(captureProvider.notifier).setPrinterId(widget.printerId);
      }
      if (widget.assignmentOverride) {
        ref
            .read(captureProvider.notifier)
            .setAssignmentOverride(value: true);
      }
    });
  }

  @override
  void dispose() {
    _counterController.dispose();
    _darknessController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  _ServiceTypeVisual _serviceTypeVisual(String type) {
    switch (type) {
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
    final CaptureState capture = ref.watch(captureProvider);
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
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<String>>[
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
                    title: 'Información Básica',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Tipo de Servicio',
                          style:
                              theme.textTheme.titleMedium?.copyWith(fontSize: 17),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SegmentedButton<String>(
                            segments: kServiceTypes
                                .map(
                                  (String type) => ButtonSegment<String>(
                                    value: type,
                                    icon: Icon(
                                      _serviceTypeVisual(type).icon,
                                      size: 18,
                                    ),
                                    label: Text(type),
                                  ),
                                )
                                .toList(),
                            selected: <String>{capture.selectedServiceType},
                            onSelectionChanged: (Set<String> values) {
                              ref
                                  .read(captureProvider.notifier)
                                  .setServiceType(values.first);
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        _SelectedServiceTypeBadge(
                          type: capture.selectedServiceType,
                          visual: _serviceTypeVisual(capture.selectedServiceType),
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
                              Expanded(child: _buildCounterField()),
                              const SizedBox(width: 12),
                              Expanded(child: _buildDarknessField()),
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
                          style:
                              theme.textTheme.titleMedium?.copyWith(fontSize: 17),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: kLabelTypes
                              .map(
                                (String type) => ChoiceChip(
                                  label: Text(type),
                                  selected: capture.selectedLabelType == type,
                                  onSelected: (_) {
                                    ref
                                        .read(captureProvider.notifier)
                                        .setLabelType(type);
                                  },
                                  selectedColor: AppPalette.primary,
                                  backgroundColor:
                                      AppPalette.surfaceDarkHighlight,
                                  labelStyle: const TextStyle(
                                    color: AppPalette.backgroundLight,
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
                      itemCount: kChecklistItems.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisExtent: isWide ? 52 : 48,
                        mainAxisSpacing: 2,
                        crossAxisSpacing: 8,
                      ),
                      itemBuilder: (BuildContext context, int index) {
                        final String item = kChecklistItems[index];
                        final bool currentValue =
                            capture.checkValues[item] ?? false;

                        return InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            ref
                                .read(captureProvider.notifier)
                                .toggleCheckItem(item);
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
                                    ref
                                        .read(captureProvider.notifier)
                                        .toggleCheckItem(item);
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
                    child: _PhotoEvidenceSection(
                      photoPaths: capture.photoPaths,
                      onCameraPressed: _onCameraPressed,
                      onGalleryPressed: _onGalleryPressed,
                      onRemovePhoto: _onRemovePhoto,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Observaciones',
                    child: TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Notas adicionales del técnico',
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
            border:
                Border(top: BorderSide(color: AppPalette.surfaceDarkHighlight)),
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

  Future<void> _onCameraPressed() async {
    final String? path = await ImageCaptureService.captureFromCamera();
    if (path != null) {
      ref.read(captureProvider.notifier).addPhotoPaths([path]);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo acceder a la cámara'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onGalleryPressed() async {
    final List<String> paths =
        await ImageCaptureService.selectMultipleFromGallery();
    if (paths.isNotEmpty) {
      ref.read(captureProvider.notifier).addPhotoPaths(paths);
    }
  }

  void _onRemovePhoto(int index) {
    ref.read(captureProvider.notifier).removePhotoAt(index);
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
      return 'Ingrese un número válido';
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
      return 'Ingrese un número válido';
    }
    return null;
  }

  void _onContinuePressed() {
    final bool formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) {
      _showValidationSnackBar('Complete los campos obligatorios');
      return;
    }

    final CaptureState capture = ref.read(captureProvider);
    final bool hasTechnicalSelection =
        capture.checkValues.values.any((bool value) => value);
    if (!hasTechnicalSelection) {
      _showValidationSnackBar('Debe seleccionar al menos una opción tecnica');
      return;
    }

    if (!capture.hasPhotos) {
      _showValidationSnackBar('Se requiere mínimo 1 foto de evidencia');
      return;
    }

    ref.read(captureProvider.notifier).commitFormValues(
          counter: _counterController.text,
          darkness: _darknessController.text,
          notes: _notesController.text,
        );

    context.pushNamed(AppRoutes.reportSummary);
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
            'Se perderán los cambios no guardados. Desea cancelar este reporte?',
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
              child: const Text('Sí, cancelar'),
            ),
          ],
        );
      },
    );

    if (shouldCancel == true && mounted) {
      ref.read(captureProvider.notifier).resetCapture();
      context.pop();
    }
  }
}

class _SelectedServiceTypeBadge extends StatelessWidget {
  const _SelectedServiceTypeBadge({
    required this.type,
    required this.visual,
  });

  final String type;
  final _ServiceTypeVisual visual;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppPalette.surfaceDarkHighlight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: visual.color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(visual.icon, size: 16, color: visual.color),
          const SizedBox(width: 6),
          Text(
            type,
            style: const TextStyle(
              color: AppPalette.backgroundLight,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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

class _PhotoEvidenceSection extends StatelessWidget {
  const _PhotoEvidenceSection({
    required this.photoPaths,
    required this.onCameraPressed,
    required this.onGalleryPressed,
    required this.onRemovePhoto,
  });

  final List<String> photoPaths;
  final VoidCallback onCameraPressed;
  final VoidCallback onGalleryPressed;
  final void Function(int) onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (photoPaths.isEmpty)
          SizedBox(
            height: 110,
            child: CustomPaint(
              painter: _DashedRectPainter(
                color: AppPalette.surfaceDarkHighlight,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const <Widget>[
                    Icon(Icons.add_photo_alternate_rounded,
                        color: Colors.white38, size: 32),
                    SizedBox(height: 6),
                    Text(
                      'Mínimo 1 foto de evidencia requerida',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          _PhotoGrid(
            photoPaths: photoPaths,
            onRemovePhoto: onRemovePhoto,
          ),
        const SizedBox(height: 14),
        if (photoPaths.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${photoPaths.length} foto${photoPaths.length == 1 ? '' : 's'} adjunta${photoPaths.length == 1 ? '' : 's'}',
              style: const TextStyle(
                color: AppPalette.success,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: onCameraPressed,
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text(
                  'Tomar Foto',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: FilledButton.tonalIcon(
                onPressed: onGalleryPressed,
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text(
                  'Subir de Galería',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.photoPaths,
    required this.onRemovePhoto,
  });

  final List<String> photoPaths;
  final void Function(int) onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: photoPaths.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1.0,
      ),
      itemBuilder: (BuildContext context, int index) {
        return _PhotoThumbnail(
          filePath: photoPaths[index],
          onRemove: () => onRemovePhoto(index),
        );
      },
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({
    required this.filePath,
    required this.onRemove,
  });

  final String filePath;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            io.File(filePath),
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: AppPalette.surfaceDarkHighlight,
              child: const Icon(
                Icons.broken_image_rounded,
                color: Colors.white38,
              ),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
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
