/// Constantes centralizadas para diseño responsive
/// Evita hardcodear valores en cada pantalla y asegura consistencia visual
abstract final class ResponsiveConstants {
  // ============================================================================
  // Breakpoints
  // ============================================================================

  /// Ancho máximo para dispositivos móviles (menores a este valor)
  static const double mobileMaxWidth = 600;

  /// Ancho máximo para dispositivos tablet (menores a este valor)
  static const double tabletMaxWidth = 900;

  /// Ancho mínimo para dispositivos desktop
  static const double desktopMinWidth = 1200;

  // ============================================================================
  // Padding y Margins
  // ============================================================================

  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingExtraLarge = 32.0;

  static const double marginSmall = 4.0;
  static const double marginMedium = 8.0;
  static const double marginLarge = 16.0;

  // ============================================================================
  // Font Sizes
  // ============================================================================

  static const double fontSmall = 12.0;
  static const double fontBody = 14.0;
  static const double fontSubtitle = 16.0;
  static const double fontTitle = 18.0;
  static const double fontHeading = 21.0;
  static const double fontHeadingLarge = 24.0;

  // ============================================================================
  // Border Radius
  // ============================================================================

  static const double borderRadiusSmall = 4.0;
  static const double borderRadiusMedium = 8.0;
  static const double borderRadiusLarge = 12.0;
  static const double borderRadiusExtraLarge = 16.0;

  // ============================================================================
  // Icon Sizes
  // ============================================================================

  static const double iconSmall = 18.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;
  static const double iconExtraLarge = 48.0;

  // ============================================================================
  // Helper Methods
  // ============================================================================

  /// Verifica si el ancho es para móvil
  static bool isMobile(double width) => width < mobileMaxWidth;

  /// Verifica si el ancho es para tablet
  static bool isTablet(double width) =>
      width >= mobileMaxWidth && width < desktopMinWidth;

  /// Verifica si el ancho es para desktop
  static bool isDesktop(double width) => width >= desktopMinWidth;

  /// Retorna el tipo de dispositivo como string
  static String getDeviceType(double width) {
    if (isMobile(width)) return 'mobile';
    if (isTablet(width)) return 'tablet';
    return 'desktop';
  }

  /// Calcula el padding horizontal adaptativo
  static double getHorizontalPadding(double width) {
    if (isMobile(width)) return paddingMedium;
    if (isTablet(width)) return paddingLarge;
    return paddingExtraLarge;
  }

  /// Calcula el padding vertical adaptativo
  static double getVerticalPadding(double width) {
    if (isMobile(width)) return paddingMedium;
    if (isTablet(width)) return paddingMedium;
    return paddingLarge;
  }

  /// Obtiene el tamaño de fuente adaptativo para títulos
  static double getTitleFontSize(double width) {
    if (isMobile(width)) return fontTitle;
    if (isTablet(width)) return fontHeading;
    return fontHeadingLarge;
  }

  /// Obtiene el tamaño de fuente adaptativo para body
  static double getBodyFontSize(double width) {
    if (isMobile(width)) return fontBody;
    if (isTablet(width)) return fontSubtitle;
    return fontSubtitle;
  }

  /// Número de columnas adaptativas para GridView
  static int getGridColumns(double width) {
    if (isMobile(width)) return 2;
    if (isTablet(width)) return 3;
    return 4;
  }

  /// Ancho máximo para contenedores centrados
  static double getMaxContentWidth(double width) {
    if (isMobile(width)) return double.infinity;
    if (isTablet(width)) return 900;
    return 1200;
  }
}
