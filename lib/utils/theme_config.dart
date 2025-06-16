import 'package:flutter/material.dart';

enum AppThemeMode {
  light,
  dark,
  system,
}

extension AppThemeModeExtension on AppThemeMode {
  String get displayName {
    switch (this) {
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.system:
        return 'System Default';
    }
  }
}

class ThemeConfig {
  // Base colors
  static const Color primaryColor = Color(0xFF1976D2);
  static const Color secondaryColor = Color(0xFF424242);
  static const Color accentColor = Color(0xFF4CAF50);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color surfaceColor = Colors.white;
  static const Color errorColor = Color(0xFFD32F2F);

  // Text colors
  static const Color textPrimaryLight = Color(0xFF212121);
  static const Color textSecondaryLight = Color(0xFF757575);
  static const Color textPrimaryDark = Colors.white;
  static const Color textSecondaryDark = Color(0xFFBDBDBD);

  // High contrast colors
  static const Color highContrastPrimary = Color(0xFF000000);
  static const Color highContrastSecondary = Color(0xFFFFFFFF);
  static const Color highContrastAccent = Color(0xFF0066CC);
  static const Color highContrastBackground = Color(0xFFFFFFFF);
  static const Color highContrastSurface = Color(0xFFFFFFFF);
  static const Color highContrastError = Color(0xFFCC0000);

  // Spacing
  static const double smallPadding = 8.0;
  static const double standardPadding = 16.0;
  static const double largePadding = 24.0;

  // Base text sizes
  static const double smallText = 12.0;
  static const double mediumText = 16.0;
  static const double largeText = 20.0;
  static const double extraLargeText = 24.0;

  // Font size multipliers
  static const double normalFontMultiplier = 1.0;
  static const double largeFontMultiplier = 1.4;

  // Get light theme
  static ThemeData getLightTheme({
    bool highContrast = false,
    bool largeFontSize = false,
  }) {
    final fontMultiplier =
        largeFontSize ? largeFontMultiplier : normalFontMultiplier;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primarySwatch: highContrast
          ? _createMaterialColor(highContrastPrimary)
          : _createMaterialColor(primaryColor),
      primaryColor: highContrast ? highContrastPrimary : primaryColor,
      scaffoldBackgroundColor:
          highContrast ? highContrastBackground : backgroundColor,
      colorScheme: ColorScheme.light(
        primary: highContrast ? highContrastPrimary : primaryColor,
        secondary: highContrast ? highContrastAccent : accentColor,
        surface: highContrast ? highContrastSurface : surfaceColor,
        error: highContrast ? highContrastError : errorColor,
      ),
      textTheme: _getTextTheme(
        baseColor: highContrast ? highContrastPrimary : textPrimaryLight,
        fontMultiplier: fontMultiplier,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: highContrast ? highContrastPrimary : primaryColor,
        foregroundColor: highContrast ? highContrastSecondary : Colors.white,
        titleTextStyle: TextStyle(
          fontSize: largeText * fontMultiplier,
          fontWeight: FontWeight.w600,
          color: highContrast ? highContrastSecondary : Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: highContrast ? highContrastPrimary : primaryColor,
          foregroundColor: highContrast ? highContrastSecondary : Colors.white,
          textStyle: TextStyle(
            fontSize: mediumText * fontMultiplier,
            fontWeight: FontWeight.w600,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: standardPadding * 1.5,
            vertical: standardPadding,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: highContrast ? highContrastSurface : surfaceColor,
        elevation: highContrast ? 8 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: highContrast
              ? BorderSide(color: highContrastPrimary, width: 2)
              : BorderSide.none,
        ),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: TextStyle(
          fontSize: mediumText * fontMultiplier,
          fontWeight: FontWeight.w600,
          color: highContrast ? highContrastPrimary : textPrimaryLight,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: smallText * fontMultiplier,
          color: highContrast ? highContrastPrimary : textSecondaryLight,
        ),
      ),
    );
  }

  // Get dark theme
  static ThemeData getDarkTheme({
    bool highContrast = false,
    bool largeFontSize = false,
  }) {
    final fontMultiplier =
        largeFontSize ? largeFontMultiplier : normalFontMultiplier;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primarySwatch: highContrast
          ? _createMaterialColor(highContrastSecondary)
          : _createMaterialColor(primaryColor),
      primaryColor: highContrast ? highContrastSecondary : primaryColor,
      scaffoldBackgroundColor:
          highContrast ? highContrastPrimary : const Color(0xFF121212),
      colorScheme: ColorScheme.dark(
        primary: highContrast ? highContrastSecondary : primaryColor,
        secondary: highContrast ? highContrastAccent : accentColor,
        surface: highContrast ? highContrastPrimary : const Color(0xFF1E1E1E),
        error: highContrast ? highContrastError : errorColor,
      ),
      textTheme: _getTextTheme(
        baseColor: highContrast ? highContrastSecondary : textPrimaryDark,
        fontMultiplier: fontMultiplier,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor:
            highContrast ? highContrastPrimary : const Color(0xFF1E1E1E),
        foregroundColor: highContrast ? highContrastSecondary : textPrimaryDark,
        titleTextStyle: TextStyle(
          fontSize: largeText * fontMultiplier,
          fontWeight: FontWeight.w600,
          color: highContrast ? highContrastSecondary : textPrimaryDark,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: highContrast ? highContrastSecondary : primaryColor,
          foregroundColor: highContrast ? highContrastPrimary : Colors.white,
          textStyle: TextStyle(
            fontSize: mediumText * fontMultiplier,
            fontWeight: FontWeight.w600,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: standardPadding * 1.5,
            vertical: standardPadding,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: highContrast ? highContrastPrimary : const Color(0xFF1E1E1E),
        elevation: highContrast ? 8 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: highContrast
              ? BorderSide(color: highContrastSecondary, width: 2)
              : BorderSide.none,
        ),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: TextStyle(
          fontSize: mediumText * fontMultiplier,
          fontWeight: FontWeight.w600,
          color: highContrast ? highContrastSecondary : textPrimaryDark,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: smallText * fontMultiplier,
          color: highContrast ? highContrastSecondary : textSecondaryDark,
        ),
      ),
    );
  }

  // Create text theme with font multiplier
  static TextTheme _getTextTheme({
    required Color baseColor,
    required double fontMultiplier,
  }) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 32.0 * fontMultiplier,
        fontWeight: FontWeight.w400,
        color: baseColor,
      ),
      displayMedium: TextStyle(
        fontSize: 28.0 * fontMultiplier,
        fontWeight: FontWeight.w400,
        color: baseColor,
      ),
      displaySmall: TextStyle(
        fontSize: 24.0 * fontMultiplier,
        fontWeight: FontWeight.w400,
        color: baseColor,
      ),
      headlineLarge: TextStyle(
        fontSize: 22.0 * fontMultiplier,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      headlineMedium: TextStyle(
        fontSize: 20.0 * fontMultiplier,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      headlineSmall: TextStyle(
        fontSize: 18.0 * fontMultiplier,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleLarge: TextStyle(
        fontSize: 16.0 * fontMultiplier,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleMedium: TextStyle(
        fontSize: 14.0 * fontMultiplier,
        fontWeight: FontWeight.w500,
        color: baseColor,
      ),
      titleSmall: TextStyle(
        fontSize: 12.0 * fontMultiplier,
        fontWeight: FontWeight.w500,
        color: baseColor,
      ),
      bodyLarge: TextStyle(
        fontSize: 16.0 * fontMultiplier,
        fontWeight: FontWeight.w400,
        color: baseColor,
      ),
      bodyMedium: TextStyle(
        fontSize: 14.0 * fontMultiplier,
        fontWeight: FontWeight.w400,
        color: baseColor,
      ),
      bodySmall: TextStyle(
        fontSize: 12.0 * fontMultiplier,
        fontWeight: FontWeight.w400,
        color: baseColor,
      ),
      labelLarge: TextStyle(
        fontSize: 14.0 * fontMultiplier,
        fontWeight: FontWeight.w500,
        color: baseColor,
      ),
      labelMedium: TextStyle(
        fontSize: 12.0 * fontMultiplier,
        fontWeight: FontWeight.w500,
        color: baseColor,
      ),
      labelSmall: TextStyle(
        fontSize: 10.0 * fontMultiplier,
        fontWeight: FontWeight.w500,
        color: baseColor,
      ),
    );
  }

  // Helper method to create MaterialColor
  static MaterialColor _createMaterialColor(Color color) {
    final strengths = <double>[.05];
    final swatch = <int, Color>{};
    final int r = (color.r * 255.0).round() & 0xff;
    final int g = (color.g * 255.0).round() & 0xff;
    final int b = (color.b * 255.0).round() & 0xff;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (double strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.toARGB32(), swatch);
  }

  // Helper method to get appropriate theme based on mode and settings
  static ThemeData getTheme({
    required AppThemeMode themeMode,
    required bool highContrastMode,
    required bool isDarkMode, // System dark mode
    bool largeFontSize = false,
  }) {
    bool useDarkTheme = false;

    switch (themeMode) {
      case AppThemeMode.light:
        useDarkTheme = false;
        break;
      case AppThemeMode.dark:
        useDarkTheme = true;
        break;
      case AppThemeMode.system:
        useDarkTheme = isDarkMode;
        break;
    }

    if (useDarkTheme) {
      return getDarkTheme(
          highContrast: highContrastMode, largeFontSize: largeFontSize);
    } else {
      return getLightTheme(
          highContrast: highContrastMode, largeFontSize: largeFontSize);
    }
  }
}
