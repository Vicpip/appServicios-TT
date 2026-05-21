import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:industrial_service_reports/core/utils/date_utils.dart' show formatLocalCDMX;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:industrial_service_reports/core/constants.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/features/auth/services/auth_service.dart';
import 'package:industrial_service_reports/features/sync/presentation/sync_history_screen.dart';
import 'package:industrial_service_reports/features/sync/providers/sync_queue_provider.dart';
import 'package:industrial_service_reports/features/sync/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyncDashboardScreen extends ConsumerStatefulWidget {
  const SyncDashboardScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  ConsumerState<SyncDashboardScreen> createState() =>
      _SyncDashboardScreenState();
}

class _SyncDashboardScreenState extends ConsumerState<SyncDashboardScreen> {
  bool _isSyncing = false;
  String _progressMessage = '';
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();
    _loadLastSync();
  }

  Future<void> _loadLastSync() async {
    // Prefer SharedPreferences (written by SyncService after each successful sync)
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? ts = prefs.getString('last_sync_timestamp');
      if (ts != null) {
        final DateTime dt = DateTime.parse(ts);
        if (mounted) setState(() => _lastSync = dt);
        return;
      }
    } catch (_) {}
    // Fallback: read lastSyncAt from users table
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
    if (mounted) setState(() => _lastSync = lastSync);
  }

  String _formatLastSync(DateTime dt) => formatLocalCDMX(dt, showTime: true);

  Future<void> _startSync({bool retryFailed = false}) async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
      _progressMessage =
          retryFailed ? 'Reintentando fallidos…' : 'Conectando al servidor…';
    });

    try {
      final SyncResult result = await SyncService(widget.database).runSync(
        baseUrl: kServerBaseUrlDevice,
        retryFailed: retryFailed,
        onProgress: (String msg) {
          if (mounted) setState(() => _progressMessage = msg);
        },
      );

      if (!mounted) return;

      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

      await _loadLastSync();

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
    final AsyncValue<List<SyncQueueData>> asyncItems =
        ref.watch(pendingSyncItemsProvider);

    final int failedCount = asyncItems.maybeWhen(
      data: (List<SyncQueueData> items) => items
          .where((SyncQueueData i) => i.estadoPeticion == 'failed')
          .length,
      orElse: () => 0,
    );

    final String lastSyncText = _isSyncing && _progressMessage.isNotEmpty
        ? _progressMessage
        : _lastSync != null
            ? 'Última sync: ${_formatLastSync(_lastSync!)}'
            : 'Sin sincronización aún';

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: <Widget>[
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
              child: asyncItems.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (Object e, _) => Center(child: Text('Error: $e')),
                data: (List<SyncQueueData> items) {
                  final List<SyncQueueData> reports = items
                      .where(
                          (SyncQueueData i) => i.entityType == 'report')
                      .toList();
                  final List<SyncQueueData> files = items
                      .where((SyncQueueData i) =>
                          i.entityType == 'file' ||
                          i.entityType == 'signature' ||
                          i.entityType == 'pdf')
                      .toList();
                  final List<SyncQueueData> deliveries = items
                      .where((SyncQueueData i) =>
                          i.entityType == 'policy_delivery')
                      .toList();

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // ── Estado y último sync ────────────────────────────
                        _NetworkStatusCard(
                          isSyncing: _isSyncing,
                          lastSyncText: lastSyncText,
                        ),
                        const SizedBox(height: 12),

                        // ── Resumen de conteos ──────────────────────────────
                        _SummaryCard(
                          reportCount: reports.length,
                          fileCount: files.length,
                          deliveryCount: deliveries.length,
                          isSyncing: _isSyncing,
                        ),
                        const SizedBox(height: 20),

                        // ── Contenido principal ─────────────────────────────
                        if (items.isEmpty) ...<Widget>[
                          const SizedBox(height: 24),
                          const _EmptyState(),
                        ] else ...<Widget>[
                          const _SectionLabel(
                              text: 'PENDIENTES DE SUBIR'),
                          const SizedBox(height: 8),
                          if (reports.isNotEmpty) ...<Widget>[
                            _PendingGroup(
                              title: 'Reportes de Servicio',
                              icon: Icons.description_rounded,
                              items: reports,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (files.isNotEmpty) ...<Widget>[
                            _PendingGroup(
                              title: 'Archivos y Firmas',
                              icon: Icons.folder_rounded,
                              items: files,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (deliveries.isNotEmpty) ...<Widget>[
                            _PendingGroup(
                              title: 'Entregas de Póliza',
                              icon: Icons.assignment_turned_in_rounded,
                              items: deliveries,
                            ),
                          ],
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── Botones fijos ───────────────────────────────────────────
            _SyncButton(
              isSyncing: _isSyncing,
              onTap: _startSync,
              failedCount: failedCount,
              onRetry: () => _startSync(retryFailed: true),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Resumen de conteos ───────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.reportCount,
    required this.fileCount,
    required this.deliveryCount,
    required this.isSyncing,
  });

  final int reportCount;
  final int fileCount;
  final int deliveryCount;
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    final int total = reportCount + fileCount + deliveryCount;

    final List<String> parts = <String>[];
    if (reportCount > 0) {
      parts.add(
          '$reportCount ${reportCount == 1 ? 'reporte' : 'reportes'}');
    }
    if (fileCount > 0) {
      parts.add(
          '$fileCount ${fileCount == 1 ? 'archivo' : 'archivos'}');
    }
    if (deliveryCount > 0) {
      parts.add(
          '$deliveryCount ${deliveryCount == 1 ? 'entrega' : 'entregas'}');
    }

    final String label = isSyncing
        ? 'Sincronizando...'
        : total == 0
            ? 'Sin elementos pendientes'
            : parts.join(' · ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppPalette.surfaceDarkHighlight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            isSyncing
                ? Icons.sync_rounded
                : total > 0
                    ? Icons.pending_actions_rounded
                    : Icons.check_circle_rounded,
            size: 18,
            color: isSyncing
                ? AppPalette.primary
                : total > 0
                    ? AppPalette.warning
                    : AppPalette.success,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isSyncing
                  ? AppPalette.primary
                  : total > 0
                      ? AppPalette.warning
                      : AppPalette.success,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (total > 0) ...<Widget>[
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppPalette.warningDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppPalette.warning),
              ),
              child: Text(
                '$total total',
                style: const TextStyle(
                  color: AppPalette.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Grupo de items pendientes ────────────────────────────────────────────────

class _PendingGroup extends StatelessWidget {
  const _PendingGroup({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<SyncQueueData> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 13, color: Colors.blueGrey),
              const SizedBox(width: 5),
              Text(
                '${title.toUpperCase()} (${items.length})',
                style: const TextStyle(
                  color: Colors.blueGrey,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        Card(
          color: AppPalette.surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppPalette.surfaceDarkHighlight),
          ),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < items.length; i++) ...<Widget>[
                _PendingItemRow(item: items[i]),
                if (i < items.length - 1) const _Divider(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Fila individual de item pendiente ───────────────────────────────────────

class _PendingItemRow extends StatelessWidget {
  const _PendingItemRow({required this.item});

  final SyncQueueData item;

  static Map<String, dynamic> _decodePayload(String json) {
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static String _basename(String path) {
    if (path.isEmpty) return '—';
    return path.replaceAll('\\', '/').split('/').last;
  }

  static String _shortId(String id) =>
      id.length > 14 ? '${id.substring(0, 14)}…' : id;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> p = _decodePayload(item.payloadJson);
    final bool isFailed = item.estadoPeticion == 'failed';

    final IconData icon;
    final String title;
    final String subtitle;

    if (item.entityType == 'report') {
      icon = Icons.description_rounded;
      title = (p['code'] as String?) ?? 'R-???';
      final String? printerCode = p['printerCode'] as String?;
      final String? serial = p['printerSerial'] as String?;
      final String? pid = p['printerId'] as String?;
      subtitle =
          'Impresora: ${printerCode ?? serial ?? (pid != null ? _shortId(pid) : '—')}';
    } else if (item.entityType == 'file') {
      icon = Icons.image_rounded;
      title = 'Foto';
      subtitle = _basename(p['localPath'] as String? ?? '');
    } else if (item.entityType == 'signature') {
      icon = Icons.draw_rounded;
      title = 'Firma';
      subtitle = _basename(p['localPath'] as String? ?? '');
    } else if (item.entityType == 'pdf') {
      icon = Icons.picture_as_pdf_rounded;
      title = 'PDF';
      subtitle = _basename(p['localPath'] as String? ?? '');
    } else if (item.entityType == 'policy_delivery') {
      icon = Icons.assignment_turned_in_rounded;
      title = 'Entrega de Póliza';
      final String? vid = p['visitId'] as String?;
      final String? polId = p['policyId'] as String?;
      subtitle = _shortId(vid ?? polId ?? item.entityId);
    } else {
      icon = Icons.sync_rounded;
      title = item.entityType;
      subtitle = _shortId(item.entityId);
    }

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
                  title,
                  style: const TextStyle(
                    color: AppPalette.backgroundLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isFailed && item.lastError != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 13,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.lastError!,
                          style: const TextStyle(
                            color: Colors.redAccent,
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
          _Badge(
              type: isFailed ? _BadgeType.error : _BadgeType.pending),
        ],
      ),
    );
  }
}

// ─── Estado vacío ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppPalette.successDark,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_done_rounded,
              size: 44,
              color: AppPalette.success,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Todo sincronizado',
            style: TextStyle(
              color: AppPalette.backgroundLight,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No hay elementos pendientes de subir al servidor',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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

enum _BadgeType { pending, error, upToDate }

// ─── Badge ────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({required this.type});

  final _BadgeType type;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color border;
    final Color textColor;
    final String label;

    switch (type) {
      case _BadgeType.pending:
        bg = AppPalette.warningDark;
        border = AppPalette.warning;
        textColor = AppPalette.warning;
        label = 'Pendiente';
      case _BadgeType.error:
        bg = const Color(0xFF5C1A1A);
        border = Colors.redAccent;
        textColor = Colors.redAccent;
        label = 'Error';
      case _BadgeType.upToDate:
        bg = AppPalette.surfaceDarkHighlight;
        border = Colors.white30;
        textColor = Colors.white60;
        label = 'Al día';
    }

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
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ─── Divisor ──────────────────────────────────────────────────────────────────

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
    required this.failedCount,
    required this.onRetry,
  });

  final bool isSyncing;
  final VoidCallback onTap;
  final int failedCount;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: AppPalette.surfaceDark,
        border: Border(top: BorderSide(color: AppPalette.surfaceDarkHighlight)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Botón secundario: solo visible cuando hay fallidos y no se está sincronizando
          if (failedCount > 0 && !isSyncing) ...<Widget>[
            SizedBox(
              height: 44,
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  'Reintentar $failedCount fallido${failedCount != 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.warning,
                  side: const BorderSide(color: AppPalette.warning),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          // Botón principal
          SizedBox(
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
        ],
      ),
    );
  }
}
