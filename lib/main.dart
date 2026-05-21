import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:industrial_service_reports/app.dart';
import 'package:industrial_service_reports/features/auth/providers/session_provider.dart';
import 'package:industrial_service_reports/features/auth/services/auth_service.dart';
import 'package:industrial_service_reports/features/sync/providers/startup_sync_provider.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

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

  // Kick off startup sync in the background. The login screen watches
  // startupSyncProvider and blocks the login button (max 10 s) until it
  // resolves so fresh catalog data is available before the first login.
  // If there is no token or no connectivity the sync fails silently and
  // the offline flow continues unchanged.
  container.read(startupSyncProvider.notifier).runAutoSync();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ServiceReportsApp(),
    ),
  );
}
