import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:industrial_service_reports/core/router/app_routes.dart';
import 'package:industrial_service_reports/core/router/route_args.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:uuid/uuid.dart';

class PrinterDetailScreen extends StatefulWidget {
  const PrinterDetailScreen({
    super.key,
    required this.database,
    required this.printerId,
    required this.serialNumber,
    required this.model,
    required this.client,
  });

  final AppDatabase database;
  final String printerId;
  final String serialNumber;
  final String model;
  final String client;

  @override
  State<PrinterDetailScreen> createState() => _PrinterDetailScreenState();
}

class _PrinterDetailScreenState extends State<PrinterDetailScreen> {
  static const Color _screenBg = Color(0xFF0D1117);
  static const Color _cardBg = Color(0xFF101826);
  static const Color _cardBorder = Color(0xFF243245);
  static const Color _textMuted = Color(0xFF8BA0BC);
  static const Color _infoBlue = Color(0xFF2A8BFF);

  bool _loading = true;

  // Datos cargados
  String? _modelName;
  String? _plantName;
  String? _areaName;
  String? _plantId;
  String? _clientId;

  // Ultimo servicio
  String? _lastServiceType;
  String? _lastServiceDate;
  int? _lastServiceCounter;
  String? _lastTechnician;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final db = widget.database;

      final rows = await (db.select(db.printers)
            ..where((p) => p.id.equals(widget.printerId)))
          .join(<drift.Join>[
            drift.innerJoin(
              db.catalogModels,
              db.catalogModels.id.equalsExp(db.printers.modelId),
            ),
            drift.innerJoin(
              db.plants,
              db.plants.id.equalsExp(db.printers.plantId),
            ),
            drift.innerJoin(
              db.areas,
              db.areas.id.equalsExp(db.printers.areaId),
            ),
          ])
          .get();

      if (rows.isNotEmpty) {
        final row = rows.first;
        final catalogModel = row.readTable(db.catalogModels);
        final plant = row.readTable(db.plants);
        final area = row.readTable(db.areas);
        final printer = row.readTable(db.printers);

        _modelName = catalogModel.modelName;
        _plantName = plant.name;
        _areaName = area.name;
        _plantId = plant.id;
        _clientId = printer.clientId;
      }

      // Último servicio
      final reports = await (db.select(db.reports)
            ..where((r) => r.printerId.equals(widget.printerId))
            ..orderBy(<drift.OrderingTerm Function(Reports)>[
              (r) => drift.OrderingTerm.desc(r.serviceDate),
            ])
            ..limit(1))
          .get();

      if (reports.isNotEmpty) {
        final report = reports.first;
        _lastServiceType = report.serviceType;
        _lastServiceCounter = report.linearInchesCounter;
        _lastServiceDate = _fmtDate(report.serviceDate);

        final techRows = await (db.select(db.users)
              ..where((u) => u.id.equals(report.techId)))
            .get();
        if (techRows.isNotEmpty) {
          _lastTechnician = techRows.first.name;
        }
      }

      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtDate(DateTime d) {
    const List<String> meses = <String>[
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    return '${d.day.toString().padLeft(2, '0')} de ${meses[d.month - 1]}, ${d.year}';
  }

  String _fmtCounter(int? v) {
    if (v == null) return 'Sin datos';
    final String s = v.toString();
    final StringBuffer buf = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buf.write(',');
      buf.write(s[i]);
      count++;
    }
    return '${buf.toString().split('').reversed.join()} in';
  }

  // ── Edit ──────────────────────────────────────────────────────────────────

  Future<void> _openEditSheet() async {
    if (_clientId == null) return;
    final db = widget.database;

    final List<Plant> plants = await (db.select(db.plants)
          ..where((p) => p.clientId.equals(_clientId!)))
        .get();

    if (!mounted) return;

    final TextEditingController areaCtrl =
        TextEditingController(text: _areaName ?? '');
    String selectedPlantId = _plantId ?? (plants.isNotEmpty ? plants.first.id : '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Editar datos de la impresora',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'PLANTA',
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (plants.isEmpty)
                    const Text(
                      'Sin plantas registradas para este cliente',
                      style: TextStyle(color: Colors.white54),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: selectedPlantId.isEmpty ? null : selectedPlantId,
                      dropdownColor: const Color(0xFF1C2534),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF1A2435),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _cardBorder),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      items: plants
                          .map(
                            (Plant p) => DropdownMenuItem<String>(
                              value: p.id,
                              child: Text(p.name),
                            ),
                          )
                          .toList(),
                      onChanged: (String? v) {
                        if (v != null) setModal(() => selectedPlantId = v);
                      },
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'ÁREA',
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: areaCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Ej. Línea de Ensamble 3',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF1A2435),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _cardBorder),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await _saveEdit(selectedPlantId, areaCtrl.text.trim());
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppPalette.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Guardar cambios',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    areaCtrl.dispose();
  }

  Future<void> _saveEdit(String plantId, String areaName) async {
    if (areaName.isEmpty || plantId.isEmpty) return;
    final db = widget.database;

    // Buscar o crear área con ese nombre en la planta seleccionada
    final List<Area> existingAreas = await (db.select(db.areas)
          ..where((a) => a.plantId.equals(plantId)))
        .get();

    Area? targetArea = existingAreas.cast<Area?>().firstWhere(
          (Area? a) =>
              a!.name.trim().toLowerCase() == areaName.toLowerCase(),
          orElse: () => null,
        );

    if (targetArea == null) {
      final String newAreaId = const Uuid().v4();
      await db.into(db.areas).insert(
            AreasCompanion.insert(id: newAreaId, plantId: plantId, name: areaName),
          );
      final List<Area> created = await (db.select(db.areas)
            ..where((a) => a.id.equals(newAreaId)))
          .get();
      if (created.isNotEmpty) targetArea = created.first;
    }

    if (targetArea == null) return;

    // Actualizar la impresora
    await (db.update(db.printers)
          ..where((p) => p.id.equals(widget.printerId)))
        .write(
          PrintersCompanion(
            plantId: drift.Value(plantId),
            areaId: drift.Value(targetArea.id),
          ),
        );

    // Recargar datos
    final List<Plant> plants = await (db.select(db.plants)
          ..where((p) => p.id.equals(plantId)))
        .get();

    if (mounted) {
      setState(() {
        _plantId = plantId;
        _plantName = plants.isNotEmpty ? plants.first.name : _plantName;
        _areaName = areaName;
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Datos actualizados correctamente'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Helpers UI ────────────────────────────────────────────────────────────

  _ServiceTypeVisual _serviceTypeVisual(String? serviceType) {
    switch (serviceType) {
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
      case 'Diagnostico':
        return const _ServiceTypeVisual(
          icon: Icons.troubleshoot_rounded,
          color: AppPalette.warning,
        );
      case 'Instalacion':
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final String displayModel = _loading
        ? widget.model
        : (_modelName ?? widget.model);

    return Scaffold(
      backgroundColor: _screenBg,
      appBar: AppBar(
        backgroundColor: _screenBg,
        title: const Text('Ficha Técnica'),
        actions: <Widget>[
          if (!_loading)
            IconButton(
              tooltip: 'Editar datos',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _openEditSheet,
            ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              children: const <Widget>[
                Icon(Icons.offline_bolt_rounded,
                    size: 13, color: Color(0xFF5DC9FF)),
                SizedBox(width: 4),
                Text(
                  'OFFLINE READY',
                  style: TextStyle(
                    color: Color(0xFF5DC9FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 140),
                child: Column(
                  children: <Widget>[
                    // ── Header modelo + contador ──
                    _DetailCard(
                      bgColor: _cardBg,
                      borderColor: _cardBorder,
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFF152133),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _cardBorder),
                            ),
                            child: const Icon(
                              Icons.print_rounded,
                              size: 32,
                              color: Color(0xFFC6D2E4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  displayModel.toLowerCase().contains('zebra')
                                      ? displayModel
                                      : 'Zebra $displayModel',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  'S/N: ${widget.serialNumber}',
                                  style: const TextStyle(
                                    color: _infoBlue,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'CONTADOR ACTUAL',
                                  style: TextStyle(
                                    color: _textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.7,
                                  ),
                                ),
                                Text(
                                  _fmtCounter(_lastServiceCounter),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Datos del cliente ──
                    _DetailCard(
                      bgColor: _cardBg,
                      borderColor: _cardBorder,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'DATOS DEL CLIENTE',
                            style: TextStyle(
                              color: _textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              const Icon(
                                Icons.business_center_rounded,
                                size: 16,
                                color: Color(0xFFA4B6CE),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.client,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: <Widget>[
                              const Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: Color(0xFFA4B6CE),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _plantName ?? 'Sin datos',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(
                                Icons.grid_view_rounded,
                                size: 16,
                                color: Color(0xFFA4B6CE),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _areaName ?? 'Sin datos',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Último servicio ──
                    _DetailCard(
                      bgColor: _cardBg,
                      borderColor: _cardBorder,
                      child: _lastServiceType == null
                          ? const _NoDataRow(label: 'ÚLTIMO SERVICIO')
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Text(
                                  'ÚLTIMO SERVICIO',
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Row(
                                            children: <Widget>[
                                              Icon(
                                                _serviceTypeVisual(
                                                        _lastServiceType)
                                                    .icon,
                                                size: 18,
                                                color: _serviceTypeVisual(
                                                        _lastServiceType)
                                                    .color,
                                              ),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  'Mantenimiento $_lastServiceType',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _lastServiceDate ?? '',
                                            style: const TextStyle(
                                              color: Color(0xFF8FA3BE),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: <Widget>[
                                        const Text(
                                          'CONTADOR',
                                          style: TextStyle(
                                            color: _textMuted,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.7,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _fmtCounter(_lastServiceCounter),
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            color: _infoBlue,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18,
                                            height: 1.05,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(
                                    color: _cardBorder, height: 1),
                                const SizedBox(height: 10),
                                Row(
                                  children: <Widget>[
                                    const CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Color(0xFF2B3D56),
                                      child: Icon(
                                        Icons.engineering_rounded,
                                        size: 18,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            _lastTechnician ?? 'Sin datos',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const Text(
                                            'Técnico',
                                            style: TextStyle(
                                              color: _textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: _screenBg,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _cardBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.pushNamed(
                      AppRoutes.capture,
                      extra: CaptureArgs(printerId: widget.printerId),
                    ),
                    icon: const Icon(Icons.playlist_add_check_circle_rounded),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    label: const Text(
                      'Crear reporte de servicio',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: FilledButton.tonalIcon(
                          onPressed: () => ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text('Generando QR...'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            ),
                          icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF242E3D),
                            foregroundColor: Colors.white,
                          ),
                          label: const Text('Mostrar QR'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: FilledButton.tonalIcon(
                          onPressed: () => context.pushNamed(
                            AppRoutes.serviceHistory,
                            pathParameters: <String, String>{
                              'serialNumber': widget.serialNumber,
                            },
                            extra: ServiceHistoryArgs(
                              printerId: widget.printerId,
                              model: _modelName ?? widget.model,
                              serialNumber: widget.serialNumber,
                            ),
                          ),
                          icon: const Icon(Icons.history_rounded, size: 18),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF242E3D),
                            foregroundColor: Colors.white,
                          ),
                          label: const Text('Ver Historial'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.bgColor,
    required this.borderColor,
    required this.child,
  });

  final Color bgColor;
  final Color borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class _NoDataRow extends StatelessWidget {
  const _NoDataRow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8BA0BC),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Sin datos',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ServiceTypeVisual {
  const _ServiceTypeVisual({required this.icon, required this.color});
  final IconData icon;
  final Color color;
}
