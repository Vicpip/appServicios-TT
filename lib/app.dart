import 'package:flutter/material.dart';
import 'package:industrial_service_reports/core/theme/app_theme.dart';
import 'package:industrial_service_reports/features/dashboard/presentation/main_dashboard_screen.dart';

class ServiceReportsApp extends StatelessWidget {
  const ServiceReportsApp({
    super.key,
    this.home = const MainDashboardScreen(),
  });

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Industrial Service Reports',
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.darkIndustrial,
      home: home,
    );
  }
}
