import 'package:flutter/material.dart';
import 'package:industrial_service_reports/app.dart';
import 'package:industrial_service_reports/features/auth/presentation/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ServiceReportsApp(home: LoginScreen()));
}
