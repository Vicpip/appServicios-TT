import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/data/local/local_database.dart';
import 'package:industrial_service_reports/features/auth/providers/session_provider.dart';
import 'package:industrial_service_reports/features/auth/services/auth_service.dart';
import 'package:industrial_service_reports/features/reports/providers/capture_provider.dart';

class AuthNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      // Authenticate against the server — stores JWT in secure storage.
      final StoredSession session = await AuthService().login(
        email: email,
        password: password,
      );

      // Upsert the authenticated user in local DB so offline features work.
      final User? existing = await (localDatabase.select(localDatabase.users)
            ..where((u) => u.id.equals(session.userId)))
          .getSingleOrNull();

      if (existing == null) {
        await localDatabase.into(localDatabase.users).insertOnConflictUpdate(
              UsersCompanion.insert(
                id: session.userId,
                name: session.userName,
                email: session.email,
                role: session.role,
                code: Value(session.techId),
              ),
            );
      }

      ref.read(sessionProvider.notifier).setUser(
            userId: session.userId,
            userName: session.userName,
            email: session.email,
            techId: session.techId,
          );

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void logout() {
    AuthService().logout();
    ref.read(captureProvider.notifier).resetCapture();
    ref.read(sessionProvider.notifier).clearSession();
    state = const AsyncValue.data(null);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, void>(
  AuthNotifier.new,
);
