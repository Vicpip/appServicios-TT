import 'package:flutter/material.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/features/qr_scanner/presentation/qr_scanner_screen.dart';

class MainDashboardScreen extends StatelessWidget {
  const MainDashboardScreen({super.key});

  static const String _mockUserName = 'Juan Perez';
  static const String _mockTechId = '#T-8492';
  static const int _pendingSyncCount = 3;
  static const String _lastSyncText = 'Hoy 08:30 AM';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 88,
        backgroundColor: AppPalette.surfaceDark,
        titleSpacing: 20,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              children: <Widget>[
                const CircleAvatar(
                  radius: 22,
                  backgroundColor: AppPalette.surfaceDarkHighlight,
                  child: Icon(
                    Icons.person,
                    color: AppPalette.backgroundLight,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _mockUserName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Tech ID: $_mockTechId',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: AppPalette.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ONLINE',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 14,
                        color: AppPalette.success,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Ultima sync: $_lastSyncText',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                children: <Widget>[
                  _PendingSyncBanner(
                    pendingCount: _pendingSyncCount,
                    onSyncTap: () =>
                        _showNavigationSnackBar(context, 'Sincronizar'),
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: isLandscape ? 3 : 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: isLandscape ? 2.05 : 1.85,
                    children: <Widget>[
                      DashboardButton(
                        title: 'Escanear QR',
                        icon: Icons.qr_code_scanner_rounded,
                        isHighlighted: true,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const QrScannerScreen(),
                            ),
                          );
                        },
                      ),
                      DashboardButton(
                        title: 'Pendientes Sync',
                        icon: Icons.sync_problem_rounded,
                        onTap: () =>
                            _showNavigationSnackBar(context, 'Pendientes Sync'),
                      ),
                      DashboardButton(
                        title: 'Alertas Riesgo',
                        icon: Icons.warning_amber_rounded,
                        onTap: () =>
                            _showNavigationSnackBar(context, 'Alertas Riesgo'),
                      ),
                      DashboardButton(
                        title: 'Clientes',
                        icon: Icons.business_rounded,
                        onTap: () =>
                            _showNavigationSnackBar(context, 'Clientes'),
                      ),
                      DashboardButton(
                        title: 'Polizas',
                        icon: Icons.assignment_rounded,
                        onTap: () =>
                            _showNavigationSnackBar(context, 'Polizas'),
                      ),
                      DashboardButton(
                        title: 'Impresoras',
                        icon: Icons.print_rounded,
                        onTap: () =>
                            _showNavigationSnackBar(context, 'Impresoras'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showNavigationSnackBar(BuildContext context, String destination) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ira a la pantalla de $destination'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _PendingSyncBanner extends StatelessWidget {
  const _PendingSyncBanner({
    required this.pendingCount,
    required this.onSyncTap,
  });

  final int pendingCount;
  final VoidCallback onSyncTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppPalette.warningDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.warning, width: 1.2),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.sync_problem_rounded, color: AppPalette.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tienes $pendingCount reportes pendientes de sincronizar',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppPalette.backgroundLight,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: onSyncTap,
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.warning,
              foregroundColor: AppPalette.backgroundDark,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            child: const Text('Ir a Sincronizar'),
          ),
        ],
      ),
    );
  }
}

class DashboardButton extends StatelessWidget {
  const DashboardButton({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.isHighlighted = false,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor =
        isHighlighted ? AppPalette.primary : AppPalette.surfaceDark;
    final Color foregroundColor =
        AppPalette.backgroundLight;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double iconSize =
                (constraints.maxHeight * 0.28).clamp(20.0, 34.0);
            final double fontSize =
                (constraints.maxHeight * 0.11).clamp(11.0, 15.0);
            final double verticalGap =
                (constraints.maxHeight * 0.05).clamp(4.0, 10.0);
            final double padding =
                (constraints.maxHeight * 0.10).clamp(8.0, 14.0);

            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isHighlighted
                      ? AppPalette.primaryHover
                      : AppPalette.surfaceDarkHighlight,
                  width: 1.4,
                ),
              ),
              padding: EdgeInsets.all(padding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(icon, size: iconSize, color: foregroundColor),
                  SizedBox(height: verticalGap),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: foregroundColor,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
