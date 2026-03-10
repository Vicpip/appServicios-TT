import 'package:flutter/material.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/features/sync/presentation/sync_history_screen.dart';

class SyncDashboardScreen extends StatefulWidget {
  const SyncDashboardScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  State<SyncDashboardScreen> createState() => _SyncDashboardScreenState();
}

class _SyncDashboardScreenState extends State<SyncDashboardScreen> {
  bool _isSyncing = false;

  Future<void> _startSync() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    await Future<void>.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    setState(() {
      _isSyncing = false;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: <Widget>[
            Icon(Icons.check_circle_rounded, color: AppPalette.success),
            SizedBox(width: 10),
            Text(
              'Sincronización completada con éxito',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        backgroundColor: AppPalette.successDark,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const <Widget>[
            Icon(Icons.sync_rounded, size: 22),
            SizedBox(width: 8),
            Text('Centro de Sincronización'),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Historial de sincronizaciones',
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SyncHistoryScreen(database: widget.database),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // ── Estado de conexión ────────────────────────────────
                    _NetworkStatusCard(isSyncing: _isSyncing),
                    const SizedBox(height: 20),

                    // ── Cola local (por subir) ────────────────────────────
                    const _SectionLabel(text: 'EN LA COLA LOCAL (POR SUBIR)'),
                    const SizedBox(height: 8),
                    Card(
                      color: AppPalette.surfaceDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(
                            color: AppPalette.surfaceDarkHighlight),
                      ),
                      child: Column(
                        children: const <Widget>[
                          _SyncItem(
                            icon: Icons.upload_file_rounded,
                            label: 'Reportes de Servicio',
                            count: 3,
                            badge: _BadgeType.pending,
                          ),
                          _Divider(),
                          _SyncItem(
                            icon: Icons.image_rounded,
                            label: 'Evidencias Fotográficas',
                            count: 12,
                            badge: _BadgeType.pending,
                          ),
                          _Divider(),
                          _SyncItem(
                            icon: Icons.draw_rounded,
                            label: 'Firmas de Clientes',
                            count: 2,
                            badge: _BadgeType.pending,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Disponible en servidor (por bajar) ────────────────
                    const _SectionLabel(
                        text: 'DISPONIBLE EN SERVIDOR (POR DESCARGAR)'),
                    const SizedBox(height: 8),
                    Card(
                      color: AppPalette.surfaceDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(
                            color: AppPalette.surfaceDarkHighlight),
                      ),
                      child: Column(
                        children: const <Widget>[
                          _SyncItem(
                            icon: Icons.cloud_download_rounded,
                            label: 'Nuevas Asignaciones',
                            count: 5,
                            badge: _BadgeType.newItem,
                          ),
                          _Divider(),
                          _SyncItem(
                            icon: Icons.list_alt_rounded,
                            label: 'Actualización de Catálogos',
                            count: 0,
                            badge: _BadgeType.upToDate,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Botón principal fijo ──────────────────────────────────────
            _SyncButton(isSyncing: _isSyncing, onTap: _startSync),
          ],
        ),
      ),
    );
  }
}

// ─── Red / Conexión ───────────────────────────────────────────────────────────

class _NetworkStatusCard extends StatelessWidget {
  const _NetworkStatusCard({required this.isSyncing});

  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppPalette.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSyncing ? AppPalette.primary : AppPalette.success,
          width: 1.4,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Row(
          children: <Widget>[
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: isSyncing
                  ? const SizedBox(
                      key: ValueKey<String>('loading'),
                      width: 52,
                      height: 52,
                      child: CircularProgressIndicator(
                        color: AppPalette.primary,
                        strokeWidth: 3,
                      ),
                    )
                  : Container(
                      key: const ValueKey<String>('wifi'),
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppPalette.successDark,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.wifi_rounded,
                        color: AppPalette.success,
                        size: 28,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    isSyncing ? 'Sincronizando...' : 'Conectado al Servidor Local',
                    style: const TextStyle(
                      color: AppPalette.backgroundLight,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Última sincronización exitosa: Hoy, 07:30 AM',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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
}

// ─── Etiqueta de sección ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.blueGrey,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ─── Tipos de badge ───────────────────────────────────────────────────────────

enum _BadgeType { pending, newItem, upToDate }

// ─── Item de sincronización ───────────────────────────────────────────────────

class _SyncItem extends StatelessWidget {
  const _SyncItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.badge,
  });

  final IconData icon;
  final String label;
  final int count;
  final _BadgeType badge;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppPalette.surfaceDarkHighlight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: AppPalette.backgroundLight),
      ),
      title: Text(
        count > 0 ? '$label ($count)' : label,
        style: const TextStyle(
          color: AppPalette.backgroundLight,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
      trailing: _Badge(type: badge),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.type});

  final _BadgeType type;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color border, Color text, String label) = switch (type) {
      _BadgeType.pending => (
          AppPalette.warningDark,
          AppPalette.warning,
          AppPalette.warning,
          'Pendiente',
        ),
      _BadgeType.newItem => (
          AppPalette.successDark,
          AppPalette.success,
          AppPalette.success,
          'Nuevo',
        ),
      _BadgeType.upToDate => (
          AppPalette.surfaceDarkHighlight,
          Colors.white30,
          Colors.white60,
          'Al día',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: AppPalette.surfaceDarkHighlight,
    );
  }
}

// ─── Botón de sincronización ──────────────────────────────────────────────────

class _SyncButton extends StatelessWidget {
  const _SyncButton({
    required this.isSyncing,
    required this.onTap,
  });

  final bool isSyncing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: AppPalette.surfaceDark,
        border: Border(top: BorderSide(color: AppPalette.surfaceDarkHighlight)),
      ),
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: FilledButton(
          onPressed: isSyncing ? null : onTap,
          child: isSyncing
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppPalette.backgroundLight,
                        strokeWidth: 2.5,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Sincronizando...',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(Icons.sync_rounded, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'INICIAR SINCRONIZACIÓN MASIVA',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
