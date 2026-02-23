import 'package:flutter/material.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/features/reports/presentation/express_capture_screen.dart';

@immutable
class PrinterSummary {
  const PrinterSummary({
    required this.serialNumber,
    required this.modelWithDpi,
    required this.clientName,
    required this.plantName,
    required this.areaName,
    required this.hasActivePolicy,
  });

  final String serialNumber;
  final String modelWithDpi;
  final String clientName;
  final String plantName;
  final String areaName;
  final bool hasActivePolicy;
}

class PrinterConfirmationScreen extends StatelessWidget {
  const PrinterConfirmationScreen({
    super.key,
    required this.printer,
  });

  final PrinterSummary printer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmar Equipo'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: _ConfirmationCard(printer: printer),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmationCard extends StatelessWidget {
  const _ConfirmationCard({
    required this.printer,
  });

  final PrinterSummary printer;

  @override
  Widget build(BuildContext context) {
    final bool compact = MediaQuery.of(context).size.width < 720;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppPalette.surfaceDarkHighlight, AppPalette.surfaceDark],
        ),
        border: Border.all(color: AppPalette.surfaceDarkHighlight, width: 1.2),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0xAA000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.print_rounded,
                  size: 30,
                  color: AppPalette.backgroundLight,
                ),
                const Spacer(),
                _PolicyChip(hasActivePolicy: printer.hasActivePolicy),
              ],
            ),
            const SizedBox(height: 10),
            _SerialLine(serialNumber: printer.serialNumber),
            const SizedBox(height: 4),
            Text(
              printer.modelWithDpi,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppPalette.backgroundLight,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            _LocationPanel(printer: printer, compact: compact),
            const SizedBox(height: 14),
            _ActionRow(
              compact: compact,
              onCancel: () => Navigator.of(context).pop(),
              onDetail: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Abrira el detalle completo del equipo'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              onCreateReport: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ExpressCaptureScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicyChip extends StatelessWidget {
  const _PolicyChip({
    required this.hasActivePolicy,
  });

  final bool hasActivePolicy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: hasActivePolicy
            ? AppPalette.success
            : AppPalette.surfaceDarkHighlight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasActivePolicy
              ? AppPalette.successDark
              : AppPalette.primaryHover,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            hasActivePolicy ? Icons.verified_rounded : Icons.sell_rounded,
            color: AppPalette.backgroundLight,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            hasActivePolicy ? 'Poliza Activa' : 'Sin Poliza',
            style: const TextStyle(
              color: AppPalette.backgroundLight,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _SerialLine extends StatelessWidget {
  const _SerialLine({
    required this.serialNumber,
  });

  final String serialNumber;

  @override
  Widget build(BuildContext context) {
    final String compact = serialNumber.replaceAll(' ', '');
    final String prefix =
        compact.length > 6 ? compact.substring(0, compact.length - 6) : '';
    final String suffix =
        compact.length > 6 ? compact.substring(compact.length - 6) : compact;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: RichText(
        text: TextSpan(
          children: <TextSpan>[
            TextSpan(
              text: prefix,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 42,
                letterSpacing: 0.9,
              ),
            ),
            const TextSpan(text: ' '),
            TextSpan(
              text: suffix,
              style: const TextStyle(
                color: AppPalette.primary,
                fontWeight: FontWeight.w900,
                fontSize: 46,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationPanel extends StatelessWidget {
  const _LocationPanel({
    required this.printer,
    required this.compact,
  });

  final PrinterSummary printer;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(12);

    if (compact) {
      return Container(
        decoration: BoxDecoration(
          color: AppPalette.backgroundDark,
          borderRadius: radius,
          border: Border.all(color: AppPalette.surfaceDarkHighlight),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          children: <Widget>[
            _LocationCell(
              icon: Icons.business_rounded,
              label: 'Cliente',
              value: printer.clientName,
            ),
            const SizedBox(height: 12),
            _LocationCell(
              icon: Icons.factory_rounded,
              label: 'Planta',
              value: printer.plantName,
            ),
            const SizedBox(height: 12),
            _LocationCell(
              icon: Icons.place_rounded,
              label: 'Area',
              value: printer.areaName,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppPalette.backgroundDark,
        borderRadius: radius,
        border: Border.all(color: AppPalette.surfaceDarkHighlight),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _LocationCell(
              icon: Icons.business_rounded,
              label: 'Cliente',
              value: printer.clientName,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.chevron_right_rounded,
              color: Colors.white70,
              size: 24,
            ),
          ),
          Expanded(
            child: _LocationCell(
              icon: Icons.factory_rounded,
              label: 'Planta',
              value: printer.plantName,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.chevron_right_rounded,
              color: Colors.white70,
              size: 24,
            ),
          ),
          Expanded(
            child: _LocationCell(
              icon: Icons.place_rounded,
              label: 'Area',
              value: printer.areaName,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationCell extends StatelessWidget {
  const _LocationCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Icon(icon, color: const Color(0xFFB8C3D3), size: 22),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppPalette.backgroundLight,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.compact,
    required this.onCancel,
    required this.onDetail,
    required this.onCreateReport,
  });

  final bool compact;
  final VoidCallback onCancel;
  final VoidCallback onDetail;
  final VoidCallback onCreateReport;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        children: <Widget>[
          _CreateButton(onPressed: onCreateReport, fullWidth: true),
          const SizedBox(height: 10),
          _DetailButton(onPressed: onDetail, fullWidth: true),
          const SizedBox(height: 10),
          _CancelButton(onPressed: onCancel, fullWidth: true),
        ],
      );
    }

    return Row(
      children: <Widget>[
        Expanded(child: _CancelButton(onPressed: onCancel)),
        const SizedBox(width: 12),
        Expanded(child: _DetailButton(onPressed: onDetail)),
        const SizedBox(width: 12),
        Expanded(child: _CreateButton(onPressed: onCreateReport)),
      ],
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton({
    required this.onPressed,
    this.fullWidth = false,
  });

  final VoidCallback onPressed;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppPalette.surfaceDarkHighlight, width: 1.5),
          foregroundColor: AppPalette.backgroundLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text(
          'Cancelar',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
    );
  }
}

class _DetailButton extends StatelessWidget {
  const _DetailButton({
    required this.onPressed,
    this.fullWidth = false,
  });

  final VoidCallback onPressed;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: 50,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.surfaceDarkHighlight,
          foregroundColor: AppPalette.backgroundLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text(
          'Ver Detalle',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({
    required this.onPressed,
    this.fullWidth = false,
  });

  final VoidCallback onPressed;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: 50,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
        label: const Text(
          'Crear Reporte',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.primary,
          foregroundColor: AppPalette.backgroundLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
