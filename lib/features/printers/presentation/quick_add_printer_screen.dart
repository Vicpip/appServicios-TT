import 'package:flutter/material.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/features/reports/presentation/express_capture_screen.dart';

class QuickAddPrinterScreen extends StatefulWidget {
  const QuickAddPrinterScreen({super.key});

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
  final TextEditingController _serialController = TextEditingController();

  String? _selectedClient;
  String? _selectedPlant;
  String? _selectedArea;

  @override
  void dispose() {
    _serialController.dispose();
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
              onPressed: _onSaveAndCreateReport,
              icon: const Icon(Icons.save_rounded),
              label: const Text(
                'Guardar y Crear Reporte',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
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
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        final String query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) {
          return _modelOptions;
        }

        return _modelOptions.where(
          (String option) => option.toLowerCase().contains(query),
        );
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

  void _onSaveAndCreateReport() {
    final bool isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: const Text('Complete los campos obligatorios'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppPalette.success,
        content: Text('Impresora registrada localmente'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const ExpressCaptureScreen(),
      ),
    );
  }
}
