/// Formatea el nivel de darkness: "18" si es entero, "18.5" si tiene decimales.
String formatDarkness(num? value) {
  if (value == null) return '';
  final double d = value.toDouble();
  return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
}

/// Parsea texto del campo darkness (acepta coma o punto). Null si está vacío o es inválido.
double? parseDarkness(String text) {
  final String t = text.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}
