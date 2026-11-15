import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../theme/app_motion.dart';

/// Clean list row with hairline divider.
/// Used for lists with many items (e.g. contacts, commitments, reminders)
/// instead of boxed card clutter.
class AppListRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? badge;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showDivider;
  final bool isDestructive;

  const AppListRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.badge,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.showDivider = true,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryText = isDestructive
        ? (isDark ? AppColors.semanticRedDark : AppColors.semanticRed)
        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);

    final secondaryText =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final hairline = isDark ? AppColors.darkHairline : AppColors.lightHairline;

    Widget row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenSide,
        vertical: 14,
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: primaryText,
                          fontSize: AppTypography.bodySize,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      badge!,
                    ],
                  ],
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: AppTypography.secondarySize,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PressableScale(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
            color: Colors.transparent,
            child: row,
          ),
        ),
        if (showDivider)
          Padding(
            padding: EdgeInsets.only(
              left: leading != null
                  ? AppSpacing.screenSide + 40
                  : AppSpacing.screenSide,
            ),
            child: Divider(
              height: 1,
              thickness: 1,
              color: hairline,
            ),
          ),
      ],
    );
  }
}
