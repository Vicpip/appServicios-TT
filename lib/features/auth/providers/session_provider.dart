import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class SessionState {
  const SessionState({
    this.userId = '',
    this.userName = 'Juan Perez',
    this.email = 'juan.perez@empresa.com',
    this.techId = '#T-8492',
    this.lastSyncText = 'Hoy 08:30 AM',
    this.isOnline = true,
  });

  final String userId;
  final String userName;
  final String email;
  final String techId;
  final String lastSyncText;
  final bool isOnline;

  SessionState copyWith({
    String? userId,
    String? userName,
    String? email,
    String? techId,
    String? lastSyncText,
    bool? isOnline,
  }) {
    return SessionState(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      email: email ?? this.email,
      techId: techId ?? this.techId,
      lastSyncText: lastSyncText ?? this.lastSyncText,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  static const SessionState empty = SessionState(
    userId: '',
    userName: '',
    email: '',
    techId: '',
    lastSyncText: '',
    isOnline: false,
  );
}

class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() => SessionState.empty;

  void setUser({
    required String userId,
    required String userName,
    required String email,
    required String techId,
  }) {
    state = state.copyWith(
      userId: userId,
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
