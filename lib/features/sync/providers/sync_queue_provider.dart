import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/data/local/local_database.dart';

/// Conteo reactivo de items con `estadoPeticion = 'pending'` en SyncQueue.
/// Se actualiza automáticamente cada vez que Drift detecta un cambio en la tabla.
final pendingSyncCountProvider = StreamProvider<int>((ref) {
  return (localDatabase.select(localDatabase.syncQueue)
        ..where((SyncQueue q) => q.estadoPeticion.equals('pending')))
      .watch()
      .map((List<SyncQueueData> list) => list.length);
});

/// Lista reactiva de items pendientes o fallidos, ordenados por fecha de creación.
/// Incluye tanto 'pending' como 'failed' para que la UI muestre todos los que
/// aún no se han subido al servidor.
final pendingSyncItemsProvider = StreamProvider<List<SyncQueueData>>((ref) {
  return (localDatabase.select(localDatabase.syncQueue)
        ..where((SyncQueue q) =>
            q.estadoPeticion.isIn(<String>['pending', 'failed']))
        ..orderBy(<OrderingTerm Function(SyncQueue)>[
          (SyncQueue q) => OrderingTerm.asc(q.fechaCreacion),
        ]))
      .watch();
});
