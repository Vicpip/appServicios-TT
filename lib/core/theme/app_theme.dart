import 'package:flutter/material.dart';
import 'package:industrial_service_reports/core/theme/app_palette.dart';

class AppTheme {
  AppTheme._();

  static final ThemeData darkIndustrial = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppPalette.backgroundDark,
    colorScheme: const ColorScheme.dark(
      primary: AppPalette.primary,
      onPrimary: AppPalette.backgroundLight,
      secondary: AppPalette.primaryHover,
      onSecondary: AppPalette.backgroundLight,
      surface: AppPalette.surfaceDark,
      onSurface: AppPalette.backgroundLight,
      error: Color(0xFFE57373),
      onError: Color(0xFF140C0C),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: AppPalette.backgroundLight),
      titleMedium: TextStyle(
        color: AppPalette.backgroundLight,
        fontWeight: FontWeight.w600,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppPalette.backgroundDark,
      foregroundColor: AppPalette.backgroundLight,
      elevation: 0,
    ),
    cardTheme: const CardThemeData(
      color: AppPalette.surfaceDark,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppPalette.surfaceDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: AppPalette.surfaceDarkHighlight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: AppPalette.primary, width: 1.4),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      side: const BorderSide(color: AppPalette.surfaceDarkHighlight),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppPalette.primary,
        foregroundColor: AppPalette.backgroundLight,
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppPalette.primary,
        foregroundColor: AppPalette.backgroundLight,
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppPalette.backgroundLight,
        side: const BorderSide(color: AppPalette.surfaceDarkHighlight),
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
  );
}
