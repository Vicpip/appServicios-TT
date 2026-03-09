import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ClientFilter { activePolicy, noPolicy, risk }

@immutable
class ClientListState {
  const ClientListState({
    this.searchQuery = '',
    this.selectedFilter = ClientFilter.activePolicy,
  });

  final String searchQuery;
  final ClientFilter selectedFilter;

  ClientListState copyWith({
    String? searchQuery,
    ClientFilter? selectedFilter,
  }) {
    return ClientListState(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedFilter: selectedFilter ?? this.selectedFilter,
    );
  }
}

class ClientListNotifier extends Notifier<ClientListState> {
  @override
  ClientListState build() => const ClientListState();

  void setFilter(ClientFilter filter) =>
      state = state.copyWith(selectedFilter: filter);

  void setSearchQuery(String query) =>
      state = state.copyWith(searchQuery: query);
}

final clientListProvider =
    NotifierProvider<ClientListNotifier, ClientListState>(
  ClientListNotifier.new,
);
