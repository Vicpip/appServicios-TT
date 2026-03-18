import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:industrial_service_reports/core/router/app_routes.dart';
import 'package:industrial_service_reports/core/router/route_args.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:uuid/uuid.dart';

class QuickAddPrinterScreen extends StatefulWidget {
  const QuickAddPrinterScreen({
    super.key,
    required this.database,
    this.initialClientId,
  });

  final AppDatabase database;
  final String? initialClientId;

  @override
  State<QuickAddPrinterScreen> createState() => _QuickAddPrinterScreenState();
}

class _QuickAddPrinterScreenState extends State<QuickAddPrinterScreen> {
  static const List<String> _modelOptions = <String>[
    'ZT411 - 203dpi',
    'ZT610 - 600dpi',
    'ZD421 - 203dpi',
    '105SL Plus',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final Uuid _uuid = const Uuid();
  final TextEditingController _serialController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final FocusNode _modelFocusNode = FocusNode();
  final FocusNode _areaFocusNode = FocusNode();

  List<Client> _clients = <Client>[];
  List<Plant> _plants = <Plant>[];
  List<Area> _areas = <Area>[];
  Client? _selectedClientObj;
  Plant? _selectedPlantObj;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _serialController.dispose();
    _modelController.dispose();
    _areaController.dispose();
    _modelFocusNode.dispose();
    _areaFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    final List<Client> clients = await (widget.database.select(widget.database.clients)
          ..where((c) => c.isActive.isValue(true)))
        .get();

    if (!mounted) return;

    if (widget.initialClientId != null) {
      final Client? preselected = clients
          .where((c) => c.id == widget.initialClientId)
          .firstOrNull;
      if (preselected != null) {
        setState(() {
          _clients = clients;
          _selectedClientObj = preselected;
        });
        await _loadPlants(preselected.id);
        return;
      }
    }

    setState(() => _clients = clients);
  }

  Future<void> _loadPlants(String clientId) async {
    final List<Plant> plants = await (widget.database.select(widget.database.plants)
          ..where((p) => p.clientId.equals(clientId)))
        .get();

    if (!mounted) return;
    setState(() {
      _plants = plants;
      _selectedPlantObj = null;
      _areas = <Area>[];
    });
    _areaController.clear();
  }

  Future<void> _loadAreas(String plantId) async {
    final List<Area> areas = await (widget.database.select(widget.database.areas)
          ..where((a) => a.plantId.equals(plantId)))
        .get();

    if (!mounted) return;
    setState(() {
      _areas = areas;
    });
    _areaController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Impresora'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Alta Rapida de Impresora',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.backgroundLight,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _serialController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Numero de Serie',
                            hintText: 'Ejemplo: 710232000196',
                            prefixIcon: Icon(Icons.qr_code_2_rounded),
                          ),
                          validator: _requiredTextValidator,
                        ),
                        const SizedBox(height: 12),
                        _buildModelAutocompleteField(),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<Client>(
                          value: _selectedClientObj,
                          items: _clients
                              .map((Client c) => DropdownMenuItem<Client>(
                                    value: c,
                                    child: Text(c.name),
                                  ))
                              .toList(),
                          decoration: const InputDecoration(
                            labelText: 'Cliente',
                            prefixIcon: Icon(Icons.business_rounded),
                          ),
                          validator: (Client? v) =>
                              v == null ? 'Campo obligatorio' : null,
                          onChanged: (Client? value) async {
                            setState(() {
                              _selectedClientObj = value;
                              _plants = <Plant>[];
                              _areas = <Area>[];
                              _selectedPlantObj = null;
                            });
                            _areaController.clear();
                            if (value != null) {
                              await _loadPlants(value.id);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<Plant>(
                          value: _selectedPlantObj,
                          items: _plants
                              .map((Plant p) => DropdownMenuItem<Plant>(
                                    value: p,
                                    child: Text(p.name),
                                  ))
                              .toList(),
                          decoration: const InputDecoration(
                            labelText: 'Planta',
                            prefixIcon: Icon(Icons.factory_rounded),
                          ),
                          validator: (Plant? v) =>
                              v == null ? 'Campo obligatorio' : null,
                          onChanged: (Plant? value) async {
                            setState(() {
                              _selectedPlantObj = value;
                              _areas = <Area>[];
                            });
                            _areaController.clear();
                            if (value != null) {
                              await _loadAreas(value.id);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildAreaAutocompleteField(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: const BoxDecoration(
            color: AppPalette.surfaceDark,
            border: Border(top: BorderSide(color: AppPalette.surfaceDarkHighlight)),
          ),
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _onSaveAndCreateReport,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(
                _isSaving ? 'Guardando...' : 'Guardar y Crear Reporte',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _requiredTextValidator(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Campo obligatorio';
    }
    return null;
  }

  Widget _buildModelAutocompleteField() {
    return RawAutocomplete<String>(
      textEditingController: _modelController,
      focusNode: _modelFocusNode,
      optionsBuilder: (TextEditingValue textEditingValue) {
        final String query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) {
          return _modelOptions;
        }
        return _modelOptions.where(
          (String option) => option.toLowerCase().contains(query),
        );
      },
      onSelected: (String selectedOption) {
        _modelController.text = selectedOption;
      },
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController textEditingController,
        FocusNode focusNode,
        VoidCallback onFieldSubmitted,
      ) {
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Modelo y DPI',
            hintText: 'Ejemplo: ZT610 - 600dpi',
            prefixIcon: Icon(Icons.print_rounded),
          ),
          validator: _requiredTextValidator,
          onEditingComplete: () {
            onFieldSubmitted();
            focusNode.unfocus();
          },
        );
      },
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<String> onSelected,
        Iterable<String> options,
      ) {
        if (options.isEmpty) {
          return const SizedBox.shrink();
        }

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 828),
              decoration: BoxDecoration(
                color: AppPalette.surfaceDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppPalette.surfaceDarkHighlight),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      child: Text(
                        option,
                        style: const TextStyle(
                          color: AppPalette.backgroundLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _onSaveAndCreateReport() async {
    final bool isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      _showErrorSnackBar('Complete los campos obligatorios');
      return;
    }

    final String serialNumber = _serialController.text.trim();
    final String modelInput = _modelController.text.trim();

    setState(() => _isSaving = true);

    try {
      final String printerId = _uuid.v4();
      final String qrUuid = _uuid.v4();

      final String clientId = _selectedClientObj!.id;
      final String plantId = _selectedPlantObj!.id;
      final String areaId = await _resolveAreaId(_areaController.text.trim(), plantId);

      final String modelId = await _resolveModelId(modelInput);

      await widget.database.into(widget.database.printers).insert(
            PrintersCompanion.insert(
              id: printerId,
              qrUuid: qrUuid,
              serialNumber: serialNumber,
              clientId: clientId,
              plantId: plantId,
              areaId: areaId,
              modelId: modelId,
              isActive: const drift.Value(true),
            ),
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppPalette.success,
          content: Text('Impresora guardada localmente'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      context.pushReplacementNamed(
        AppRoutes.capture,
        extra: CaptureArgs(printerId: printerId),
      );
    } catch (error) {
      if (!mounted) return;

      final String errorText = error.toString().toLowerCase();
      if (errorText.contains('unique constraint failed: printers.serial_number')) {
        _showErrorSnackBar('El numero de serie ya existe en la base local');
      } else {
        _showErrorSnackBar('No se pudo guardar la impresora localmente');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<String> _resolveAreaId(String areaName, String plantId) async {
    final existing = await (widget.database.select(widget.database.areas)
          ..where((a) => a.plantId.equals(plantId) & a.name.equals(areaName)))
        .getSingleOrNull();
    if (existing != null) return existing.id;

    final String areaId = _uuid.v4();
    await widget.database.into(widget.database.areas).insert(
          AreasCompanion.insert(id: areaId, plantId: plantId, name: areaName),
        );
    return areaId;
  }

  Widget _buildAreaAutocompleteField() {
    return RawAutocomplete<String>(
      textEditingController: _areaController,
      focusNode: _areaFocusNode,
      optionsBuilder: (TextEditingValue textEditingValue) {
        final String query = textEditingValue.text.trim().toLowerCase();
        final Iterable<String> names = _areas.map((Area a) => a.name);
        if (query.isEmpty) return names;
        return names.where((String n) => n.toLowerCase().contains(query));
      },
      onSelected: (String selectedOption) {
        _areaController.text = selectedOption;
      },
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController textEditingController,
        FocusNode focusNode,
        VoidCallback onFieldSubmitted,
      ) {
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Área',
            hintText: 'Escribe o selecciona un área',
            prefixIcon: Icon(Icons.place_rounded),
          ),
          validator: _requiredTextValidator,
          onEditingComplete: () {
            onFieldSubmitted();
            focusNode.unfocus();
          },
        );
      },
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<String> onSelected,
        Iterable<String> options,
      ) {
        if (options.isEmpty) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 828),
              decoration: BoxDecoration(
                color: AppPalette.surfaceDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppPalette.surfaceDarkHighlight),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      child: Text(
                        option,
                        style: const TextStyle(
                          color: AppPalette.backgroundLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String> _resolveModelId(String modelInput) async {
    final ({String modelName, int dpi}) parsedModel = _parseModelAndDpi(modelInput);

    final existingModel = await (widget.database.select(widget.database.catalogModels)
          ..where(
            (tbl) =>
                tbl.brand.equals('ZEBRA') &
                tbl.modelName.equals(parsedModel.modelName) &
                tbl.dpi.equals(parsedModel.dpi),
          ))
        .getSingleOrNull();

    if (existingModel != null) {
      return existingModel.id;
    }

    final String modelId = _uuid.v4();
    await widget.database.into(widget.database.catalogModels).insert(
          CatalogModelsCompanion.insert(
            id: modelId,
            brand: 'ZEBRA',
            modelName: parsedModel.modelName,
            dpi: parsedModel.dpi,
            isActive: const drift.Value(true),
          ),
        );
    return modelId;
  }

  ({String modelName, int dpi}) _parseModelAndDpi(String rawInput) {
    final String trimmed = rawInput.trim();
    final RegExp dpiRegex = RegExp(r'(\d{2,4})\s*dpi', caseSensitive: false);
    final RegExpMatch? dpiMatch = dpiRegex.firstMatch(trimmed);

    final int dpi = int.tryParse(dpiMatch?.group(1) ?? '') ?? 203;
    String modelName = trimmed;

    if (dpiMatch != null) {
      modelName = trimmed
          .replaceFirst(dpiMatch.group(0)!, '')
          .replaceAll(RegExp(r'[-–]+'), ' ')
          .trim();
    }

    if (modelName.isEmpty) {
      modelName = trimmed;
    }

    return (modelName: modelName, dpi: dpi);
  }

  void _showErrorSnackBar(String message) {
    final ThemeData theme = Theme.of(context);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: theme.colorScheme.error,
        content: Text(
          message,
          style: TextStyle(color: theme.colorScheme.onError),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
