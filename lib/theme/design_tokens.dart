import 'package:flutter/material.dart';

/// Centralized Design Tokens for RemembrAI.
/// Strict adherence to premium mobile UI specifications:
/// Calm, confident, quiet, 60-30-10 color balance, 8pt spacing grid.
class AppColors {
  AppColors._();

  // ─────────────────────────────────────────────
  // LIGHT MODE PALETTE (Warm Off-White & Crisp Slate)
  // ─────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFFAFAF9); // Warm off-white
  static const Color lightSurface = Color(0xFFFFFFFF); // Card & surface pure white
  static const Color lightSurfaceSubtle = Color(0xFFF3F3F1); // Subtle container fill
  static const Color lightHairline = Color(0xFFECECE8); // Hairline border
  static const Color lightTextPrimary = Color(0xFF111111);
  static const Color lightTextSecondary = Color(0xFF6B6B66);
  static const Color lightTextTertiary = Color(0xFF9A9A94);

  // Accent: Deep calm ink blue (used sparingly for primary actions/active tabs)
  static const Color lightAccent = Color(0xFF3B4CCA);
  static const Color lightAccentHover = Color(0xFF2E3CA3);
  static const Color lightAccentSubtle = Color(0xFFEEF0FA);

  // ─────────────────────────────────────────────
  // DARK MODE PALETTE (Deep Charcoal, Not Pure Inversion)
  // ─────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF0E0E0F);
  static const Color darkSurface = Color(0xFF17171A);
  static const Color darkSurfaceSubtle = Color(0xFF1F1F23);
  static const Color darkHairline = Color(0xFF26262B);
  static const Color darkTextPrimary = Color(0xFFF2F2F0);
  static const Color darkTextSecondary = Color(0xFFA0A09A);
  static const Color darkTextTertiary = Color(0xFF666660);

  // Accent in dark mode (slightly lighter for contrast & legibility)
  static const Color darkAccent = Color(0xFF4F62E2);
  static const Color darkAccentHover = Color(0xFF6A7AF0);
  static const Color darkAccentSubtle = Color(0xFF1A1C30);

  // ─────────────────────────────────────────────
  // SEMANTIC STATUS COLORS (Muted tones, paired with icons/labels)
  // ─────────────────────────────────────────────
  // Confirmed / Complete / Healthy
  static const Color semanticGreen = Color(0xFF2E7D32);
  static const Color semanticGreenLight = Color(0xFFE8F5E9);
  static const Color semanticGreenDark = Color(0xFF4CAF50);
  static const Color semanticGreenDarkSubtle = Color(0xFF152818);

  // Needs Review / Uncertain AI guess
  static const Color semanticAmber = Color(0xFFD97706);
  static const Color semanticAmberLight = Color(0xFFFEF3C7);
  static const Color semanticAmberDark = Color(0xFFF59E0B);
  static const Color semanticAmberDarkSubtle = Color(0xFF2B1F08);

  // Overdue / Urgent / Destructive
  static const Color semanticRed = Color(0xFFDC2626);
  static const Color semanticRedLight = Color(0xFFFEE2E2);
  static const Color semanticRedDark = Color(0xFFEF4444);
  static const Color semanticRedDarkSubtle = Color(0xFF2E1214);

  // Neutral / Done
  static const Color semanticNeutral = Color(0xFF78716C);
  static const Color semanticNeutralLight = Color(0xFFF5F5F4);
  static const Color semanticNeutralDark = Color(0xFFA8A29E);
  static const Color semanticNeutralDarkSubtle = Color(0xFF21201E);

  // Shorthand Semantic Aliases
  static const Color primary = lightAccent;
  static const Color success = semanticGreen;
  static const Color warning = semanticAmber;
  static const Color error = semanticRed;

  // Context-aware dynamic colors
  static Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBackground : lightBackground;

  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSurface : lightSurface;

  static Color subtle(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSurfaceSubtle : lightSurfaceSubtle;

  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkHairline : lightHairline;

  static Color foreground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextPrimary : lightTextPrimary;

  static Color muted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextSecondary : lightTextSecondary;
}

/// Strict 8pt Typography & Spacing Scales
class AppTypography {
  AppTypography._();

  static const double captionSize = 12.0;
  static const double secondarySize = 15.0;
  static const double bodySize = 17.0;
  static const double subtitleSize = 20.0;
  static const double titleSize = 24.0;
  static const double largeTitleSize = 32.0;

  static const double standardHeight = 1.4;
  static const double bengaliHeight = 1.55;

  static TextStyle get caption => const TextStyle(
        fontSize: captionSize,
        fontWeight: FontWeight.w400,
        height: standardHeight,
        letterSpacing: 0.1,
      );

  static TextStyle get secondary => const TextStyle(
        fontSize: secondarySize,
        fontWeight: FontWeight.w400,
        height: standardHeight,
      );

  static TextStyle get body => const TextStyle(
        fontSize: bodySize,
        fontWeight: FontWeight.w400,
        height: standardHeight,
      );

  static TextStyle get bodyMedium => const TextStyle(
        fontSize: bodySize,
        fontWeight: FontWeight.w500,
        height: standardHeight,
      );

  static TextStyle get subtitle => const TextStyle(
        fontSize: subtitleSize,
        fontWeight: FontWeight.w600,
        height: 1.35,
        letterSpacing: -0.2,
      );

  static TextStyle get title => const TextStyle(
        fontSize: titleSize,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.3,
      );

  static TextStyle get largeTitle => const TextStyle(
        fontSize: largeTitleSize,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.5,
      );
}

/// Spacing on 8pt grid + minimum tap targets
class AppSpacing {
  AppSpacing._();

  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double screenSide = 20.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  static const double minTapTarget = 44.0;
}

/// Border Radii Scale
class AppRadius {
  AppRadius._();

  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double full = 999.0;

  static const double input = 8.0;
  static const double card = 16.0;
  static const double sheet = 24.0;
  static const double pill = 999.0;

  static final BorderRadius inputRadius = BorderRadius.circular(input);
  static final BorderRadius cardRadius = BorderRadius.circular(card);
  static final BorderRadius sheetRadius = BorderRadius.circular(sheet);
  static final BorderRadius pillRadius = BorderRadius.circular(pill);
}

/// Soft large-blur shadows used only for floating elements
class AppShadows {
  AppShadows._();

  static List<BoxShadow> floating(bool isDark) => [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.45)
              : const Color(0xFF111111).withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
          spreadRadius: -4,
        ),
      ];

  static List<BoxShadow> subtle(bool isDark) => [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.3)
              : const Color(0xFF111111).withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
          spreadRadius: -2,
        ),
      ];
}
