import 'package:flutter/material.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';

enum _SyncStatus { success, partial, failed }

@immutable
class _SyncLogEntry {
  const _SyncLogEntry({
    required this.status,
    required this.title,
    required this.timestamp,
    required this.actions,
    this.errorMessage,
  });

  final _SyncStatus status;
  final String title;
  final String timestamp;
  final List<String> actions;
  final String? errorMessage;
}

class SyncHistoryScreen extends StatefulWidget {
  const SyncHistoryScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  State<SyncHistoryScreen> createState() => _SyncHistoryScreenState();
}

class _SyncHistoryScreenState extends State<SyncHistoryScreen> {
  // Nota: La tabla de sincronización no existe en la BD actual
  // Se muestra un mensaje de "Sin registros" como fallback
  List<_SyncLogEntry> _entries = <_SyncLogEntry>[];

  void _confirmClearHistory() {
    showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Limpiar Historial'),
          content: const Text(
            '¿Deseas eliminar toda la bitácora de sincronizaciones? Esta acción no afecta los datos.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Limpiar'),
            ),
          ],
        );
      },
    ).then((bool? confirmed) {
      if (confirmed == true && mounted) {
        setState(() {
          _entries = <_SyncLogEntry>[];
        });
      }
    });
  }

  void _retrySync() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Iniciando reintento de sincronización...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const <Widget>[
            Icon(Icons.history_rounded, size: 22),
            SizedBox(width: 8),
            Text('Historial de Sincronización'),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Filtrar',
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Filtros de bitácora (próximamente)'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // ── Header fijo ───────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              decoration: const BoxDecoration(
                color: AppPalette.surfaceDark,
                border: Border(
                  bottom: BorderSide(color: AppPalette.surfaceDarkHighlight),
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Bitácora de las últimas conexiones con el servidor local.',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _entries.isEmpty ? null : _confirmClearHistory,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFE57373),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                    child: const Text(
                      'Limpiar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Lista de bitácora ─────────────────────────────────────────
            Expanded(
              child: _entries.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.history_rounded,
                            size: 54,
                            color: Colors.white24,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No hay registros en la bitácora',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: _entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (BuildContext context, int index) {
                        return _LogCard(
                          entry: _entries[index],
                          onRetry: _retrySync,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tarjeta de log ───────────────────────────────────────────────────────────

class _LogCard extends StatelessWidget {
  const _LogCard({
    required this.entry,
    required this.onRetry,
  });

  final _SyncLogEntry entry;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final _StatusStyle style = _styleFor(entry.status);

    return Card(
      color: AppPalette.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: style.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Fila 1: estado + título + timestamp
            Row(
              children: <Widget>[
                Icon(style.icon, color: style.color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.title,
                    style: TextStyle(
                      color: style.color,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  entry.timestamp,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Fila 2: detalles / payload
            if (entry.status == _SyncStatus.failed) ...<Widget>[
              _ErrorDetail(message: entry.errorMessage ?? ''),
            ] else if (entry.actions.isNotEmpty) ...<Widget>[
              _ActionDetail(actions: entry.actions),
            ],

            // Fila 3: botón reintentar (solo en fallo)
            if (entry.status == _SyncStatus.failed) ...<Widget>[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  height: 34,
                  child: FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.sync_rounded, size: 16),
                    label: const Text(
                      'Reintentar ahora',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _StatusStyle _styleFor(_SyncStatus status) {
    return switch (status) {
      _SyncStatus.success => const _StatusStyle(
          icon: Icons.check_circle_rounded,
          color: AppPalette.success,
          borderColor: AppPalette.successDark,
        ),
      _SyncStatus.partial => const _StatusStyle(
          icon: Icons.warning_rounded,
          color: AppPalette.warning,
          borderColor: AppPalette.warningDark,
        ),
      _SyncStatus.failed => const _StatusStyle(
          icon: Icons.error_rounded,
          color: Color(0xFFE57373),
          borderColor: Color(0xFF5A1A1A),
        ),
    };
  }
}

class _ActionDetail extends StatelessWidget {
  const _ActionDetail({required this.actions});

  final List<String> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppPalette.surfaceDarkHighlight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: actions
            .map(
              (String action) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  action,
                  style: TextStyle(
                    color: action.startsWith('⚠')
                        ? AppPalette.warning
                        : Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ErrorDetail extends StatelessWidget {
  const _ErrorDetail({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF3B1010),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF7A2222)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: Color(0xFFE57373),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Error: $message',
              style: const TextStyle(
                color: Color(0xFFFFB3B3),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusStyle {
  const _StatusStyle({
    required this.icon,
    required this.color,
    required this.borderColor,
  });

  final IconData icon;
  final Color color;
  final Color borderColor;
}
