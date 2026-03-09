import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:industrial_service_reports/core/router/app_routes.dart';
import 'package:industrial_service_reports/core/router/route_args.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';

class ClientDetailScreen extends StatefulWidget {
  const ClientDetailScreen({
    super.key,
    required this.database,
    required this.client,
  });

  final AppDatabase database;
  final Client client;

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  static const List<_PrinterMockItem> _mockPrinters = <_PrinterMockItem>[
    _PrinterMockItem(
      model: 'Zebra ZT411',
      serialNumber: '52J194200122',
      status: _PrinterStatus.active,
    ),
    _PrinterMockItem(
      model: 'Zebra ZT610',
      serialNumber: '99J882310245',
      status: _PrinterStatus.active,
    ),
    _PrinterMockItem(
      model: 'Zebra ZD421',
      serialNumber: '71K009830711',
      status: _PrinterStatus.maintenance,
    ),
  ];

  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detalle de Cliente'),
          actions: <Widget>[
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppPalette.successDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppPalette.success),
              ),
              child: Row(
                children: const <Widget>[
                  Icon(Icons.circle, size: 9, color: AppPalette.success),
                  SizedBox(width: 7),
                  Text(
                    'ONLINE',
                    style: TextStyle(
                      color: AppPalette.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (String value) {
                if (value == 'edit') {
                  context.pushNamed(
                    AppRoutes.addClient,
                    extra: AddClientArgs(client: widget.client),
                  );
                }
                if (value == 'delete') {
                  _confirmDeleteClient();
                }
              },
              itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Text('Editar Cliente'),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Text(
                    'Eliminar Cliente',
                    style: TextStyle(color: Color(0xFFE57373)),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              children: <Widget>[
                _CorporateInfoCard(
                  database: widget.database,
                  client: widget.client,
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppPalette.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppPalette.surfaceDarkHighlight),
                  ),
                  child: const TabBar(
                    labelColor: AppPalette.backgroundLight,
                    unselectedLabelColor: Colors.white60,
                    indicatorColor: AppPalette.primary,
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: <Widget>[
                      Tab(text: 'Impresoras'),
                      Tab(text: 'Polizas'),
                      Tab(text: 'Reportes'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: TabBarView(
                    children: <Widget>[
                      _PrintersTab(
                        database: widget.database,
                        printers: _mockPrinters,
                      ),
                      const _EmptyTab(
                        icon: Icons.assignment_outlined,
                        message: 'No hay polizas registradas aun',
                      ),
                      const _EmptyTab(
                        icon: Icons.description_outlined,
                        message: 'No hay reportes registrados aun',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteClient() async {
    if (_isDeleting) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Eliminar Cliente'),
          content: const Text(
            'Estas seguro de eliminar este cliente y todos sus datos?',
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

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await _deleteClientCascade(widget.client.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppPalette.success,
          content: Text('Cliente eliminado correctamente'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: const Text('No se pudo eliminar el cliente'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  Future<void> _deleteClientCascade(String clientId) async {
    await widget.database.transaction(() async {
      final List<Plant> plants = await (widget.database.select(widget.database.plants)
            ..where((tbl) => tbl.clientId.equals(clientId)))
          .get();
      final List<String> plantIds = plants.map((Plant p) => p.id).toList();

      final List<Printer> printers =
          await (widget.database.select(widget.database.printers)
                ..where((tbl) => tbl.clientId.equals(clientId)))
              .get();
      final List<String> printerIds = printers.map((Printer p) => p.id).toList();

      final List<Policy> policies =
          await (widget.database.select(widget.database.policies)
                ..where((tbl) => tbl.clientId.equals(clientId)))
              .get();
      final List<String> policyIds = policies.map((Policy p) => p.id).toList();

      final List<Report> reports = printerIds.isEmpty
          ? <Report>[]
          : await (widget.database.select(widget.database.reports)
                ..where((tbl) => tbl.printerId.isIn(printerIds)))
              .get();
      final List<String> reportIds = reports.map((Report r) => r.id).toList();

      final List<PolicyDelivery> deliveries = policyIds.isEmpty
          ? <PolicyDelivery>[]
          : await (widget.database.select(widget.database.policyDeliveries)
                ..where((tbl) => tbl.policyId.isIn(policyIds)))
              .get();
      final List<String> deliveryIds =
          deliveries.map((PolicyDelivery d) => d.id).toList();

      if (reportIds.isNotEmpty) {
        await (widget.database.delete(widget.database.entityFiles)
              ..where(
                (tbl) => drift.Expression.and(<drift.Expression<bool>>[
                  tbl.entityType.equals('report'),
                  tbl.entityId.isIn(reportIds),
                ]),
              ))
            .go();
        await (widget.database.delete(widget.database.reportActions)
              ..where((tbl) => tbl.reportId.isIn(reportIds)))
            .go();
        await (widget.database.delete(widget.database.reportParts)
              ..where((tbl) => tbl.reportId.isIn(reportIds)))
            .go();
        await (widget.database.delete(widget.database.policyDeliveryReports)
              ..where((tbl) => tbl.reportId.isIn(reportIds)))
            .go();
        await (widget.database.delete(widget.database.reports)
              ..where((tbl) => tbl.id.isIn(reportIds)))
            .go();
      }

      if (deliveryIds.isNotEmpty) {
        await (widget.database.delete(widget.database.entityFiles)
              ..where(
                (tbl) => drift.Expression.and(<drift.Expression<bool>>[
                  tbl.entityType.equals('policy_delivery'),
                  tbl.entityId.isIn(deliveryIds),
                ]),
              ))
            .go();
        await (widget.database.delete(widget.database.policyDeliveryReports)
              ..where((tbl) => tbl.deliveryId.isIn(deliveryIds)))
            .go();
        await (widget.database.delete(widget.database.policyDeliveries)
              ..where((tbl) => tbl.id.isIn(deliveryIds)))
            .go();
      }

      if (policyIds.isNotEmpty) {
        await (widget.database.delete(widget.database.policyPrinters)
              ..where((tbl) => tbl.policyId.isIn(policyIds)))
            .go();
        await (widget.database.delete(widget.database.policies)
              ..where((tbl) => tbl.id.isIn(policyIds)))
            .go();
      }

      if (printerIds.isNotEmpty) {
        await (widget.database.delete(widget.database.policyPrinters)
              ..where((tbl) => tbl.printerId.isIn(printerIds)))
            .go();
        await (widget.database.delete(widget.database.printers)
              ..where((tbl) => tbl.id.isIn(printerIds)))
            .go();
      }

      if (plantIds.isNotEmpty) {
        await (widget.database.delete(widget.database.areas)
              ..where((tbl) => tbl.plantId.isIn(plantIds)))
            .go();
        await (widget.database.delete(widget.database.plants)
              ..where((tbl) => tbl.id.isIn(plantIds)))
            .go();
      }

      await (widget.database.delete(widget.database.clients)
            ..where((tbl) => tbl.id.equals(clientId)))
          .go();
    });
  }
}

class _CorporateInfoCard extends StatelessWidget {
  const _CorporateInfoCard({
    required this.database,
    required this.client,
  });

  final AppDatabase database;
  final Client client;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppPalette.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppPalette.surfaceDarkHighlight),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppPalette.primaryHover.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.factory_rounded,
                    color: AppPalette.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        client.name,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.backgroundLight,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'RFC: ${client.rfc ?? 'Sin RFC'}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: Colors.white60,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    client.address ?? 'Ubicacion industrial no registrada',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StreamBuilder<Plant?>(
              stream: (database.select(database.plants)
                    ..where((tbl) => tbl.clientId.equals(client.id))
                    ..limit(1))
                  .watchSingleOrNull(),
              builder: (BuildContext context, AsyncSnapshot<Plant?> snapshot) {
                final Plant? plant = snapshot.data;
                final String contact = plant?.contactName?.trim().isNotEmpty == true
                    ? plant!.contactName!
                    : 'Cargando contacto...';

                return Row(
                  children: <Widget>[
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                      color: Colors.white60,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      contact,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PrintersTab extends StatelessWidget {
  const _PrintersTab({
    required this.database,
    required this.printers,
  });

  final AppDatabase database;
  final List<_PrinterMockItem> printers;

  @override
  Widget build(BuildContext context) {
    final int total = printers.length;

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              'EQUIPOS REGISTRADOS ($total)',
              style: const TextStyle(
                color: Colors.white60,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                fontSize: 12,
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => context.pushNamed(AppRoutes.quickAddPrinter),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nueva'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: printers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int index) {
              return _PrinterCard(printer: printers[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _PrinterCard extends StatelessWidget {
  const _PrinterCard({
    required this.printer,
  });

  final _PrinterMockItem printer;

  @override
  Widget build(BuildContext context) {
    final bool isActive = printer.status == _PrinterStatus.active;
    final Color statusBg = isActive
        ? AppPalette.successDark.withValues(alpha: 0.35)
        : AppPalette.surfaceDarkHighlight.withValues(alpha: 0.55);
    final Color statusBorder = isActive
        ? AppPalette.success.withValues(alpha: 0.35)
        : Colors.white24;
    final Color statusText = isActive ? AppPalette.success : Colors.white54;

    return Card(
      color: AppPalette.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppPalette.surfaceDarkHighlight),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2433),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppPalette.surfaceDarkHighlight),
                  ),
                  child: const Icon(
                    Icons.print_rounded,
                    color: Color(0xFFDFE7F3),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        printer.model,
                        style: const TextStyle(
                          color: AppPalette.backgroundLight,
                          fontWeight: FontWeight.w800,
                          fontSize: 21,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'S/N: ${printer.serialNumber}',
                        style: const TextStyle(
                          color: Color(0xFF8BC2FF),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusBorder),
                  ),
                  child: Text(
                    isActive ? 'ACTIVO' : 'MANTENIMIENTO',
                    style: TextStyle(
                      color: statusText,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Detalle de impresora en construccion'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2A3342),
                      foregroundColor: const Color(0xFFDCE3EF),
                      elevation: 0,
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Ver Detalles'),
                  ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: ElevatedButton(
                    onPressed: () => context.pushNamed(AppRoutes.capture),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.primary,
                      foregroundColor: AppPalette.backgroundLight,
                      elevation: 0,
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('📝 Reporte'),
                  ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 54, color: Colors.white30),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
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

enum _PrinterStatus {
  active,
  maintenance,
}

class _PrinterMockItem {
  const _PrinterMockItem({
    required this.model,
    required this.serialNumber,
    required this.status,
  });

  final String model;
  final String serialNumber;
  final _PrinterStatus status;
}
