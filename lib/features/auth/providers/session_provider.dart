import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class SessionState {
  const SessionState({
    this.userName = 'Juan Perez',
    this.email = 'juan.perez@empresa.com',
    this.techId = '#T-8492',
    this.pendingSyncCount = 3,
    this.lastSyncText = 'Hoy 08:30 AM',
    this.isOnline = true,
  });

  final String userName;
  final String email;
  final String techId;
  final int pendingSyncCount;
  final String lastSyncText;
  final bool isOnline;

  SessionState copyWith({
    String? userName,
    String? email,
    String? techId,
    int? pendingSyncCount,
    String? lastSyncText,
    bool? isOnline,
  }) {
    return SessionState(
      userName: userName ?? this.userName,
      email: email ?? this.email,
      techId: techId ?? this.techId,
      pendingSyncCount: pendingSyncCount ?? this.pendingSyncCount,
      lastSyncText: lastSyncText ?? this.lastSyncText,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  static const SessionState empty = SessionState(
    userName: '',
    email: '',
    techId: '',
    pendingSyncCount: 0,
    lastSyncText: '',
    isOnline: false,
  );
}

class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() => SessionState.empty;

  void setUser({
    required String userName,
    required String email,
    required String techId,
  }) {
    state = state.copyWith(
      userName: userName,
      email: email,
      techId: techId,
    );
  }

  void clearSession() {
    state = SessionState.empty;
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(
  SessionNotifier.new,
);
