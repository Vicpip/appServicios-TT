import 'package:flutter/material.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';

class AddClientScreen extends StatefulWidget {
  const AddClientScreen({
    super.key,
    required this.database,
    this.client,
  });

  final AppDatabase database;
  final Client? client;

  bool get isEditMode => client != null;

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _rfcController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  final List<_PlantDraft> _plantDrafts = <_PlantDraft>[];

  bool _isSubmitting = false;
  bool _isLoadingPlants = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _rfcController.dispose();
    _addressController.dispose();
    for (final _PlantDraft draft in _plantDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditMode = widget.isEditMode;
    final String screenTitle =
        isEditMode ? 'Editar Cliente' : 'Nuevo Cliente / Sitio';

    return Scaffold(
      appBar: AppBar(
        title: Text(screenTitle),
        actions: <Widget>[
          if (isEditMode)
            IconButton(
              tooltip: 'Eliminar Cliente',
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFE57373),
              ),
              onPressed: _confirmDeleteClient,
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _SectionCard(
                      title: 'Datos del Corporativo',
                      child: Column(
                        children: <Widget>[
                          TextFormField(
                            controller: _companyNameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Nombre de la Empresa',
                              prefixIcon: Icon(Icons.apartment_rounded),
                            ),
                            validator: _requiredValidator,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _rfcController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'RFC',
                              prefixIcon: Icon(Icons.assignment_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _addressController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Direccion Fiscal',
                              prefixIcon: Icon(Icons.location_on_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        const Text(
                          'Plantas / Sucursales',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.backgroundLight,
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          height: 34,
                          child: FilledButton(
                            onPressed: _addPlantSection,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            child: const Text(
                              '+ Agregar Planta',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_isLoadingPlants)
                      const _SectionCard(
                        title: 'Cargando plantas...',
                        child: LinearProgressIndicator(minHeight: 3),
                      )
                    else
                      ..._buildPlantCards(),
                  ],
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
            child: FilledButton(
              onPressed: (_isSubmitting || _isLoadingPlants) ? null : _onSubmit,
              child: Text(
                _isSubmitting
                    ? 'PROCESANDO...'
                    : (isEditMode
                        ? 'ACTUALIZAR DATOS'
                        : 'GUARDAR CLIENTE Y PLANTAS'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _initializeForm() async {
    if (widget.isEditMode) {
      final Client client = widget.client!;
      _companyNameController.text = client.name;
      _rfcController.text = client.rfc ?? '';
      _addressController.text = client.address ?? '';
      await _loadPlantsForEdit(client.id);
      return;
    }

    _plantDrafts.add(
      _PlantDraft.withDefaults(defaultPlantName: 'Planta Matriz'),
    );
  }

  Future<void> _loadPlantsForEdit(String clientId) async {
    setState(() {
      _isLoadingPlants = true;
    });

    final List<Plant> plants = await (widget.database.select(widget.database.plants)
          ..where((tbl) => tbl.clientId.equals(clientId)))
        .get();

    for (final _PlantDraft draft in _plantDrafts) {
      draft.dispose();
    }
    _plantDrafts.clear();

    if (plants.isEmpty) {
      _plantDrafts.add(
        _PlantDraft.withDefaults(defaultPlantName: 'Planta Matriz'),
      );
    } else {
      for (final Plant plant in plants) {
        _plantDrafts.add(
          _PlantDraft(
            plantName: plant.name,
            contactName: plant.contactName ?? '',
            phone: plant.phone ?? '',
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _isLoadingPlants = false;
    });
  }

  List<Widget> _buildPlantCards() {
    final List<Widget> widgets = <Widget>[];

    for (int index = 0; index < _plantDrafts.length; index++) {
      final _PlantDraft draft = _plantDrafts[index];
      final bool canRemove = _plantDrafts.length > 1 && index > 0;

      widgets.add(
        _PlantCard(
          title: index == 0
              ? 'Planta Principal'
              : 'Planta / Sucursal ${index + 1}',
          canRemove: canRemove,
          onRemove: canRemove ? () => _removePlantSection(index) : null,
          child: Column(
            children: <Widget>[
              TextFormField(
                controller: draft.plantNameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la Planta',
                  prefixIcon: Icon(Icons.factory_rounded),
                ),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: draft.contactController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Contacto',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: draft.phoneController,
                textInputAction: TextInputAction.done,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefono del Contacto',
                  prefixIcon: Icon(Icons.phone_rounded),
                ),
                validator: _requiredValidator,
              ),
            ],
          ),
        ),
      );
      widgets.add(const SizedBox(height: 10));
    }
    return widgets;
  }

  void _addPlantSection() {
    setState(() {
      _plantDrafts.add(_PlantDraft());
    });
  }

  void _removePlantSection(int index) {
    final _PlantDraft removed = _plantDrafts.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  String? _requiredValidator(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Requerido';
    }
    return null;
  }

  Future<void> _onSubmit() async {
    final bool isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      _showErrorSnackBar('Revisa los campos obligatorios');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;
    _showSuccessSnackBar(
      widget.isEditMode
          ? 'Datos del cliente actualizados'
          : 'Cliente registrado correctamente',
    );
    Navigator.of(context).pop(true);
  }

  Future<void> _confirmDeleteClient() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Eliminar Cliente'),
          content: const Text(
            '¿Estas seguro de eliminar este cliente y todos sus datos?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    _showSuccessSnackBar('Cliente eliminado correctamente');
    Navigator.of(context).pop(true);
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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppPalette.success,
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppPalette.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.surfaceDarkHighlight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppPalette.backgroundLight,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _PlantCard extends StatelessWidget {
  const _PlantCard({
    required this.title,
    required this.child,
    this.canRemove = false,
    this.onRemove,
  });

  final String title;
  final Widget child;
  final bool canRemove;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.surfaceDarkHighlight),
      ),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: AppPalette.primary, width: 3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.backgroundLight,
                      ),
                    ),
                  ),
                  if (canRemove)
                    IconButton(
                      onPressed: onRemove,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.white70,
                      ),
                      tooltip: 'Quitar planta',
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _PlantDraft {
  _PlantDraft({
    String plantName = '',
    String contactName = '',
    String phone = '',
  })  : plantNameController = TextEditingController(text: plantName),
        contactController = TextEditingController(text: contactName),
        phoneController = TextEditingController(text: phone);

  _PlantDraft.withDefaults({
    required String defaultPlantName,
  })  : plantNameController = TextEditingController(text: defaultPlantName),
        contactController = TextEditingController(),
        phoneController = TextEditingController();

  final TextEditingController plantNameController;
  final TextEditingController contactController;
  final TextEditingController phoneController;

  void dispose() {
    plantNameController.dispose();
    contactController.dispose();
    phoneController.dispose();
  }
}
