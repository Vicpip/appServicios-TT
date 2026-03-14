import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:industrial_service_reports/core/router/app_routes.dart';
import 'package:industrial_service_reports/core/router/route_args.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/features/clients/providers/client_list_provider.dart';

class ClientListScreen extends ConsumerStatefulWidget {
  const ClientListScreen({
    super.key,
    required this.database,
  });

  final AppDatabase database;

  @override
  ConsumerState<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends ConsumerState<ClientListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<_ClientItem> _clients = <_ClientItem>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    try {
      final List<_ClientItem> items = await _buildClientItems();
      if (mounted) setState(() { _clients = items; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<_ClientItem>> _buildClientItems() async {
    final AppDatabase db = widget.database;
    final DateTime now = DateTime.now();

    final List<Client> allClients = await db.select(db.clients).get();
    // Load all clients (both active and inactive) for the "Todos" filter
    final List<Client> clients = List<Client>.from(allClients)
        ..sort((a, b) => a.name.compareTo(b.name));

    final List<_ClientItem> items = <_ClientItem>[];
    for (final Client client in clients) {
      // Contar impresoras activas
      final List<Printer> printers = await (db.select(db.printers)
            ..where((p) => p.clientId.equals(client.id)))
          .get();
      final int zebraUnits = printers.where((p) => p.isActive).length;

      // Contacto de la primera planta
      final Plant? firstPlant = await (db.select(db.plants)
            ..where((p) => p.clientId.equals(client.id))
            ..limit(1))
          .getSingleOrNull();
      final String contact = firstPlant?.contactName ?? 'Sin contacto';

      // Pólizas activas del cliente
      final List<Policy> allPolicies = await (db.select(db.policies)
            ..where((p) => p.clientId.equals(client.id)))
          .get();
      final List<Policy> activePolicies =
          allPolicies.where((p) => !p.endDate.isBefore(now)).toList();

      final _ClientStatus status;
      if (activePolicies.isEmpty) {
        status = _ClientStatus.noPolicy;
      } else {
        final bool soonExpiring =
            activePolicies.any((p) => p.endDate.difference(now).inDays < 30);
        status = soonExpiring ? _ClientStatus.risk : _ClientStatus.stable;
      }

      items.add(_ClientItem(
        displayId: _deriveDisplayId(client.id),
        client: client,
        contact: contact,
        zebraUnits: zebraUnits,
        policies: activePolicies.length,
        status: status,
        isActive: client.isActive,
      ));
    }
    return items;
  }

  int _deriveDisplayId(String uuid) {
    final String hex = uuid.replaceAll('-', '');
    return int.parse(hex.substring(0, 4), radix: 16) % 9000 + 1000;
  }

  @override
  Widget build(BuildContext context) {
    final ClientListState listState = ref.watch(clientListProvider);
    final List<_ClientItem> filteredClients = _filteredClients(listState);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const <Widget>[
            Icon(Icons.business_center_rounded, size: 22),
            SizedBox(width: 8),
            Text('Clientes'),
          ],
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppPalette.successDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppPalette.success),
                ),
                child: Row(
                  children: const <Widget>[
                    Icon(Icons.circle, color: AppPalette.success, size: 9),
                    SizedBox(width: 7),
                    Text(
                      'Sincronizado',
                      style: TextStyle(
                        color: AppPalette.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            children: <Widget>[
              TextField(
                controller: _searchController,
                onChanged: (String value) {
                  ref.read(clientListProvider.notifier).setSearchQuery(value);
                },
                decoration: const InputDecoration(
                  hintText: 'Nombre, RFC o Contacto',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    _FilterChip(
                      label: 'Todos',
                      selected: listState.selectedFilter == ClientFilter.all,
                      selectedColor: const Color(0xFF366B9C),
                      selectedBorderColor: const Color(0xFF5A9FD4),
                      onTap: () => ref
                          .read(clientListProvider.notifier)
                          .setFilter(ClientFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Con Poliza Activa',
                      selected: listState.selectedFilter ==
                          ClientFilter.activePolicy,
                      selectedColor: AppPalette.primary,
                      selectedBorderColor: AppPalette.primaryHover,
                      onTap: () => ref
                          .read(clientListProvider.notifier)
                          .setFilter(ClientFilter.activePolicy),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Sin Poliza',
                      selected:
                          listState.selectedFilter == ClientFilter.noPolicy,
                      selectedColor: AppPalette.surfaceDarkHighlight,
                      selectedBorderColor: AppPalette.surfaceDarkHighlight,
                      onTap: () => ref
                          .read(clientListProvider.notifier)
                          .setFilter(ClientFilter.noPolicy),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Con Riesgo',
                      selected: listState.selectedFilter == ClientFilter.risk,
                      selectedColor: const Color(0xFF5A1A1A),
                      selectedBorderColor: const Color(0xFFE57373),
                      onTap: () => ref
                          .read(clientListProvider.notifier)
                          .setFilter(ClientFilter.risk),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredClients.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay clientes para el filtro actual',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filteredClients.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (BuildContext context, int index) {
                          final _ClientItem item = filteredClients[index];
                          return _ClientCard(
                            client: item,
                            onTap: () => _openClientDetail(item.client),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.large(
        backgroundColor: AppPalette.primary,
        foregroundColor: AppPalette.backgroundLight,
        onPressed: _openAddClientScreen,
        tooltip: 'Nuevo Cliente',
        child: const Icon(Icons.add_rounded, size: 34),
      ),
    );
  }

  List<_ClientItem> _filteredClients(ClientListState listState) {
    final String query = listState.searchQuery.trim().toLowerCase();

    return _clients.where((_ClientItem client) {
      final bool matchesFilter = switch (listState.selectedFilter) {
        ClientFilter.all => true,
        ClientFilter.activePolicy => client.policies > 0,
        ClientFilter.noPolicy => client.status == _ClientStatus.noPolicy,
        ClientFilter.risk => client.status == _ClientStatus.risk,
      };

      if (!matchesFilter) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      return client.client.name.toLowerCase().contains(query) ||
          (client.client.rfc ?? '').toLowerCase().contains(query) ||
          client.contact.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openAddClientScreen() async {
    await context.pushNamed(AppRoutes.addClient);
    _loadClients();
  }

  Future<void> _openClientDetail(Client client) async {
    await context.pushNamed(
      AppRoutes.clientDetail,
      extra: ClientDetailArgs(client: client),
    );
    _loadClients();
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.selectedBorderColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final Color selectedBorderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: selectedColor,
      backgroundColor: AppPalette.surfaceDark,
      side: BorderSide(
        color: selected ? selectedBorderColor : AppPalette.surfaceDarkHighlight,
      ),
      labelStyle: const TextStyle(
        color: AppPalette.backgroundLight,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({
    required this.client,
    required this.onTap,
  });

  final _ClientItem client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final _StatusStyle statusStyle = _styleFor(client.status);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Card(
          color: AppPalette.surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppPalette.surfaceDarkHighlight),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusStyle.backgroundColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: statusStyle.borderColor),
                      ),
                      child: Text(
                        statusStyle.label,
                        style: TextStyle(
                          color: statusStyle.textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'ID: #${client.displayId}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  client.client.name,
                  style: const TextStyle(
                    color: AppPalette.backgroundLight,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    const Icon(Icons.badge_rounded,
                        size: 16, color: Colors.white70),
                    const SizedBox(width: 8),
                    Text(
                      client.client.rfc ?? 'Sin RFC',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    const Icon(Icons.person_rounded,
                        size: 16, color: Colors.white70),
                    const SizedBox(width: 8),
                    Text(
                      client.contact,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: <Widget>[
                    _StatPill(
                      icon: Icons.print_rounded,
                      text: '${client.zebraUnits} Zebra Units',
                    ),
                    _StatPill(
                      icon: Icons.description_rounded,
                      text: '${client.policies} Polizas',
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

  _StatusStyle _styleFor(_ClientStatus status) {
    return switch (status) {
      _ClientStatus.risk => const _StatusStyle(
          label: 'RIESGO CRITICO',
          backgroundColor: Color(0xFF5A1A1A),
          borderColor: Color(0xFFE57373),
          textColor: Color(0xFFFFB3B3),
        ),
      _ClientStatus.stable => const _StatusStyle(
          label: 'ESTABLE',
          backgroundColor: AppPalette.successDark,
          borderColor: AppPalette.success,
          textColor: AppPalette.success,
        ),
      _ClientStatus.noPolicy => const _StatusStyle(
          label: 'SIN POLIZA',
          backgroundColor: AppPalette.surfaceDarkHighlight,
          borderColor: Colors.white54,
          textColor: Colors.white70,
        ),
    };
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppPalette.surfaceDarkHighlight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: AppPalette.backgroundLight),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: AppPalette.backgroundLight,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ClientStatus {
  risk,
  stable,
  noPolicy,
}

class _ClientItem {
  const _ClientItem({
    required this.displayId,
    required this.client,
    required this.contact,
    required this.zebraUnits,
    required this.policies,
    required this.status,
    required this.isActive,
  });

  final int displayId;
  final Client client;
  final String contact;
  final int zebraUnits;
  final int policies;
  final _ClientStatus status;
  final bool isActive;
}

class _StatusStyle {
  const _StatusStyle({
    required this.label,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
}
