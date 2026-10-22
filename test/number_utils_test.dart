import 'package:flutter_test/flutter_test.dart';
import 'package:industrial_service_reports/core/utils/number_utils.dart';

void main() {
  group('formatDarkness', () {
    test('muestra enteros sin decimales', () {
      expect(formatDarkness(18.0), '18');
      expect(formatDarkness(18), '18');
    });
    test('conserva decimales', () {
      expect(formatDarkness(18.5), '18.5');
    });
    test('null -> vacío', () {
      expect(formatDarkness(null), '');
    });
  });

  group('parseDarkness', () {
    test('acepta punto y coma', () {
      expect(parseDarkness('18.5'), 18.5);
      expect(parseDarkness('18,5'), 18.5);
    });
    test('vacío o inválido -> null', () {
      expect(parseDarkness(''), isNull);
      expect(parseDarkness('abc'), isNull);
    });
  });
}
