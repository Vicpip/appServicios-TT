import 'package:drift/drift.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';

/// Cuántos elementos de la cola de sincronización (pendientes o con error)
/// pertenecen a [clientId]: reportes de sus impresoras, entregas de sus
/// pólizas y los archivos/firmas/PDF ligados a ellos.
Future<int> pendingSyncCountForClient(AppDatabase db, String clientId) async {
  final List<SyncQueueData> queue = await (db.select(db.syncQueue)
        ..where((SyncQueue q) =>
            q.estadoPeticion.isIn(<String>['pending', 'failed'])))
      .get();
  if (queue.isEmpty) return 0;

  final Set<String> printerIds = (await (db.select(db.printers)
            ..where((Printers p) => p.clientId.equals(clientId)))
          .get())
      .map((Printer p) => p.id)
      .toSet();
  final Set<String> policyIds = (await (db.select(db.policies)
            ..where((Policies p) => p.clientId.equals(clientId)))
          .get())
      .map((Policy p) => p.id)
      .toSet();

  final List<String> entityIds =
      queue.map((SyncQueueData q) => q.entityId).toSet().toList();

  final Set<String> clientReportIds = printerIds.isEmpty
      ? <String>{}
      : (await (db.select(db.reports)
                ..where((Reports r) =>
                    r.id.isIn(entityIds) & r.printerId.isIn(printerIds)))
              .get())
          .map((Report r) => r.id)
          .toSet();
  final Set<String> clientDeliveryIds = policyIds.isEmpty
      ? <String>{}
      : (await (db.select(db.policyDeliveries)
                ..where((PolicyDeliveries d) =>
                    d.id.isIn(entityIds) & d.policyId.isIn(policyIds)))
              .get())
          .map((PolicyDelivery d) => d.id)
          .toSet();

  return queue
      .where((SyncQueueData q) =>
          clientReportIds.contains(q.entityId) ||
          clientDeliveryIds.contains(q.entityId))
      .length;
}

/// Mensaje que se muestra cuando se bloquea la eliminación de un cliente.
String clientDeleteBlockedMessage(int pending) =>
    'No se puede eliminar este cliente: tiene $pending elemento'
    '${pending != 1 ? 's' : ''} pendiente${pending != 1 ? 's' : ''} de '
    'sincronizar. Sincroniza primero y vuelve a intentarlo.';
