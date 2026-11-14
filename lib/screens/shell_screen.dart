import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../theme/app_haptics.dart';
import '../theme/app_motion.dart';
import '../widgets/widgets.dart';
import 'home_screen.dart';
import 'commitments_screen.dart';
import 'people_screen.dart';
import 'memory_hub_screen.dart';
import 'voice_capture_screen.dart';
import 'ai_capture_sheet.dart';
import 'meeting_form_screen.dart';

/// The redesign App Shell featuring a floating 4+1 navigation system,
/// centered tactile Capture FAB, smooth tab transitions, and contextual sheet routing.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    CommitmentsScreen(),
    PeopleScreen(),
    MemoryHubScreen(),
  ];

  void _onTabSelected(int index) {
    if (_currentIndex == index) return;
    AppHaptics.lightImpact();
    setState(() => _currentIndex = index);
  }

  void _showCaptureSheet() {
    AppHaptics.mediumImpact();
    AppBottomSheet.show(
      context: context,
      title: 'Capture Business Memory',
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenSide,
            AppSpacing.sm,
            AppSpacing.screenSide,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Live Voice Recording
              AppCard(
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VoiceCaptureScreen(),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (isDark
                                ? AppColors.darkAccent
                                : AppColors.lightAccent)
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.mic_none_rounded,
                        size: 22,
                        color: isDark
                            ? AppColors.darkAccent
                            : AppColors.lightAccent,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Voice Transcribe & Decode',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                              fontSize: AppTypography.bodySize,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Speak naturally. AI will detect promises, dates, and people.',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                              fontSize: AppTypography.captionSize,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // 2. Type Text Note
              AppCard(
                onTap: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const AiCaptureSheet(),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (isDark
                                ? AppColors.semanticGreenDark
                                : AppColors.semanticGreen)
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.edit_note_rounded,
                        size: 22,
                        color: isDark
                            ? AppColors.semanticGreenDark
                            : AppColors.semanticGreen,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick Text Note',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                              fontSize: AppTypography.bodySize,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Type or paste a follow-up, meeting notes, or commitment.',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                              fontSize: AppTypography.captionSize,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // 3. Log Meeting Intelligence
              AppCard(
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MeetingFormScreen(),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (isDark
                                ? AppColors.semanticAmberDark
                                : AppColors.semanticAmber)
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.meeting_room_outlined,
                        size: 22,
                        color: isDark
                            ? AppColors.semanticAmberDark
                            : AppColors.semanticAmber,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Log Business Meeting',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                              fontSize: AppTypography.bodySize,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Record attendees, extract decisions & action items.',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                              fontSize: AppTypography.captionSize,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final bg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final accent = isDark ? AppColors.darkAccent : AppColors.lightAccent;

    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: AppMotion.normal,
        switchInCurve: AppMotion.easeOut,
        switchOutCurve: AppMotion.easeOut,
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: _screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            bottomInset > 0 ? 4 : AppSpacing.xs,
          ),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(32), // Pure floating pill
              border: Border.all(color: border, width: 1),
              boxShadow: AppShadows.floating(isDark),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 1. Home Tab
                _BarItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  isSelected: _currentIndex == 0,
                  onTap: () => _onTabSelected(0),
                ),

                // 2. Commitments Tab
                _BarItem(
                  icon: Icons.handshake_outlined,
                  activeIcon: Icons.handshake_rounded,
                  label: 'Promises',
                  isSelected: _currentIndex == 1,
                  onTap: () => _onTabSelected(1),
                ),

                // Center Action: Elevated Capture FAB
                PressableScale(
                  onTap: _showCaptureSheet,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),

                // 3. People Tab
                _BarItem(
                  icon: Icons.people_outline_rounded,
                  activeIcon: Icons.people_rounded,
                  label: 'People',
                  isSelected: _currentIndex == 2,
                  onTap: () => _onTabSelected(2),
                ),

                // 4. Memory Hub Tab
                _BarItem(
                  icon: Icons.layers_outlined,
                  activeIcon: Icons.layers_rounded,
                  label: 'Memory',
                  isSelected: _currentIndex == 3,
                  onTap: () => _onTabSelected(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _BarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activeColor = isDark ? AppColors.darkAccent : AppColors.lightAccent;
    final inactiveColor =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    return PressableScale(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 54, minHeight: 48),
        alignment: Alignment.center,
        child: AnimatedScale(
          scale: isSelected ? 1.05 : 1.0,
          duration: AppMotion.micro,
          curve: AppMotion.easeOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                size: 22,
                color: isSelected ? activeColor : inactiveColor,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
