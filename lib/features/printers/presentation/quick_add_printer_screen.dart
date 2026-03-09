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
  });

  final AppDatabase database;

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
  static const Map<String, String> _mockClientIds = <String, String>{
    'Beautyge Mexico': '10000000-0000-0000-0000-000000000001',
    'Generic Client': '10000000-0000-0000-0000-000000000002',
  };
  static const Map<String, String> _mockPlantIds = <String, String>{
    'Nave 1': '20000000-0000-0000-0000-000000000001',
    'Nave 2': '20000000-0000-0000-0000-000000000002',
    'Principal': '20000000-0000-0000-0000-000000000003',
  };
  static const Map<String, String> _mockAreaIds = <String, String>{
    'Linea de Empaque': '30000000-0000-0000-0000-000000000001',
    'Almacen': '30000000-0000-0000-0000-000000000002',
    'Recibo': '30000000-0000-0000-0000-000000000003',
  };

  static const List<String> _clientOptions = <String>[
    'Beautyge Mexico',
    'Generic Client',
  ];

  static const List<String> _plantOptions = <String>[
    'Nave 1',
    'Nave 2',
    'Principal',
  ];

  static const List<String> _areaOptions = <String>[
    'Linea de Empaque',
    'Almacen',
    'Recibo',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final Uuid _uuid = const Uuid();
  final TextEditingController _serialController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final FocusNode _modelFocusNode = FocusNode();

  String? _selectedClient;
  String? _selectedPlant;
  String? _selectedArea;
  bool _isSaving = false;

  @override
  void dispose() {
    _serialController.dispose();
    _modelController.dispose();
    _modelFocusNode.dispose();
    super.dispose();
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
                        DropdownButtonFormField<String>(
                          initialValue: _selectedClient,
                          items: _buildItems(_clientOptions),
                          decoration: const InputDecoration(
                            labelText: 'Cliente',
                            prefixIcon: Icon(Icons.business_rounded),
                          ),
                          validator: _requiredDropdownValidator,
                          onChanged: (String? value) {
                            setState(() {
                              _selectedClient = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedPlant,
                          items: _buildItems(_plantOptions),
                          decoration: const InputDecoration(
                            labelText: 'Planta',
                            prefixIcon: Icon(Icons.factory_rounded),
                          ),
                          validator: _requiredDropdownValidator,
                          onChanged: (String? value) {
                            setState(() {
                              _selectedPlant = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedArea,
                          items: _buildItems(_areaOptions),
                          decoration: const InputDecoration(
                            labelText: 'Area',
                            prefixIcon: Icon(Icons.place_rounded),
                          ),
                          validator: _requiredDropdownValidator,
                          onChanged: (String? value) {
                            setState(() {
                              _selectedArea = value;
                            });
                          },
                        ),
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

  List<DropdownMenuItem<String>> _buildItems(List<String> options) {
    return options
        .map(
          (String option) => DropdownMenuItem<String>(
            value: option,
            child: Text(option),
          ),
        )
        .toList();
  }

  String? _requiredTextValidator(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Campo obligatorio';
    }
    return null;
  }

  String? _requiredDropdownValidator(String? value) {
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
    final String clientName = _selectedClient!.trim();
    final String plantName = _selectedPlant!.trim();
    final String areaName = _selectedArea!.trim();

    setState(() {
      _isSaving = true;
    });

    try {
      final String printerId = _uuid.v4();
      final String qrUuid = _uuid.v4();

      final String clientId = _mockClientIds[clientName]!;
      final String plantId = _mockPlantIds[plantName]!;
      final String areaId = _mockAreaIds[areaName]!;

      await widget.database.transaction(() async {
        await widget.database.into(widget.database.clients).insertOnConflictUpdate(
              ClientsCompanion(
                id: drift.Value(clientId),
                name: drift.Value(clientName),
                isActive: const drift.Value(true),
              ),
            );

        await widget.database.into(widget.database.plants).insertOnConflictUpdate(
              PlantsCompanion(
                id: drift.Value(plantId),
                clientId: drift.Value(clientId),
                name: drift.Value(plantName),
              ),
            );

        await widget.database.into(widget.database.areas).insertOnConflictUpdate(
              AreasCompanion(
                id: drift.Value(areaId),
                plantId: drift.Value(plantId),
                name: drift.Value(areaName),
              ),
            );

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
      });

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
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<String> _resolveModelId(String modelInput) async {
    final ({String modelName, int dpi}) parsedModel =
        _parseModelAndDpi(modelInput);

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
