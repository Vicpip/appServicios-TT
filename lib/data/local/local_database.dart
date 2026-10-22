import 'package:industrial_service_reports/data/local/app_database.dart';

/// Base de datos local compartida por toda la app. No es `final` solo para que
/// las pruebas de widgets puedan sustituirla por una base en memoria.
AppDatabase localDatabase = AppDatabase();
