import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:industrial_service_reports/core/router/app_routes.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/features/auth/providers/session_provider.dart';

class MainDashboardScreen extends ConsumerWidget {
  const MainDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionState session = ref.watch(sessionProvider);
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
                InkWell(
                  borderRadius: BorderRadius.circular(34),
                  onTap: () => context.pushNamed(AppRoutes.profile),
                  child: const CircleAvatar(
                    radius: 22,
                    backgroundColor: AppPalette.surfaceDarkHighlight,
                    child: Icon(
                      Icons.person,
                      color: AppPalette.backgroundLight,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.pushNamed(AppRoutes.profile),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        session.userName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Tech ID: ${session.techId}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
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
                      decoration: BoxDecoration(
                        color: session.isOnline
                            ? AppPalette.success
                            : AppPalette.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      session.isOnline ? 'ONLINE' : 'OFFLINE',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 14,
                        color: session.isOnline
                            ? AppPalette.success
                            : AppPalette.warning,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Ultima sync: ${session.lastSyncText}',
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
                    pendingCount: session.pendingSyncCount,
                    onSyncTap: () => context.pushNamed(AppRoutes.sync),
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
                        onTap: () => context.pushNamed(AppRoutes.qrScanner),
                      ),
                      DashboardButton(
                        title: 'Pendientes Sync',
                        icon: Icons.sync_problem_rounded,
                        onTap: () => context.pushNamed(AppRoutes.sync),
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
                        onTap: () => context.pushNamed(AppRoutes.clients),
                      ),
                      DashboardButton(
                        title: 'Polizas',
                        icon: Icons.assignment_rounded,
                        onTap: () => context.pushNamed(AppRoutes.policies),
                      ),
                      DashboardButton(
                        title: 'Impresoras',
                        icon: Icons.print_rounded,
                        onTap: () => context.pushNamed(AppRoutes.printerInventory),
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
    final Color foregroundColor = AppPalette.backgroundLight;

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
