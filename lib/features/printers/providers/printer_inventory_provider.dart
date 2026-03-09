import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PrinterFilter { all, byClient, byPlant, byContact }

@immutable
class PrinterInventoryState {
  const PrinterInventoryState({
    this.searchQuery = '',
    this.selectedFilter = PrinterFilter.all,
    this.selectedClient,
    this.selectedPlant,
    this.selectedContact,
  });

  final String searchQuery;
  final PrinterFilter selectedFilter;
  final String? selectedClient;
  final String? selectedPlant;
  final String? selectedContact;

  PrinterInventoryState copyWith({
    String? searchQuery,
    PrinterFilter? selectedFilter,
    String? selectedClient,
    String? selectedPlant,
    String? selectedContact,
  }) {
    return PrinterInventoryState(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      selectedClient: selectedClient ?? this.selectedClient,
      selectedPlant: selectedPlant ?? this.selectedPlant,
      selectedContact: selectedContact ?? this.selectedContact,
    );
  }

  PrinterInventoryState clearSubFilters() {
    return PrinterInventoryState(
      searchQuery: searchQuery,
      selectedFilter: selectedFilter,
    );
  }
}

class PrinterInventoryNotifier extends Notifier<PrinterInventoryState> {
  @override
  PrinterInventoryState build() => const PrinterInventoryState();

  void setFilter(PrinterFilter filter) {
    state = state.clearSubFilters().copyWith(selectedFilter: filter);
  }

  void setSearchQuery(String query) =>
      state = state.copyWith(searchQuery: query);

  void setClientFilter(String? client) =>
      state = state.copyWith(selectedClient: client);

  void setPlantFilter(String? plant) =>
      state = state.copyWith(selectedPlant: plant);

  void setContactFilter(String? contact) =>
      state = state.copyWith(selectedContact: contact);
}

final printerInventoryProvider =
    NotifierProvider<PrinterInventoryNotifier, PrinterInventoryState>(
  PrinterInventoryNotifier.new,
);
