import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/core/utils/date_utils.dart'
    show formatLocalCDMX;
import 'package:industrial_service_reports/data/local/app_database.dart';

/// Máximo de reportes subidos que muestra el historial.
const int _kHistoryLimit = 50;

@immutable
class _UploadedEntry {
  const _UploadedEntry({
    required this.code,
    required this.serial,
    required this.client,
    required this.syncedAt,
  });

  final String code;
  final String serial;
  final String client;
  final DateTime syncedAt;
}

@immutable
class _ErrorEntry {
  const _ErrorEntry({
    required this.title,
    required this.detail,
    required this.reason,
    required this.attempts,
  });

  final String title;
  final String detail;
  final String reason;
  final int attempts;
}

/// Historial de sincronización: reportes subidos recientemente (últimos 50) y
/// elementos de la cola que están en error con su motivo.
class SyncHistoryScreen extends StatefulWidget {
  const SyncHistoryScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  State<SyncHistoryScreen> createState() => _SyncHistoryScreenState();
}

class _SyncHistoryScreenState extends State<SyncHistoryScreen> {
  bool _loading = true;
  List<_UploadedEntry> _uploaded = const <_UploadedEntry>[];
  List<_ErrorEntry> _errors = const <_ErrorEntry>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<({String code, String serial, String client})> _describeReport(
      Report report) async {
    final AppDatabase db = widget.database;
    final Printer? printer = await (db.select(db.printers)
          ..where((Printers p) => p.id.equals(report.printerId)))
        .getSingleOrNull();
    final Client? client = printer == null
        ? null
        : await (db.select(db.clients)
              ..where((Clients c) => c.id.equals(printer.clientId)))
            .getSingleOrNull();
    return (
      code: report.code ?? report.id.substring(0, 8),
      serial: printer?.serialNumber ?? '—',
      client: client?.name ?? '—',
    );
  }

  String _entityLabel(String entityType) {
    switch (entityType) {
      case 'report':
        return 'Reporte';
      case 'report_update':
        return 'Corrección de reporte';
      case 'file':
        return 'Foto';
      case 'signature':
        return 'Firma';
      case 'pdf':
        return 'PDF del reporte';
      case 'delivery_pdf':
        return 'PDF de entrega';
      case 'policy_delivery':
        return 'Entrega de póliza';
      default:
        return entityType;
    }
  }

  Future<void> _load() async {
    final AppDatabase db = widget.database;

    final List<Report> reports = await (db.select(db.reports)
          ..where((Reports r) => r.syncedAt.isNotNull())
          ..orderBy(<OrderingTerm Function(Reports)>[
            (Reports r) => OrderingTerm.desc(r.syncedAt),
          ])
          ..limit(_kHistoryLimit))
        .get();

    final List<_UploadedEntry> uploaded = <_UploadedEntry>[];
    for (final Report report in reports) {
      final d = await _describeReport(report);
      uploaded.add(_UploadedEntry(
        code: d.code,
        serial: d.serial,
        client: d.client,
        syncedAt: report.syncedAt!,
      ));
    }

    final List<SyncQueueData> failedItems = await (db.select(db.syncQueue)
          ..where((SyncQueue q) => q.estadoPeticion.equals('failed'))
          ..orderBy(<OrderingTerm Function(SyncQueue)>[
            (SyncQueue q) => OrderingTerm.desc(q.updatedAt),
          ]))
        .get();

    final List<_ErrorEntry> errors = <_ErrorEntry>[];
    for (final SyncQueueData item in failedItems) {
      final Report? report = await (db.select(db.reports)
            ..where((Reports r) => r.id.equals(item.entityId)))
          .getSingleOrNull();
      String detail = '';
      String title = _entityLabel(item.entityType);
      if (report != null) {
        final d = await _describeReport(report);
        title = '${_entityLabel(item.entityType)} ${d.code}';
        detail = 'S/N ${d.serial} · ${d.client}';
      }
      errors.add(_ErrorEntry(
        title: title,
        detail: detail,
        reason: (item.lastError ?? '').isEmpty
            ? 'Error desconocido'
            : item.lastError!,
        attempts: item.intentosFallidos,
      ));
    }

    if (!mounted) return;
    setState(() {
      _uploaded = uploaded;
      _errors = errors;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: <Widget>[
            Icon(Icons.history_rounded, size: 22),
            SizedBox(width: 8),
            Text('Historial de Sincronización'),
          ],
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_uploaded.isEmpty && _errors.isEmpty)
                ? const _EmptyHistory()
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: <Widget>[
                        if (_errors.isNotEmpty) ...<Widget>[
                          _SectionTitle(
                              text: 'En error (${_errors.length})',
                              color: const Color(0xFFE57373)),
                          for (final _ErrorEntry e in _errors) ...<Widget>[
                            _ErrorCard(entry: e),
                            const SizedBox(height: 10),
                          ],
                          const SizedBox(height: 8),
                        ],
                        _SectionTitle(
                            text:
                                'Subidos recientemente (últimos $_kHistoryLimit)',
                            color: AppPalette.success),
                        if (_uploaded.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Aún no hay reportes subidos.',
                              style: TextStyle(color: Colors.white60),
                            ),
                          ),
                        for (final _UploadedEntry u in _uploaded) ...<Widget>[
                          _UploadedCard(entry: u),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.history_rounded, size: 54, color: Colors.white24),
          SizedBox(height: 12),
          Text(
            'Aún no hay reportes sincronizados',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _UploadedCard extends StatelessWidget {
  const _UploadedCard({required this.entry});

  final _UploadedEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppPalette.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppPalette.successDark),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.check_circle_rounded,
                    color: AppPalette.success, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.code,
                    style: const TextStyle(
                      color: AppPalette.success,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  formatLocalCDMX(entry.syncedAt, showTime: true),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'S/N: ${entry.serial}',
              style: const TextStyle(
                color: AppPalette.accentBlue,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              entry.client,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.entry});

  final _ErrorEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppPalette.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF5A1A1A)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.error_rounded,
                    color: Color(0xFFE57373), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.title,
                    style: const TextStyle(
                      color: Color(0xFFE57373),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  '${entry.attempts} intento${entry.attempts != 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (entry.detail.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                entry.detail,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: const Color(0xFF3B1010),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF7A2222)),
              ),
              child: Text(
                'Motivo: ${entry.reason}',
                style: const TextStyle(
                  color: Color(0xFFFFB3B3),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
