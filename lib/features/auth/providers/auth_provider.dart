import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/data/local/local_database.dart';
import 'package:industrial_service_reports/features/auth/providers/session_provider.dart';
import 'package:industrial_service_reports/features/reports/providers/capture_provider.dart';
import 'package:uuid/uuid.dart';

class AuthNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> login({
    required String identifier,
    required String pin,
  }) async {
    state = const AsyncValue.loading();
    try {
      if (identifier.trim().isEmpty || pin.trim().length < 4) {
        throw Exception('Credenciales inválidas');
      }

      final String email = identifier.trim();

      // Buscar usuario en DB
      final User? existingUser = await (localDatabase.select(localDatabase.users)
            ..where((u) => u.email.equals(email)))
          .getSingleOrNull();

      late String userId;
      late String userName;

      if (existingUser != null) {
        userId = existingUser.id;
        userName = existingUser.name;
      } else {
        // Crear usuario nuevo
        userId = const Uuid().v4();
        userName = email.contains('@') ? email.split('@').first : email;
        await localDatabase.into(localDatabase.users).insert(
              UsersCompanion.insert(
                id: userId,
                name: userName,
                email: email,
                role: 'technician',
              ),
            );
      }

      ref.read(sessionProvider.notifier).setUser(
            userId: userId,
            userName: userName,
            email: email,
            techId: userId,
          );

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void logout() {
    ref.read(captureProvider.notifier).resetCapture();
    ref.read(sessionProvider.notifier).clearSession();
    state = const AsyncValue.data(null);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, void>(
  AuthNotifier.new,
);
