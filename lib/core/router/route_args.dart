import 'package:industrial_service_reports/data/local/app_database.dart';
import 'package:industrial_service_reports/features/printers/models/printer_summary.dart';

class ClientDetailArgs {
  const ClientDetailArgs({required this.client});
  final Client client;
}

class AddClientArgs {
  const AddClientArgs({this.client});
  final Client? client;
}

class PrinterConfirmArgs {
  const PrinterConfirmArgs({required this.printer});
  final PrinterSummary printer;
}

class PrinterDetailArgs {
  const PrinterDetailArgs({
    required this.model,
    required this.client,
    required this.serialNumber,
    required this.printerId,
  });
  final String model;
  final String client;
  final String serialNumber;
  final String printerId;
}

class ServiceHistoryArgs {
  const ServiceHistoryArgs({
    required this.model,
    required this.serialNumber,
    required this.printerId,
  });
  final String model;
  final String serialNumber;
  final String printerId;
}

class CaptureArgs {
  const CaptureArgs({this.printerId});
  final String? printerId;
}

class ReportViewArgs {
  const ReportViewArgs({required this.reportId});
  final String reportId;
}

class QuickAddPrinterArgs {
  const QuickAddPrinterArgs({this.initialClientId});
  final String? initialClientId;
}
