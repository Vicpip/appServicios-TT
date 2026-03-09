import 'package:flutter/foundation.dart';

@immutable
class PrinterSummary {
  const PrinterSummary({
    required this.serialNumber,
    required this.modelWithDpi,
    required this.clientName,
    required this.plantName,
    required this.areaName,
    required this.hasActivePolicy,
  });

  final String serialNumber;
  final String modelWithDpi;
  final String clientName;
  final String plantName;
  final String areaName;
  final bool hasActivePolicy;
}
