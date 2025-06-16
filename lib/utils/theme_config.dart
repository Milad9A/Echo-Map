import 'package:flutter/material.dart';

/// Configuration for app theming with a focus on accessibility
class ThemeConfig {
  // Primary colors - high contrast
  static const Color primaryColor = Color(0xFF0066CC); // Strong blue
  static const Color secondaryColor = Color(0xFFFFA500); // Orange
  static const Color accentColor = Color(0xFF00CC66); // Green
  static const Color errorColor = Color(0xFFCC0000); // Red

  // Additional colors for enhanced interface
  static const Color warningColor = Color(0xFFFF9800); // Amber
  static const Color successColor = Color(0xFF4CAF50); // Material Green
  static const Color infoColor = Color(0xFF2196F3); // Material Blue

  // Background colors
  static const Color backgroundLight = Color(0xFFF5F5F5); // Almost white
  static const Color backgroundDark = Color(0xFF121212); // Almost black
  static const Color cardColorLight = Colors.white;
  static const Color cardColorDark = Color(0xFF1E1E1E);

  // Text colors
  static const Color textPrimaryLight = Color(0xFF000000); // Black
  static const Color textSecondaryLight = Color(0xFF333333); // Dark gray
  static const Color textPrimaryDark = Color(0xFFFFFFFF); // White
  static const Color textSecondaryDark = Color(0xFFCCCCCC); // Light gray

  // Accessibility dimensions
  static const double minimumTouchSize = 48.0; // Minimum touch target size
  static const double standardPadding = 16.0;
  static const double largePadding = 24.0;
  static const double smallPadding = 8.0;
  static const double borderRadius = 12.0;
  static const double largeText = 18.0;
  static const double mediumText = 16.0;
  static const double smallText = 14.0;

  // Get light theme
  static ThemeData getLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        error: errorColor,
        surface: cardColorLight,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: textPrimaryLight,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: backgroundLight,
      cardColor: cardColorLight,
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontSize: 22.0,
          fontWeight: FontWeight.bold,
          color: textPrimaryLight,
        ),
        titleMedium: TextStyle(
          fontSize: 18.0,
          fontWeight: FontWeight.bold,
          color: textPrimaryLight,
        ),
        bodyLarge: TextStyle(fontSize: 16.0, color: textPrimaryLight),
        bodyMedium: TextStyle(fontSize: 14.0, color: textPrimaryLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          minimumSize: const Size(minimumTouchSize * 2, minimumTouchSize),
          textStyle: const TextStyle(
            fontSize: mediumText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: primaryColor,
        thumbColor: primaryColor,
        trackHeight: 6.0, // Thicker track for easier targeting
        thumbShape: RoundSliderThumbShape(
          enabledThumbRadius: 12.0, // Larger thumb for easier targeting
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor.withAlpha((0.5 * 255).round());
          }
          return Colors.grey.withAlpha((0.5 * 255).round());
        }),
      ),
    );
  }

  // Get dark theme
  static ThemeData getDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        error: errorColor,
        surface: cardColorDark,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: textPrimaryDark,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: backgroundDark,
      cardColor: cardColorDark,
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontSize: 22.0,
          fontWeight: FontWeight.bold,
          color: textPrimaryDark,
        ),
        titleMedium: TextStyle(
          fontSize: 18.0,
          fontWeight: FontWeight.bold,
          color: textPrimaryDark,
        ),
        bodyLarge: TextStyle(fontSize: 16.0, color: textPrimaryDark),
        bodyMedium: TextStyle(fontSize: 14.0, color: textPrimaryDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          minimumSize: const Size(minimumTouchSize * 2, minimumTouchSize),
          textStyle: const TextStyle(
            fontSize: mediumText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: cardColorDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: primaryColor,
        thumbColor: primaryColor,
        trackHeight: 6.0,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12.0),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor.withAlpha((0.5 * 255).round());
          }
          return Colors.grey.withAlpha((0.5 * 255).round());
        }),
      ),
    );
  }
}
