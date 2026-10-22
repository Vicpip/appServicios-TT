import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:industrial_service_reports/app.dart';

void main() {
  testWidgets('App builds with industrial dark theme shell', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // La app usa Riverpod: sin ProviderScope falla al construirse.
    await tester.pumpWidget(const ProviderScope(child: ServiceReportsApp()));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
