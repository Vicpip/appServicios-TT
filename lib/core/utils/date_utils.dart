import 'package:timezone/timezone.dart' as tz;

const List<String> _months = <String>[
  'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
  'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
];

/// Converts [utcDate] to America/Mexico_City local time and formats it.
/// If [showTime] is true, appends ", HH:mm" after the date.
/// Returns '—' for null input.
String formatLocalCDMX(DateTime? utcDate, {bool showTime = false}) {
  if (utcDate == null) return '—';
  final tz.Location cdmx = tz.getLocation('America/Mexico_City');
  final tz.TZDateTime local = tz.TZDateTime.from(utcDate, cdmx);
  final String dateStr =
      '${local.day.toString().padLeft(2, '0')} '
      '${_months[local.month - 1]} '
      '${local.year}';
  if (!showTime) return dateStr;
  final String h = local.hour.toString().padLeft(2, '0');
  final String m = local.minute.toString().padLeft(2, '0');
  return '$dateStr, $h:$m';
}
