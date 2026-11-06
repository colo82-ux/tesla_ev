import 'package:flutter/material.dart';

/// Antigravity 다크 테마 + Dracula 컬러 팔레트 감성의 테마 (Material 3 기반)
class TeslaColors {
  TeslaColors._();

  // Antigravity Deep Dark & Dracula Background / Surface 계층
  static const Color background = Color(0xFF191A22); // Antigravity Deep Abyss
  static const Color surface = Color(0xFF282A36); // Dracula Background
  static const Color surfaceElevated = Color(0xFF343746); // Dracula Current Line
  static const Color border = Color(0xFF44475A); // Dracula Selection / Border

  // Dracula 시그니처 네온 액센트 컬러
  static const Color teslaRed = Color(0xFFFF79C6); // Dracula Pink (메인 포인트/차트)
  static const Color purpleAccent = Color(0xFFBD93F9); // Dracula Purple (프라이머리 액센트)
  static const Color electricBlue = Color(0xFF8BE9FD); // Dracula Cyan (보조/전비/온도 포인트)
  static const Color batteryGreen = Color(0xFF50FA7B); // Dracula Green (배터리/충전/양호)
  static const Color warningAmber = Color(0xFFFFB86C); // Dracula Orange (지출/경고/유지비)
  static const Color dangerRed = Color(0xFFFF5555); // Dracula Red (위험/삭제/초과)

  // Dracula 타이포그래피 컬러
  static const Color textPrimary = Color(0xFFF8F8F2); // Dracula Foreground
  static const Color textSecondary = Color(0xFFBDBFC7); // Soft Lavender-Gray
  static const Color textMuted = Color(0xFF6272A4); // Dracula Comment (Slate Purple)
}

class TeslaTheme {
  TeslaTheme._();

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: TeslaColors.purpleAccent,
      secondary: TeslaColors.teslaRed,
      tertiary: TeslaColors.electricBlue,
      surface: TeslaColors.surface,
      error: TeslaColors.dangerRed,
      onPrimary: Color(0xFF191A22),
      onSecondary: Color(0xFF191A22),
      onTertiary: Color(0xFF191A22),
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
      dialogTheme: DialogTheme(
        backgroundColor: TeslaColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: TeslaColors.border, width: 1),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: TeslaColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: TeslaColors.border, width: 1),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: TeslaColors.surface,
        headerBackgroundColor: TeslaColors.surfaceElevated,
        headerForegroundColor: TeslaColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        dividerColor: TeslaColors.border,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: TeslaColors.border, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: TeslaColors.surfaceElevated,
        selectedColor: TeslaColors.purpleAccent.withOpacity(0.25),
        side: const BorderSide(color: TeslaColors.border),
        labelStyle: const TextStyle(
          color: TeslaColors.textPrimary,
          fontSize: 12,
        ),
        secondaryLabelStyle: const TextStyle(
          color: TeslaColors.purpleAccent,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        checkmarkColor: TeslaColors.purpleAccent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return TeslaColors.purpleAccent.withOpacity(0.25);
            }
            return TeslaColors.surfaceElevated;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return TeslaColors.textPrimary;
            }
            return TeslaColors.textSecondary;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const BorderSide(
                color: TeslaColors.purpleAccent,
                width: 1.2,
              );
            }
            return const BorderSide(color: TeslaColors.border);
          }),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: TeslaColors.surface,
        indicatorColor: TeslaColors.purpleAccent.withOpacity(0.22),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            color: isSelected
                ? TeslaColors.purpleAccent
                : TeslaColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected
                ? TeslaColors.purpleAccent
                : TeslaColors.textSecondary,
            size: 24,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: TeslaColors.surface,
        indicatorColor: TeslaColors.purpleAccent.withOpacity(0.22),
        selectedIconTheme:
            const IconThemeData(color: TeslaColors.purpleAccent),
        unselectedIconTheme:
            const IconThemeData(color: TeslaColors.textSecondary),
        selectedLabelTextStyle: const TextStyle(
          color: TeslaColors.purpleAccent,
          fontWeight: FontWeight.w700,
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
          borderSide: const BorderSide(
            color: TeslaColors.purpleAccent,
            width: 1.5,
          ),
        ),
        labelStyle: const TextStyle(color: TeslaColors.textSecondary),
        hintStyle: const TextStyle(color: TeslaColors.textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: TeslaColors.purpleAccent,
          foregroundColor: const Color(0xFF191A22),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TeslaColors.electricBlue,
          side: const BorderSide(color: TeslaColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: TeslaColors.purpleAccent,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: TeslaColors.teslaRed,
        foregroundColor: Color(0xFF191A22),
        elevation: 4,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: TeslaColors.surfaceElevated,
        contentTextStyle: const TextStyle(
          color: TeslaColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: TeslaColors.purpleAccent, width: 1),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: TeslaColors.border,
        thickness: 1,
      ),
    );
  }
}
