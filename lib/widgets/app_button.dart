import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../theme/app_motion.dart';
import '../theme/app_haptics.dart';

enum AppButtonVariant { primary, secondary, subtle, destructive }

enum AppButtonSize { medium, large }

/// Standardized tactile button with press-scale interaction and haptic feedback.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final double height = size == AppButtonSize.large ? 52.0 : 44.0;
    final double fontSize = size == AppButtonSize.large
        ? AppTypography.bodySize
        : AppTypography.secondarySize;

    Color bg;
    Color fg;
    Border? border;

    switch (variant) {
      case AppButtonVariant.primary:
        bg = isDark ? AppColors.darkAccent : AppColors.lightAccent;
        fg = Colors.white;
        break;
      case AppButtonVariant.secondary:
        bg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
        fg = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
        border = Border.all(
          color: isDark ? AppColors.darkHairline : AppColors.lightHairline,
          width: 1,
        );
        break;
      case AppButtonVariant.subtle:
        bg = isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle;
        fg = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
        break;
      case AppButtonVariant.destructive:
        bg = isDark ? AppColors.semanticRedDarkSubtle : AppColors.semanticRedLight;
        fg = isDark ? AppColors.semanticRedDark : AppColors.semanticRed;
        break;
    }

    final bool isDisabled = onPressed == null || isLoading;
    if (isDisabled) {
      bg = bg.withValues(alpha: 0.5);
      fg = fg.withValues(alpha: 0.5);
    }

    Widget content = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ],
    );

    return PressableScale(
      onTap: isDisabled
          ? null
          : () {
              if (variant == AppButtonVariant.destructive) {
                AppHaptics.warning();
              } else {
                AppHaptics.lightImpact();
              }
              onPressed?.call();
            },
      child: Container(
        height: height,
        constraints: BoxConstraints(
          minWidth: isFullWidth ? double.infinity : AppSpacing.minTapTarget,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(height / 2), // Clean pill radius
          border: border,
        ),
        alignment: Alignment.center,
        child: content,
      ),
    );
  }
}
