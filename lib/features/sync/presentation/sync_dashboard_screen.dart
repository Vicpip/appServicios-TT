import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:industrial_service_reports/core/constants.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/features/auth/services/auth_service.dart';
import 'package:industrial_service_reports/features/sync/presentation/sync_history_screen.dart';
import 'package:industrial_service_reports/features/sync/services/sync_service.dart';

class SyncDashboardScreen extends StatefulWidget {
  const SyncDashboardScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  State<SyncDashboardScreen> createState() => _SyncDashboardScreenState();
}

class _SyncDashboardScreenState extends State<SyncDashboardScreen> {
  bool _isSyncing = false;
  String _progressMessage = '';
  int _pendingReports = 0;
  int _pendingFiles = 0;
  int _pendingSignatures = 0;
  String? _lastReportError;
  String? _lastFileError;
  String? _lastSignatureError;
  bool _loading = true;
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();
    _loadSyncData();
  }

  Future<void> _loadSyncData() async {
    // Fetch pending items (for counts) and any item with a recorded error
    // (pending or failed) to surface the last failure message in the UI.
    final List<SyncQueueData> allPending =
        await (widget.database.select(widget.database.syncQueue)
              ..where((q) => q.estadoPeticion.equals('pending')))
            .get();

    final List<SyncQueueData> withErrors =
        await (widget.database.select(widget.database.syncQueue)
              ..where((q) => q.lastError.isNotNull())
              ..where((q) => q.estadoPeticion.isIn(<String>['pending', 'failed']))
              ..orderBy(<OrderingTerm Function(SyncQueue)>[
                (q) => OrderingTerm.desc(q.updatedAt),
              ]))
            .get();

    int reports = 0, files = 0, signatures = 0;
    for (final SyncQueueData item in allPending) {
      if (item.entityType == 'report') {
        reports++;
      } else if (item.entityType == 'file') {
        files++;
      } else if (item.entityType == 'signature') {
        signatures++;
      }
    }

    // Pick the most-recent error per entity type.
    String? reportError, fileError, signatureError;
    for (final SyncQueueData item in withErrors) {
      if (item.entityType == 'report' && reportError == null) {
        reportError = item.lastError;
      } else if (item.entityType == 'file' && fileError == null) {
        fileError = item.lastError;
      } else if (item.entityType == 'signature' && signatureError == null) {
        signatureError = item.lastError;
      }
    }

    // Get last sync from users table
    final List<User> users =
        await widget.database.select(widget.database.users).get();
    DateTime? lastSync;
    for (final User u in users) {
      if (u.lastSyncAt != null) {
        if (lastSync == null || u.lastSyncAt!.isAfter(lastSync)) {
          lastSync = u.lastSyncAt;
        }
      }
    }

    if (mounted) {
      setState(() {
        _pendingReports = reports;
        _pendingFiles = files;
        _pendingSignatures = signatures;
        _lastReportError = reportError;
        _lastFileError = fileError;
        _lastSignatureError = signatureError;
        _lastSync = lastSync;
        _loading = false;
      });
    }
  }

  String _formatLastSync(DateTime dt) {
    const List<String> months = <String>[
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];
    final String day = dt.day.toString().padLeft(2, '0');
    final String month = months[dt.month - 1];
    final String year = dt.year.toString();
    final String hour = dt.hour.toString().padLeft(2, '0');
    final String minute = dt.minute.toString().padLeft(2, '0');
    return '$day $month $year, $hour:$minute';
  }

  Future<void> _startSync() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
      _progressMessage = 'Conectando al servidor…';
    });

    try {
      final SyncResult result = await SyncService(widget.database).runSync(
        baseUrl: kServerBaseUrlDevice,
        onProgress: (String msg) {
          if (mounted) setState(() => _progressMessage = msg);
        },
      );

      if (!mounted) return;

      // Capture messenger before async gap
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

      // Refresh pending counts after sync
      await _loadSyncData();

      setState(() {
        _isSyncing = false;
        _progressMessage = '';
      });

      final String message;
      final Color bgColor;
      final IconData iconData;
      if (result.processed == 0) {
        message = 'No hay elementos pendientes para sincronizar';
        bgColor = AppPalette.surfaceDarkHighlight;
        iconData = Icons.check_circle_rounded;
      } else if (result.failed == 0) {
        message =
            'Completado: ${result.succeeded} enviado${result.succeeded != 1 ? 's' : ''}';
        bgColor = AppPalette.successDark;
        iconData = Icons.check_circle_rounded;
      } else {
        message =
            '${result.succeeded} OK · ${result.failed} fallido${result.failed != 1 ? 's' : ''} (reintento automático)';
        bgColor = AppPalette.warningDark;
        iconData = Icons.warning_rounded;
      }

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: <Widget>[
              Icon(iconData,
                  color: result.failed == 0
                      ? AppPalette.success
                      : AppPalette.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          backgroundColor: bgColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } on TokenExpiredException {
      if (!mounted) return;

      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

      setState(() {
        _isSyncing = false;
        _progressMessage = '';
      });

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: const Row(
            children: <Widget>[
              Icon(Icons.lock_clock_rounded, color: Colors.orangeAccent),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sesión expirada — inicia sesión para sincronizar.\nPuedes seguir usando la app sin conexión.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF7C4D00),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      // Capture messenger before setState (which may trigger rebuilds)
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

      setState(() {
        _isSyncing = false;
        _progressMessage = '';
      });

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: <Widget>[
              const Icon(Icons.error_rounded, color: Colors.red),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Error de red: $e',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade900,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String lastSyncText = _lastSync != null
        ? 'Última sincronización exitosa: ${_formatLastSync(_lastSync!)}'
        : 'Sin sincronización aún';

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
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // ── Estado de conexión ────────────────────────────────
                          _NetworkStatusCard(
                            isSyncing: _isSyncing,
                            lastSyncText: _isSyncing && _progressMessage.isNotEmpty
                                ? _progressMessage
                                : lastSyncText,
                          ),
                          const SizedBox(height: 20),

                          // ── Cola local (por subir) ────────────────────────────
                          const _SectionLabel(
                              text: 'EN LA COLA LOCAL (POR SUBIR)'),
                          const SizedBox(height: 8),
                          Card(
                            color: AppPalette.surfaceDark,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(
                                  color: AppPalette.surfaceDarkHighlight),
                            ),
                            child: Column(
                              children: <Widget>[
                                _SyncItem(
                                  icon: Icons.upload_file_rounded,
                                  label: 'Reportes de Servicio',
                                  count: _pendingReports,
                                  badge: _BadgeType.pending,
                                  lastError: _lastReportError,
                                ),
                                const _Divider(),
                                _SyncItem(
                                  icon: Icons.image_rounded,
                                  label: 'Evidencias Fotográficas',
                                  count: _pendingFiles,
                                  badge: _BadgeType.pending,
                                  lastError: _lastFileError,
                                ),
                                const _Divider(),
                                _SyncItem(
                                  icon: Icons.draw_rounded,
                                  label: 'Firmas de Clientes',
                                  count: _pendingSignatures,
                                  badge: _BadgeType.pending,
                                  lastError: _lastSignatureError,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── Disponible en servidor (por bajar) ────────────────
                          const _SectionLabel(
                              text:
                                  'DISPONIBLE EN SERVIDOR (POR DESCARGAR)'),
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
                                  count: 0,
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
  const _NetworkStatusCard({
    required this.isSyncing,
    required this.lastSyncText,
  });

  final bool isSyncing;
  final String lastSyncText;

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
                    isSyncing
                        ? 'Sincronizando...'
                        : 'Conectado al Servidor Local',
                    style: const TextStyle(
                      color: AppPalette.backgroundLight,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastSyncText,
                    style: const TextStyle(
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
    this.lastError,
  });

  final IconData icon;
  final String label;
  final int count;
  final _BadgeType badge;
  final String? lastError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppPalette.surfaceDarkHighlight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppPalette.backgroundLight),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  count > 0 ? '$label ($count)' : label,
                  style: const TextStyle(
                    color: AppPalette.backgroundLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if (lastError != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 13,
                        color: Colors.orangeAccent,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          lastError!,
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Badge(type: badge),
        ],
      ),
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
