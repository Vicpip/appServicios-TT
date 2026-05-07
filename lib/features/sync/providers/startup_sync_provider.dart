import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:industrial_service_reports/data/local/local_database.dart';
import 'package:industrial_service_reports/features/auth/services/auth_service.dart';
import 'package:industrial_service_reports/features/sync/services/sync_service.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum StartupSyncPhase { idle, running, done, failed }

class StartupSyncState {
  const StartupSyncState({
    this.phase = StartupSyncPhase.idle,
    this.message = '',
    this.syncedThisSession = false,
  });

  final StartupSyncPhase phase;
  final String message;

  /// True if at least one successful download happened during this app session.
  final bool syncedThisSession;

  bool get isRunning => phase == StartupSyncPhase.running;
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class StartupSyncNotifier extends Notifier<StartupSyncState> {
  static const Duration _timeout = Duration(seconds: 10);

  @override
  StartupSyncState build() => const StartupSyncState();

  /// Sincroniza con el servidor: descarga catálogos y sube pendientes.
  ///
  /// - Con token válido: llama `SyncService.runSync()` que hace download + upload.
  /// - Sin token: solo intenta `downloadData()` (catálogos públicos si el servidor
  ///   lo permite; falla silenciosamente si requiere auth).
  /// Safe to call multiple times — concurrent calls are ignored (max 2 min timeout).
  Future<void> runAutoSync() async {
    if (state.phase == StartupSyncPhase.running) return;

    state = const StartupSyncState(
      phase: StartupSyncPhase.running,
      message: 'Sincronizando...',
    );

    try {
      final bool hasToken = await AuthService().hasValidTokenForSync();

      if (hasToken) {
        // runSync() (sync_service.dart:59) hace: downloadData() + sube pendientes.
        await SyncService(localDatabase)
            .runSync(
              onProgress: (String msg) {
                if (state.isRunning) {
                  state = StartupSyncState(
                    phase: StartupSyncPhase.running,
                    message: msg,
                  );
                }
              },
            )
            .timeout(const Duration(minutes: 2));
      } else {
        // Sin token: intenta solo descargar catálogos (10 s).
        await SyncService(localDatabase).downloadData().timeout(_timeout);
      }

      state = const StartupSyncState(
        phase: StartupSyncPhase.done,
        message: 'Sincronización completada',
        syncedThisSession: true,
      );
    } on TimeoutException {
      state = const StartupSyncState(
        phase: StartupSyncPhase.failed,
        message: 'Tiempo de espera agotado',
      );
    } on TokenExpiredException {
      state = const StartupSyncState(
        phase: StartupSyncPhase.failed,
        message: 'Token expirado — inicia sesión para sincronizar',
      );
    } catch (_) {
      state = const StartupSyncState(
        phase: StartupSyncPhase.failed,
        message: 'Sin conexión — usando datos locales',
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final startupSyncProvider =
    NotifierProvider<StartupSyncNotifier, StartupSyncState>(
  StartupSyncNotifier.new,
);
