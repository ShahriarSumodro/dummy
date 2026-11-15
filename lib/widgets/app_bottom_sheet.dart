import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../theme/app_haptics.dart';

/// Modal bottom sheet system with 24pt radius, grabber handle, and safe-area insets.
class AppBottomSheet extends StatelessWidget {
  final Widget child;
  final String? title;
  final Widget? trailing;

  const AppBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.trailing,
  });

  /// Opens an AppBottomSheet with standardized styling and haptics
  static Future<T?> show<T>({
    required BuildContext context,
    Widget Function(BuildContext)? builder,
    Widget? child,
    String? title,
    Widget? trailing,
    bool isScrollControlled = true,
  }) {
    AppHaptics.lightImpact();
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) => AppBottomSheet(
        title: title,
        trailing: trailing,
        child: builder != null ? builder(ctx) : (child ?? const SizedBox.shrink()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final grabber = isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final titleColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
        boxShadow: AppShadows.floating(isDark),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Grabber Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: grabber,
                borderRadius: AppRadius.pillRadius,
              ),
            ),
          ),
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenSide,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title!,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: AppTypography.subtitleSize,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
            Divider(
              color: isDark ? AppColors.darkHairline : AppColors.lightHairline,
              height: 1,
            ),
          ],
          Flexible(child: child),
        ],
      ),
    );
  }
}
