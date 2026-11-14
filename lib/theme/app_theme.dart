import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// Complete AppTheme using strict design tokens.
class AppTheme {
  AppTheme._();

  // ─────────────────────────────────────────────
  // LIGHT THEME
  // ─────────────────────────────────────────────
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBackground,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.lightAccent,
      onPrimary: Colors.white,
      primaryContainer: AppColors.lightAccentSubtle,
      onPrimaryContainer: AppColors.lightAccent,
      secondary: AppColors.lightTextSecondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.lightSurfaceSubtle,
      onSecondaryContainer: AppColors.lightTextPrimary,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      surfaceContainerHighest: AppColors.lightSurfaceSubtle,
      outline: AppColors.lightHairline,
      outlineVariant: AppColors.lightHairline,
      error: AppColors.semanticRed,
      onError: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightBackground,
      foregroundColor: AppColors.lightTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.lightTextPrimary,
        fontSize: AppTypography.subtitleSize,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      iconTheme: IconThemeData(
        color: AppColors.lightTextPrimary,
        size: 22,
      ),
    ),
    cardTheme: CardTheme(
      color: AppColors.lightSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardRadius,
        side: const BorderSide(color: AppColors.lightHairline, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: AppRadius.inputRadius,
        borderSide: const BorderSide(color: AppColors.lightHairline, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputRadius,
        borderSide: const BorderSide(color: AppColors.lightHairline, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputRadius,
        borderSide: const BorderSide(color: AppColors.lightAccent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputRadius,
        borderSide: const BorderSide(color: AppColors.semanticRed, width: 1),
      ),
      hintStyle: const TextStyle(
        color: AppColors.lightTextTertiary,
        fontSize: AppTypography.bodySize,
        fontWeight: FontWeight.w400,
      ),
      labelStyle: const TextStyle(
        color: AppColors.lightTextSecondary,
        fontSize: AppTypography.secondarySize,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.lightHairline,
      thickness: 1,
      space: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.lightSurface,
      elevation: 0,
      indicatorColor: AppColors.lightAccentSubtle,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontSize: AppTypography.captionSize,
            fontWeight: FontWeight.w600,
            color: AppColors.lightAccent,
          );
        }
        return const TextStyle(
          fontSize: AppTypography.captionSize,
          fontWeight: FontWeight.w500,
          color: AppColors.lightTextTertiary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.lightAccent, size: 22);
        }
        return const IconThemeData(color: AppColors.lightTextSecondary, size: 22);
      }),
    ),
  );

  // ─────────────────────────────────────────────
  // DARK THEME
  // ─────────────────────────────────────────────
  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.darkAccent,
      onPrimary: Colors.white,
      primaryContainer: AppColors.darkAccentSubtle,
      onPrimaryContainer: AppColors.darkAccent,
      secondary: AppColors.darkTextSecondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.darkSurfaceSubtle,
      onSecondaryContainer: AppColors.darkTextPrimary,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      surfaceContainerHighest: AppColors.darkSurfaceSubtle,
      outline: AppColors.darkHairline,
      outlineVariant: AppColors.darkHairline,
      error: AppColors.semanticRedDark,
      onError: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkBackground,
      foregroundColor: AppColors.darkTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.darkTextPrimary,
        fontSize: AppTypography.subtitleSize,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      iconTheme: IconThemeData(
        color: AppColors.darkTextPrimary,
        size: 22,
      ),
    ),
    cardTheme: CardTheme(
      color: AppColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardRadius,
        side: const BorderSide(color: AppColors.darkHairline, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: AppRadius.inputRadius,
        borderSide: const BorderSide(color: AppColors.darkHairline, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputRadius,
        borderSide: const BorderSide(color: AppColors.darkHairline, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputRadius,
        borderSide: const BorderSide(color: AppColors.darkAccent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputRadius,
        borderSide: const BorderSide(color: AppColors.semanticRedDark, width: 1),
      ),
      hintStyle: const TextStyle(
        color: AppColors.darkTextTertiary,
        fontSize: AppTypography.bodySize,
        fontWeight: FontWeight.w400,
      ),
      labelStyle: const TextStyle(
        color: AppColors.darkTextSecondary,
        fontSize: AppTypography.secondarySize,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.darkHairline,
      thickness: 1,
      space: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      elevation: 0,
      indicatorColor: AppColors.darkAccentSubtle,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontSize: AppTypography.captionSize,
            fontWeight: FontWeight.w600,
            color: AppColors.darkAccent,
          );
        }
        return const TextStyle(
          fontSize: AppTypography.captionSize,
          fontWeight: FontWeight.w500,
          color: AppColors.darkTextTertiary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.darkAccent, size: 22);
        }
        return const IconThemeData(color: AppColors.darkTextSecondary, size: 22);
      }),
    ),
  );
}
