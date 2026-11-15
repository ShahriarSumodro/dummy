import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../theme/app_motion.dart';
import '../theme/app_haptics.dart';

enum AppButtonVariant { primary, secondary, subtle, tonal, destructive }

enum AppButtonSize { sm, md, lg, medium, large }

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
    this.size = AppButtonSize.md,
    this.icon,
    bool? loading,
    bool isLoading = false,
    bool? fullWidth,
    bool isFullWidth = false,
  })  : isLoading = loading ?? isLoading,
        isFullWidth = fullWidth ?? isFullWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final double height = (size == AppButtonSize.lg || size == AppButtonSize.large)
        ? 52.0
        : (size == AppButtonSize.sm ? 36.0 : 44.0);

    final double fontSize = (size == AppButtonSize.lg || size == AppButtonSize.large)
        ? AppTypography.bodySize
        : (size == AppButtonSize.sm ? AppTypography.captionSize + 1 : AppTypography.secondarySize);

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
      case AppButtonVariant.tonal:
        bg = isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle;
        fg = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
        break;
      case AppButtonVariant.destructive:
        bg = isDark
            ? AppColors.semanticRedDarkSubtle
            : AppColors.semanticRedLight;
        fg = isDark ? AppColors.semanticRedDark : AppColors.semanticRed;
        break;
    }

    final effectiveOnPressed = onPressed != null
        ? () {
            if (variant == AppButtonVariant.destructive) {
              AppHaptics.warning();
            } else {
              AppHaptics.lightImpact();
            }
            onPressed!();
          }
        : null;

    Widget content = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: fg,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ] else if (icon != null) ...[
          Icon(icon, size: size == AppButtonSize.sm ? 16 : 18, color: fg),
          const SizedBox(width: AppSpacing.xs),
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
    );

    return PressableScale(
      onTap: effectiveOnPressed,
      child: AnimatedContainer(
        duration: AppMotion.snappy,
        curve: AppMotion.easeOut,
        height: height,
        padding: EdgeInsets.symmetric(
          horizontal: size == AppButtonSize.sm ? AppSpacing.sm : AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: onPressed == null ? bg.withValues(alpha: 0.5) : bg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: border,
        ),
        alignment: Alignment.center,
        child: content,
      ),
    );
  }
}
