import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:industrial_service_reports/core/utils/date_utils.dart' show formatLocalCDMX;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:industrial_service_reports/core/constants.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/features/auth/services/auth_service.dart';
import 'package:industrial_service_reports/features/reports/services/pdf_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart' as printing_pkg;

class ReportViewScreen extends StatefulWidget {
  const ReportViewScreen({
    super.key,
    required this.reportId,
    required this.database,
  });

  final String reportId;
  final AppDatabase database;

  @override
  State<ReportViewScreen> createState() => _ReportViewScreenState();
}

class _ReportViewScreenState extends State<ReportViewScreen> {
  // ── Palette ────────────────────────────────────────────────────────────────
  static const Color _screenBg = Color(0xFF0D1117);
  static const Color _cardBg = Color(0xFF101826);
  static const Color _cardBorder = Color(0xFF243245);
  static const Color _textMuted = Color(0xFF8BA0BC);
  static const Color _accentBlue = Color(0xFF2A8BFF);
  static const Color _successText = Color(0xFF33E98A);
  static const Color _successBg = Color(0xFF103A27);
  static const Color _warningText = Color(0xFFFFD166);
  static const Color _warningBg = Color(0xFF4A3A12);

  static const List<String> _checklistItems = <String>[
    'Mantenimiento general',
    'Calibración sensores',
    'Rodillo dañado',
    'Cabezal dañado',
    'Sensor ribbon dañado',
    'Sensor papel dañado',
    'Pruebas',
    'Otros',
  ];

  static const List<String> _serviceTypeOptions = <String>[
    'Preventivo',
    'Correctivo',
    'Diagnóstico',
    'Instalación',
  ];

  // ── State ──────────────────────────────────────────────────────────────────
  bool _loading = true;
  bool _isGeneratingPdf = false;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isReprintingPdf = false;

  Report? _report;
  Printer? _printer;
  Client? _client;
  CatalogModel? _catalogModel;
  String? _technicianName;

  // ── Edit controllers ───────────────────────────────────────────────────────
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _counterController = TextEditingController();
  final TextEditingController _darknessController = TextEditingController();
  String _editServiceType = 'Preventivo';

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _counterController.dispose();
    _darknessController.dispose();
    super.dispose();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadReport() async {
    try {
      final Report? report = await (widget.database.select(widget.database.reports)
            ..where((r) => r.id.equals(widget.reportId)))
          .getSingleOrNull();

      if (report == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final Printer? printer = await (widget.database.select(widget.database.printers)
            ..where((p) => p.id.equals(report.printerId)))
          .getSingleOrNull();

      Client? client;
      CatalogModel? catalogModel;
      if (printer != null) {
        client = await (widget.database.select(widget.database.clients)
              ..where((c) => c.id.equals(printer.clientId)))
            .getSingleOrNull();
        catalogModel = await (widget.database.select(widget.database.catalogModels)
              ..where((m) => m.id.equals(printer.modelId)))
            .getSingleOrNull();
      }

      final User? technician = await (widget.database.select(widget.database.users)
            ..where((u) => u.id.equals(report.techId)))
          .getSingleOrNull();

      if (mounted) {
        setState(() {
          _report = report;
          _printer = printer;
          _client = client;
          _catalogModel = catalogModel;
          _technicianName = technician?.name;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Edit mode ──────────────────────────────────────────────────────────────

  void _enterEditMode() {
    if (_report == null) return;
    final Report r = _report!;
    _editServiceType = r.serviceType;
    _notesController.text = r.notes ?? '';
    _counterController.text = r.linearInchesCounter.toString();
    _darknessController.text = r.darknessLevel?.toString() ?? '';
    setState(() => _isEditing = true);
  }

  void _cancelEdit() => setState(() => _isEditing = false);

  Future<void> _saveEdit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final int? counter = int.tryParse(_counterController.text.trim());
    final int? darkness = _darknessController.text.trim().isEmpty
        ? null
        : int.tryParse(_darknessController.text.trim());

    final Map<String, dynamic> payload = <String, dynamic>{
      'service_type': _editServiceType,
      'linear_inches_counter': counter ?? _report!.linearInchesCounter,
      'notes': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      'darkness_level': darkness,
    };

    bool saved = false;
    try {
      final AuthService auth = AuthService();
      final String? token = await auth.getToken();

      final http.Response resp = await http
          .patch(
            Uri.parse('$kServerBaseUrlDevice/api/reports/${widget.reportId}'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (resp.statusCode == 200) {
        await _applyLocalUpdate(payload);
        saved = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reporte actualizado correctamente')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error del servidor (${resp.statusCode})'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } on io.SocketException catch (_) {
      await _saveOffline(payload);
      saved = true;
    } on TimeoutException catch (_) {
      await _saveOffline(payload);
      saved = true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          if (saved) _isEditing = false;
        });
      }
    }
  }

  Future<void> _applyLocalUpdate(Map<String, dynamic> payload) async {
    await (widget.database.update(widget.database.reports)
          ..where((r) => r.id.equals(widget.reportId)))
        .write(ReportsCompanion(
      serviceType: Value<String>(payload['service_type'] as String),
      linearInchesCounter:
          Value<int>(payload['linear_inches_counter'] as int),
      notes: Value<String?>(payload['notes'] as String?),
      darknessLevel: Value<int?>(payload['darkness_level'] as int?),
    ));
    await _loadReport();
  }

  Future<void> _saveOffline(Map<String, dynamic> payload) async {
    await _applyLocalUpdate(payload);
    await widget.database.into(widget.database.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: 'ru_${widget.reportId}_${DateTime.now().millisecondsSinceEpoch}',
            methodHttp: 'PATCH',
            endpointDestino: '/api/reports/${widget.reportId}',
            payloadJson: jsonEncode(payload),
            entityType: 'report_update',
            entityId: widget.reportId,
          ),
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guardado localmente, se sincronizará después'),
        ),
      );
    }
  }

  // ── Reimprimir PDF ─────────────────────────────────────────────────────────

  Future<void> _reprintPdf() async {
    setState(() => _isReprintingPdf = true);
    try {
      final Report report = _report!;
      final AuthService auth = AuthService();
      final String? token = await auth.getToken();

      final http.Response resp = await http
          .patch(
            Uri.parse('$kServerBaseUrlDevice/api/reports/${widget.reportId}'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(<String, dynamic>{
              'service_type': report.serviceType,
              'linear_inches_counter': report.linearInchesCounter,
              'notes': report.notes,
              'darkness_level': report.darknessLevel,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final Uint8List pdfBytes = await PdfService.generateReportPdf(
          reportId: widget.reportId,
          database: widget.database,
        );
        // Overwrite local PDF file if it exists
        try {
          final io.Directory appDir = await getApplicationDocumentsDirectory();
          final User? techForName = await (widget.database
                  .select(widget.database.users)
                ..where((Users u) => u.id.equals(report.techId)))
              .getSingleOrNull();
          final String pdfPath =
              '${appDir.path}/reports/pdfs/${PdfService.reportPdfName(report, techForName)}';
          if (io.File(pdfPath).existsSync()) {
            await io.File(pdfPath).writeAsBytes(pdfBytes);
          }
        } catch (_) {}

        await printing_pkg.Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name: report.code ?? 'reporte',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF regenerado correctamente')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error del servidor (${resp.statusCode})'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } on io.SocketException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sin conexión, intenta cuando tengas internet'),
          ),
        );
      }
    } on TimeoutException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sin conexión, intenta cuando tengas internet'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isReprintingPdf = false);
    }
  }

  // ── PDF (local) ────────────────────────────────────────────────────────────

  Future<void> _generateAndShowPdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final Uint8List pdfBytes = await PdfService.generateReportPdf(
        reportId: widget.reportId,
        database: widget.database,
      );
      await printing_pkg.Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: _report?.code ?? 'reporte',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text('Error al generar PDF: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _formatDate(DateTime date) => formatLocalCDMX(date);

  InputDecoration _editDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _accentBlue),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red),
      ),
      filled: true,
      fillColor: const Color(0xFF1A2536),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBg,
      appBar: AppBar(
        backgroundColor: _screenBg,
        title: Text(
          _isEditing
              ? 'Editando reporte'
              : (_report?.code ?? 'Ver Reporte'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: _isEditing
            ? <Widget>[
                if (_isSaving)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                  )
                else ...<Widget>[
                  IconButton(
                    icon: const Icon(Icons.check_rounded,
                        color: Color(0xFF33E98A)),
                    onPressed: _saveEdit,
                    tooltip: 'Guardar cambios',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                    onPressed: _cancelEdit,
                    tooltip: 'Cancelar edición',
                  ),
                ],
              ]
            : <Widget>[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _report == null ? null : _enterEditMode,
                  tooltip: 'Editar reporte',
                ),
              ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _report == null
              ? _buildNotFound()
              : _buildContent(),
      bottomNavigationBar: _report == null
          ? null
          : SafeArea(
              top: false,
              child: Container(
                color: _screenBg,
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: () => context.pop(),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF242E3D),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text(
                            'Cerrar',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                    if (!_isEditing) ...<Widget>[
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: TextButton.icon(
                          onPressed: _isGeneratingPdf
                              ? null
                              : _generateAndShowPdf,
                          icon: _isGeneratingPdf
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : const Icon(Icons.picture_as_pdf_rounded),
                          label: const Text('PDF'),
                          style: TextButton.styleFrom(
                              foregroundColor: _accentBlue),
                        ),
                      ),
                      if (_report!.signatureName != null) ...<Widget>[
                        const SizedBox(width: 6),
                        SizedBox(
                          height: 48,
                          child: TextButton.icon(
                            onPressed: _isReprintingPdf ? null : _reprintPdf,
                            icon: _isReprintingPdf
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(
                                    Icons.picture_as_pdf_outlined),
                            label: const Text('Reimprimir'),
                            style: TextButton.styleFrom(
                                foregroundColor: _warningText),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildNotFound() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.find_in_page_rounded, size: 64, color: Colors.white24),
          SizedBox(height: 16),
          Text(
            'Reporte no encontrado',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final Report report = _report!;
    final List<String> photos = List<String>.from(
      jsonDecode(report.photoPaths) as List<dynamic>,
    );
    final Map<String, dynamic> checkboxes = report.technicalCheckboxes;

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
        child: Column(
          children: <Widget>[
            _buildHeaderCard(report),
            const SizedBox(height: 10),
            _buildServiceParamsCard(report),
            const SizedBox(height: 10),
            _buildPrinterCard(),
            const SizedBox(height: 10),
            _buildChecklistCard(checkboxes),
            const SizedBox(height: 10),
            if (_isEditing || (report.notes ?? '').isNotEmpty) ...<Widget>[
              _buildNotesCard(report),
              const SizedBox(height: 10),
            ],
            if (photos.isNotEmpty) ...<Widget>[
              _buildPhotosCard(photos),
              const SizedBox(height: 10),
            ],
            _buildSignatureCard(report),
          ],
        ),
      ),
    );
  }

  // ── Cards ──────────────────────────────────────────────────────────────────

  Widget _buildHeaderCard(Report report) {
    final (Color statusBg, Color statusFg, String statusLabel) =
        _statusBadge(report.status);
    final (Color badgeBg, Color badgeFg, String badgeLabel) =
        _serviceTypeBadge(report.serviceType);

    return _ViewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'INFORMACIÓN DEL REPORTE',
            style: TextStyle(
              color: _textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      report.code ??
                          'R-${report.id.substring(0, 8).toUpperCase()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(report.serviceDate),
                      style: const TextStyle(
                        color: _textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  if (_isEditing)
                    SizedBox(
                      width: 148,
                      child: DropdownButtonFormField<String>(
                        value: _editServiceType,
                        dropdownColor: const Color(0xFF1E2A3A),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: _cardBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: _cardBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: _accentBlue),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF1A2536),
                        ),
                        items: _serviceTypeOptions
                            .map((String v) => DropdownMenuItem<String>(
                                  value: v,
                                  child: Text(v),
                                ))
                            .toList(),
                        onChanged: (String? v) {
                          if (v != null) {
                            setState(() => _editServiceType = v);
                          }
                        },
                        validator: (String? v) =>
                            (v == null || v.isEmpty) ? 'Requerido' : null,
                      ),
                    )
                  else ...<Widget>[
                    _buildBadge(badgeBg, badgeFg, badgeLabel),
                    const SizedBox(height: 6),
                  ],
                  const SizedBox(height: 6),
                  _buildBadge(statusBg, statusFg, statusLabel),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceParamsCard(Report report) {
    return _ViewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'PARÁMETROS DEL SERVICIO',
            style: TextStyle(
              color: _textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          if (!_isEditing) ...<Widget>[
            _InfoRow(
              label: 'Contador',
              value: '${report.linearInchesCounter} pulg.',
            ),
            const SizedBox(height: 6),
            _InfoRow(
              label: 'Oscuridad',
              value: report.darknessLevel?.toString() ?? '—',
            ),
          ] else ...<Widget>[
            TextFormField(
              controller: _counterController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration:
                  _editDecoration('Contador de pulgadas lineales'),
              validator: (String? v) {
                if (v == null || v.trim().isEmpty) return 'Requerido';
                if (int.tryParse(v.trim()) == null) {
                  return 'Debe ser un número entero';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _darknessController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration:
                  _editDecoration('Nivel de oscuridad (vacío si no aplica)'),
              validator: (String? v) {
                if (v != null &&
                    v.trim().isNotEmpty &&
                    int.tryParse(v.trim()) == null) {
                  return 'Debe ser un número entero';
                }
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrinterCard() {
    final String serialNumber =
        _printer?.serialNumber ?? 'Desconocido';
    final String modelName = _catalogModel != null
        ? '${_catalogModel!.brand} ${_catalogModel!.modelName}'
            ' ${_catalogModel!.dpi}dpi'
        : 'Modelo desconocido';
    final String clientName = _client?.name ?? 'Cliente desconocido';
    final String printerCode = _printer?.code ??
        (_printer?.id.substring(0, 8) ?? '—');
    final String techName = _technicianName ?? 'Desconocido';

    return _ViewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'DATOS DE LA IMPRESORA',
            style: TextStyle(
              color: _textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          _InfoRow(label: 'Modelo', value: modelName),
          const SizedBox(height: 6),
          _InfoRow(label: 'Serie', value: 'S/N: $serialNumber'),
          const SizedBox(height: 6),
          _InfoRow(label: 'Cliente', value: clientName),
          const SizedBox(height: 6),
          _InfoRow(label: 'Código', value: printerCode),
          const SizedBox(height: 6),
          _InfoRow(label: 'Técnico', value: techName),
        ],
      ),
    );
  }

  Widget _buildChecklistCard(Map<String, dynamic> checkboxes) {
    return _ViewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'LISTA TÉCNICA',
            style: TextStyle(
              color: _textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          ..._checklistItems.map((String item) {
            final bool checked = checkboxes[item] == true;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: <Widget>[
                  Icon(
                    checked
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 20,
                    color:
                        checked ? _successText : Colors.white30,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    item,
                    style: TextStyle(
                      color: checked ? Colors.white : Colors.white54,
                      fontSize: 14,
                      fontWeight: checked
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNotesCard(Report report) {
    return _ViewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'NOTAS DEL SERVICIO',
            style: TextStyle(
              color: _textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          if (_isEditing)
            TextFormField(
              controller: _notesController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _editDecoration('Notas / Observaciones'),
            )
          else
            Text(
              report.notes ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotosCard(List<String> photos) {
    final List<String> existingPhotos = photos
        .take(4)
        .where((String p) => io.File(p).existsSync())
        .toList();

    if (existingPhotos.isEmpty) return const SizedBox.shrink();

    return _ViewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'EVIDENCIAS FOTOGRÁFICAS',
            style: TextStyle(
              color: _textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: existingPhotos.length,
            itemBuilder: (BuildContext context, int index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  io.File(existingPhotos[index]),
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureCard(Report report) {
    final String signerName =
        report.signatureName ?? 'No especificado';
    final String signerRole =
        report.signatureRole ?? 'No especificado';
    final String? sigPath = report.signatureImagePath;
    final bool hasSignature =
        sigPath != null && io.File(sigPath).existsSync();

    return _ViewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'FIRMA DE CONFORMIDAD',
            style: TextStyle(
              color: _textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          _InfoRow(label: 'Nombre', value: signerName),
          const SizedBox(height: 6),
          _InfoRow(label: 'Cargo', value: signerRole),
          if (hasSignature) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  io.File(sigPath),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Widgets helpers ────────────────────────────────────────────────────────

  Widget _buildBadge(Color bg, Color fg, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  (Color, Color, String) _serviceTypeBadge(String serviceType) {
    switch (serviceType) {
      case 'Correctivo':
        return (
          const Color(0xFF471C1C),
          const Color(0xFFFF8F8F),
          'CORRECTIVO'
        );
      case 'Diagnóstico':
      case 'Diagnostico':
        return (
          const Color(0xFF2E3F17),
          const Color(0xFFD6FF91),
          'DIAGNÓSTICO'
        );
      case 'Instalación':
      case 'Instalacion':
        return (
          const Color(0xFF1E304D),
          const Color(0xFF8EC5FF),
          'INSTALACIÓN'
        );
      default:
        return (_successBg, _successText, 'PREVENTIVO');
    }
  }

  (Color, Color, String) _statusBadge(String status) {
    switch (status.toLowerCase()) {
      case 'synced':
        return (_successBg, _successText, 'SINCRONIZADO');
      case 'pending':
      case 'draft':
        return (_warningBg, _warningText, status.toUpperCase());
      default:
        return (
          const Color(0xFF1E2A3A),
          Colors.white54,
          status.toUpperCase()
        );
    }
  }
}

// ── Shared sub-widgets ─────────────────────────────────────────────────────

class _ViewCard extends StatelessWidget {
  const _ViewCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _ReportViewScreenState._cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ReportViewScreenState._cardBorder),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 70,
          child: Text(
            '$label:',
            style: const TextStyle(
              color: _ReportViewScreenState._textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
