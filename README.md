# Industrial Service Reports (Tablet App)

Base Flutter del proyecto offline-first para captura de reportes tecnicos industriales.

## Estado actual

- Tema dark industrial configurado.
- Estructura de base de datos local con Drift/SQLite creada segun el dominio funcional.
- Sin pantallas de negocio (solo shell de app).

## Archivos clave

- `lib/main.dart`
- `lib/app.dart`
- `lib/core/theme/app_theme.dart`
- `lib/data/local/app_database.dart`
- `lib/data/local/local_database.dart`

## Cuando tengas Flutter SDK en PATH

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```
