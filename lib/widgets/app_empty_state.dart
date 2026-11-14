import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'app_button.dart';

/// Minimalist empty state with clean icon, clear title, friendly microcopy,
/// and optional primary action.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isFullPage;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.isFullPage = true,
  });

  factory AppEmptyState.allCaughtUp({VoidCallback? onAction}) => AppEmptyState(
        icon: Icons.check_circle_outline,
        title: 'All caught up',
        description: 'You have no pending promises or overdue follow-ups right now.',
        actionLabel: onAction != null ? 'Create Commitment' : null,
        onAction: onAction,
      );

  factory AppEmptyState.noResults({
    required String query,
    VoidCallback? onClear,
  }) =>
      AppEmptyState(
        icon: Icons.search_off_outlined,
        title: 'No results found',
        description: 'No matching items found for "$query". Try adjusting your search term.',
        actionLabel: onClear != null ? 'Clear Search' : null,
        onAction: onClear,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryText =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final iconBg =
        isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle;
    final iconFg =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? AppColors.darkHairline : AppColors.lightHairline,
                width: 1,
              ),
            ),
            child: Icon(icon, size: 32, color: iconFg),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            style: TextStyle(
              color: primaryText,
              fontSize: AppTypography.subtitleSize,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            description,
            style: TextStyle(
              color: secondaryText,
              fontSize: AppTypography.secondarySize,
              fontWeight: FontWeight.w400,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: actionLabel!,
              onPressed: onAction,
              variant: AppButtonVariant.secondary,
            ),
          ],
        ],
      ),
    );

    if (isFullPage) {
      return Center(child: SingleChildScrollView(child: content));
    }
    return content;
  }
}
