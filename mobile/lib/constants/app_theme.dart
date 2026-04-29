import 'package:flutter/material.dart';
import 'app_colors.dart';

// Light theme palette
class _Light {
  static const background = Color(0xFFF5F7FA);
  static const surface = Colors.white;
  static const surfaceElevated = Color(0xFFF0F2F8);
  static const border = Color(0xFFE4E7EF);
  static const textDark = Color(0xFF1A1A2E);
  static const textGray = Color(0xFF6B7280);
  static const textLight = Color(0xFF9CA3AF);
  static const navBackground = Colors.white;
  static const navBorder = Color(0xFFE4E7EF);
}

/// Context extension — dùng thay AppColors.X để hỗ trợ light/dark theme
extension AppThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get bgColor =>
      isDark ? AppColors.background : _Light.background;
  Color get surfaceColor =>
      isDark ? AppColors.surface : _Light.surface;
  Color get surfaceElevatedColor =>
      isDark ? AppColors.surfaceElevated : _Light.surfaceElevated;
  Color get borderColor =>
      isDark ? AppColors.border : _Light.border;
  Color get textPrimary =>
      isDark ? AppColors.textDark : _Light.textDark;
  Color get textSecondary =>
      isDark ? AppColors.textGray : _Light.textGray;
  Color get textTertiary =>
      isDark ? AppColors.textLight : _Light.textLight;
  Color get navBgColor =>
      isDark ? AppColors.navBackground : _Light.navBackground;
  Color get navBorderColor =>
      isDark ? AppColors.navBorder : _Light.navBorder;
}

// ── ThemeData definitions ─────────────────────────────────────────────────────

ThemeData buildDarkTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      surface: AppColors.surface,
      onSurface: AppColors.textDark,
    ),
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Nunito',
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: AppColors.textLight),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    ),
    dividerTheme:
        const DividerThemeData(color: AppColors.border, thickness: 1),
    iconTheme: const IconThemeData(color: AppColors.textGray),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.textDark),
      bodyMedium: TextStyle(color: AppColors.textDark),
      bodySmall: TextStyle(color: AppColors.textGray),
    ),
  );
}

ThemeData buildLightTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      surface: _Light.surface,
      onSurface: _Light.textDark,
    ),
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: _Light.background,
    fontFamily: 'Nunito',
    appBarTheme: const AppBarTheme(
      backgroundColor: _Light.background,
      foregroundColor: _Light.textDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: _Light.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _Light.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _Light.surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: _Light.textLight),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _Light.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _Light.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    ),
    dividerTheme:
        const DividerThemeData(color: _Light.border, thickness: 1),
    iconTheme: const IconThemeData(color: _Light.textGray),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: _Light.textDark),
      bodyMedium: TextStyle(color: _Light.textDark),
      bodySmall: TextStyle(color: _Light.textGray),
    ),
  );
}
