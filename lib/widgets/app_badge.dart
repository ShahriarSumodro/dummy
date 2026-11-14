import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

enum AppBadgeVariant {
  confirmed, // Green
  needsReview, // Amber / AI guess awaiting confirmation
  overdue, // Red
  done, // Neutral gray
  neutral, // Subtle background
  accent, // Brand ink blue
}

/// Semantic status badge paired with an icon or explicit label (never color alone).
class AppBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final AppBadgeVariant variant;
  final bool isSmall;

  const AppBadge({
    super.key,
    required this.label,
    this.icon,
    this.variant = AppBadgeVariant.neutral,
    this.isSmall = false,
  });

  factory AppBadge.confirmed({String label = 'Confirmed', bool isSmall = false}) =>
      AppBadge(
        label: label,
        icon: Icons.check_circle_outline,
        variant: AppBadgeVariant.confirmed,
        isSmall: isSmall,
      );

  factory AppBadge.needsReview({
    String label = 'Needs Review',
    bool isSmall = false,
  }) =>
      AppBadge(
        label: label,
        icon: Icons.help_outline,
        variant: AppBadgeVariant.needsReview,
        isSmall: isSmall,
      );

  factory AppBadge.overdue({String label = 'Overdue', bool isSmall = false}) =>
      AppBadge(
        label: label,
        icon: Icons.error_outline,
        variant: AppBadgeVariant.overdue,
        isSmall: isSmall,
      );

  factory AppBadge.done({String label = 'Done', bool isSmall = false}) => AppBadge(
        label: label,
        icon: Icons.done_all,
        variant: AppBadgeVariant.done,
        isSmall: isSmall,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bg;
    Color fg;
    Color border;

    switch (variant) {
      case AppBadgeVariant.confirmed:
        bg = isDark
            ? AppColors.semanticGreenDarkSubtle
            : AppColors.semanticGreenLight;
        fg = isDark ? AppColors.semanticGreenDark : AppColors.semanticGreen;
        border = fg.withValues(alpha: 0.25);
        break;
      case AppBadgeVariant.needsReview:
        bg = isDark
            ? AppColors.semanticAmberDarkSubtle
            : AppColors.semanticAmberLight;
        fg = isDark ? AppColors.semanticAmberDark : AppColors.semanticAmber;
        border = fg.withValues(alpha: 0.25);
        break;
      case AppBadgeVariant.overdue:
        bg = isDark
            ? AppColors.semanticRedDarkSubtle
            : AppColors.semanticRedLight;
        fg = isDark ? AppColors.semanticRedDark : AppColors.semanticRed;
        border = fg.withValues(alpha: 0.25);
        break;
      case AppBadgeVariant.done:
        bg = isDark
            ? AppColors.semanticNeutralDarkSubtle
            : AppColors.semanticNeutralLight;
        fg = isDark ? AppColors.semanticNeutralDark : AppColors.semanticNeutral;
        border = fg.withValues(alpha: 0.25);
        break;
      case AppBadgeVariant.accent:
        bg = isDark ? AppColors.darkAccentSubtle : AppColors.lightAccentSubtle;
        fg = isDark ? AppColors.darkAccent : AppColors.lightAccent;
        border = fg.withValues(alpha: 0.25);
        break;
      case AppBadgeVariant.neutral:
        bg = isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle;
        fg = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
        border = isDark ? AppColors.darkHairline : AppColors.lightHairline;
        break;
    }

    final double fontSize = isSmall ? 11.0 : AppTypography.captionSize;
    final double iconSize = isSmall ? 12.0 : 13.0;
    final double vPadding = isSmall ? 2.5 : 4.5;
    final double hPadding = isSmall ? 6.5 : 9.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.pillRadius,
        border: Border.all(color: border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
