import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remembrai/theme/design_tokens.dart';
import 'package:remembrai/theme/app_theme.dart';
import 'package:remembrai/theme/app_haptics.dart';
import 'package:remembrai/widgets/widgets.dart';

void main() {
  group('Design System Foundation Tests (Stage 1)', () {
    test('AppColors tokens define strict light and dark color palettes', () {
      expect(AppColors.lightBackground, const Color(0xFFFAFAF9));
      expect(AppColors.darkBackground, const Color(0xFF0E0E0F));
      expect(AppColors.lightAccent, const Color(0xFF3B4CCA));
      expect(AppColors.darkAccent, const Color(0xFF4F62E2));
      expect(AppColors.semanticGreen, const Color(0xFF2E7D32));
      expect(AppColors.semanticAmber, const Color(0xFFD97706));
      expect(AppColors.semanticRed, const Color(0xFFDC2626));
    });

    test('AppTypography tokens follow 8pt mobile standard scale', () {
      expect(AppTypography.captionSize, 12.0);
      expect(AppTypography.secondarySize, 15.0);
      expect(AppTypography.bodySize, 17.0);
      expect(AppTypography.subtitleSize, 20.0);
      expect(AppTypography.titleSize, 24.0);
      expect(AppTypography.largeTitleSize, 32.0);
    });

    test('AppSpacing & AppRadius tokens conform to 8pt geometry', () {
      expect(AppSpacing.screenSide, 20.0);
      expect(AppSpacing.minTapTarget, 44.0);
      expect(AppRadius.input, 8.0);
      expect(AppRadius.card, 16.0);
      expect(AppRadius.sheet, 24.0);
    });

    test('AppHaptics toggles cleanly', () {
      expect(AppHaptics.enabled, isTrue);
      AppHaptics.enabled = false;
      expect(AppHaptics.enabled, isFalse);
      AppHaptics.enabled = true;
    });

    testWidgets('AppButton renders properly with primary variant', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AppButton(
              label: 'Confirm Action',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Confirm Action'), findsOneWidget);
      await tester.tap(find.text('Confirm Action'));
      expect(tapped, isTrue);
    });

    testWidgets('AppBadge renders semantic status with icon and label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Column(
              children: [
                AppBadge.confirmed(),
                AppBadge.needsReview(),
                AppBadge.overdue(),
                AppBadge.done(),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Needs Review'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('AppEmptyState renders illustration, title, and action', (tester) async {
      bool actionTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AppEmptyState(
              icon: Icons.inbox_outlined,
              title: 'Empty State Title',
              description: 'Empty state description text',
              actionLabel: 'Create First Item',
              onAction: () => actionTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Empty State Title'), findsOneWidget);
      expect(find.text('Empty state description text'), findsOneWidget);
      expect(find.text('Create First Item'), findsOneWidget);
      await tester.tap(find.text('Create First Item'));
      expect(actionTapped, isTrue);
    });
  });
}
