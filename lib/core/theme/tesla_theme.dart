import 'package:flutter/material.dart';

/// 테슬라 순정 UI 감성의 미니멀 다크 테마 (Material 3 기반)
class TeslaColors {
  TeslaColors._();

  static const Color background = Color(0xFF0A0C0E);
  static const Color surface = Color(0xFF14171C);
  static const Color surfaceElevated = Color(0xFF1E222A);
  static const Color border = Color(0xFF282D37);

  static const Color teslaRed = Color(0xFFE82127);
  static const Color electricBlue = Color(0xFF3E6AE1);
  static const Color batteryGreen = Color(0xFF22C55E);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color purpleAccent = Color(0xFF8B5CF6);

  static const Color textPrimary = Color(0xFFF3F4F6);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);
}

class TeslaTheme {
  TeslaTheme._();

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: TeslaColors.teslaRed,
      secondary: TeslaColors.electricBlue,
      tertiary: TeslaColors.batteryGreen,
      surface: TeslaColors.surface,
      error: Color(0xFFEF4444),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: TeslaColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: TeslaColors.background,
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: TeslaColors.background,
        foregroundColor: TeslaColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: TeslaColors.textPrimary,
        ),
      ),
      cardTheme: CardTheme(
        color: TeslaColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: TeslaColors.border, width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: TeslaColors.surface,
        indicatorColor: TeslaColors.teslaRed.withOpacity(0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? TeslaColors.textPrimary
                : TeslaColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected
                ? TeslaColors.teslaRed
                : TeslaColors.textSecondary,
            size: 24,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: TeslaColors.surface,
        indicatorColor: TeslaColors.teslaRed.withOpacity(0.18),
        selectedIconTheme: const IconThemeData(color: TeslaColors.teslaRed),
        unselectedIconTheme:
            const IconThemeData(color: TeslaColors.textSecondary),
        selectedLabelTextStyle: const TextStyle(
          color: TeslaColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: TeslaColors.textSecondary,
          fontSize: 12,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TeslaColors.surfaceElevated,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TeslaColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TeslaColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TeslaColors.electricBlue, width: 1.5),
        ),
        labelStyle: const TextStyle(color: TeslaColors.textSecondary),
        hintStyle: const TextStyle(color: TeslaColors.textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: TeslaColors.teslaRed,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: TeslaColors.teslaRed,
        foregroundColor: Colors.white,
      ),
      dividerTheme: const DividerThemeData(
        color: TeslaColors.border,
        thickness: 1,
      ),
    );
  }
}
