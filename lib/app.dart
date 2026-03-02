import 'package:flutter/material.dart';
import 'package:industrial_service_reports/core/theme/app_theme.dart';
import 'package:industrial_service_reports/features/auth/presentation/login_screen.dart';
import 'package:industrial_service_reports/features/dashboard/presentation/main_dashboard_screen.dart';
import 'package:industrial_service_reports/features/profile/presentation/technician_profile_screen.dart';

class ServiceReportsApp extends StatelessWidget {
  const ServiceReportsApp({
    super.key,
    this.home = const LoginScreen(),
  });

  final Widget home;

  static const String loginRoute = '/login';
  static const String dashboardRoute = '/dashboard';
  static const String profileRoute = '/profile';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Industrial Service Reports',
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.darkIndustrial,
      home: home,
      routes: <String, WidgetBuilder>{
        loginRoute: (_) => const LoginScreen(),
        dashboardRoute: (_) => const MainDashboardScreen(),
        profileRoute: (_) => const TechnicianProfileScreen(),
      },
    );
  }
}
