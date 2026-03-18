import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:industrial_service_reports/app.dart';
import 'package:industrial_service_reports/features/auth/providers/session_provider.dart';
import 'package:industrial_service_reports/features/auth/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restore session from secure storage so the router skips /login when a
  // valid JWT is already present from a previous session.
  final ProviderContainer container = ProviderContainer();
  final StoredSession? stored = await AuthService().getStoredSession();
  if (stored != null) {
    container.read(sessionProvider.notifier).setUser(
          userId: stored.userId,
          userName: stored.userName,
          email: stored.email,
          techId: stored.techId,
        );
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ServiceReportsApp(),
    ),
  );
}
