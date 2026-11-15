import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../theme/app_motion.dart';

/// Clean surface container card with 16pt radius and subtle hairline border.
/// Respects the zero-nested padding rule (no card-in-card).
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool isSubtle;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.isSubtle = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = backgroundColor ??
        (isSubtle
            ? (isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle)
            : (isDark ? AppColors.darkSurface : AppColors.lightSurface));

    final border = borderColor ??
        (isDark ? AppColors.darkHairline : AppColors.lightHairline);

    final cardWidget = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: border, width: 1),
      ),
      child: child,
    );

    if (onTap != null || onLongPress != null) {
      return PressableScale(
        onTap: onTap,
        onLongPress: onLongPress,
        child: cardWidget,
      );
    }

    return cardWidget;
  }
}
