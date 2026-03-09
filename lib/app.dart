import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:industrial_service_reports/core/router/app_router.dart';
import 'package:industrial_service_reports/core/theme/app_theme.dart';

class ServiceReportsApp extends ConsumerWidget {
  const ServiceReportsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Industrial Service Reports',
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.darkIndustrial,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
