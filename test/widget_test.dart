import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:industrial_service_reports/app.dart';

void main() {
  testWidgets('App builds with industrial dark theme shell', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ServiceReportsApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
