import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:industrial_service_reports/features/auth/providers/session_provider.dart';

class AuthNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> login({
    required String identifier,
    required String pin,
  }) async {
    state = const AsyncValue.loading();
    try {
      await Future<void>.delayed(const Duration(seconds: 1));

      if (identifier.trim().isEmpty || pin.trim().length < 4) {
        throw Exception('Credenciales inválidas');
      }

      ref.read(sessionProvider.notifier).setUser(
            userName: 'Juan Perez',
            email: identifier.trim(),
            techId: '#T-8492',
          );

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void logout() {
    ref.read(sessionProvider.notifier).clearSession();
    state = const AsyncValue.data(null);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, void>(
  AuthNotifier.new,
);
