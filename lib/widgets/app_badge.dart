import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

enum AppBadgeVariant {
  confirmed, // Green
  success, // Alias Green
  needsReview, // Amber / AI guess awaiting confirmation
  warning, // Alias Amber
  overdue, // Red
  error, // Alias Red
  done, // Neutral gray
  neutral, // Subtle background
  accent, // Brand ink blue
  info, // Blue
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

  factory AppBadge.done({String label = 'Done', bool isSmall = false}) =>
      AppBadge(
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
    Border? border;

    switch (variant) {
      case AppBadgeVariant.confirmed:
      case AppBadgeVariant.success:
        bg = isDark
            ? AppColors.semanticGreenDarkSubtle
            : AppColors.semanticGreenLight;
        fg = isDark ? AppColors.semanticGreenDark : AppColors.semanticGreen;
        break;
      case AppBadgeVariant.needsReview:
      case AppBadgeVariant.warning:
        bg = isDark
            ? AppColors.semanticAmberDarkSubtle
            : AppColors.semanticAmberLight;
        fg = isDark ? AppColors.semanticAmberDark : AppColors.semanticAmber;
        break;
      case AppBadgeVariant.overdue:
      case AppBadgeVariant.error:
        bg = isDark
            ? AppColors.semanticRedDarkSubtle
            : AppColors.semanticRedLight;
        fg = isDark ? AppColors.semanticRedDark : AppColors.semanticRed;
        break;
      case AppBadgeVariant.done:
        bg = isDark
            ? AppColors.semanticNeutralDarkSubtle
            : AppColors.semanticNeutralLight;
        fg = isDark ? AppColors.semanticNeutralDark : AppColors.semanticNeutral;
        break;
      case AppBadgeVariant.neutral:
        bg = isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle;
        fg = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
        border = Border.all(
          color: isDark ? AppColors.darkHairline : AppColors.lightHairline,
          width: 0.5,
        );
        break;
      case AppBadgeVariant.accent:
      case AppBadgeVariant.info:
        bg = isDark ? AppColors.darkAccentSubtle : AppColors.lightAccentSubtle;
        fg = isDark ? AppColors.darkAccent : AppColors.lightAccent;
        break;
    }

    final double fontSize = isSmall ? 10.0 : AppTypography.captionSize;
    final double iconSize = isSmall ? 11.0 : 13.0;
    final EdgeInsets padding = isSmall
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 4);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: border,
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
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
