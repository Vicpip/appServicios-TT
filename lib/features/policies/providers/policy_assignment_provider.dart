import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/data/local/local_database.dart';
import 'package:industrial_service_reports/features/auth/providers/session_provider.dart';

@immutable
class PolicyPrinterAssignmentResult {
  const PolicyPrinterAssignmentResult({
    required this.assignedTechnicianId,
    required this.assignedTechnicianName,
    required this.assignedTechnicianCode,
    required this.isAssignedToCurrentUser,
  });

  final String assignedTechnicianId;
  final String assignedTechnicianName;
  final String? assignedTechnicianCode;
  final bool isAssignedToCurrentUser;
}

/// Queries the local [PolicyPrinterAssignments] table for [printerId].
/// Returns null if no assignment exists.
final printerAssignmentProvider = FutureProvider.family<
    PolicyPrinterAssignmentResult?, String>((ref, printerId) async {
  final AppDatabase db = localDatabase;
  final SessionState session = ref.watch(sessionProvider);
  final String? currentUserId =
      session.userId.isEmpty ? null : session.userId;

  final List<PolicyPrinterAssignment> rows = await (db
          .select(db.policyPrinterAssignments)
        ..where((PolicyPrinterAssignments t) => t.printerId.equals(printerId)))
      .get();

  if (rows.isEmpty) return null;

  // Take the most recently assigned (latest assignedAt)
  rows.sort((a, b) => b.assignedAt.compareTo(a.assignedAt));
  final PolicyPrinterAssignment assignment = rows.first;

  final User? tech = await (db.select(db.users)
        ..where((Users u) => u.id.equals(assignment.technicianId)))
      .getSingleOrNull();

  return PolicyPrinterAssignmentResult(
    assignedTechnicianId: assignment.technicianId,
    assignedTechnicianName: tech?.name ?? assignment.technicianId,
    assignedTechnicianCode: tech?.code,
    isAssignedToCurrentUser: assignment.technicianId == currentUserId,
  );
});
