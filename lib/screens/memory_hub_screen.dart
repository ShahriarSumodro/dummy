import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../theme/app_haptics.dart';
import '../widgets/widgets.dart';
import 'meetings_screen.dart';
import 'meeting_form_screen.dart';
import 'action_drafts_screen.dart';
import 'relationship_health_screen.dart';
import 'timeline_screen.dart';
import 'analytics_screen.dart';
import 'organizations_screen.dart';
import 'global_search_screen.dart';
import 'hardware_companion_screen.dart';
import 'reminders_screen.dart';

/// Executive Memory Hub (Linear/Things/Notion style).
/// Aggregates deeper memory systems (Meetings, Drafts, Organizations, Analytics, Timeline)
/// into a calm, focused hub without overloading the bottom navigation bar.
class MemoryHubScreen extends StatelessWidget {
  const MemoryHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryText =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Memory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search Memory',
            onPressed: () {
              AppHaptics.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenSide,
          AppSpacing.sm,
          AppSpacing.screenSide,
          100, // Bottom padding for floating navigation bar
        ),
        children: [
          // Header Card
          AppCard(
            isSubtle: true,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkAccent : AppColors.lightAccent)
                            .withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 20,
                        color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Grounded Intelligence',
                            style: TextStyle(
                              color: primaryText,
                              fontSize: AppTypography.bodySize,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Your executive archive of meetings, drafts, and touchpoints.',
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: AppTypography.captionSize,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Core Systems Section
          const AppSectionHeader(title: 'Memory Systems'),
          const SizedBox(height: AppSpacing.xs),

          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _HubRow(
                  icon: Icons.meeting_room_outlined,
                  iconColor: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                  title: 'Meeting Intelligence',
                  subtitle: 'Past discussions, AI decisions & action items',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MeetingsScreen()),
                  ),
                ),
                const Divider(height: 1),
                _HubRow(
                  icon: Icons.mark_email_read_outlined,
                  iconColor: isDark ? AppColors.semanticGreenDark : AppColors.semanticGreen,
                  title: 'Action Drafts Queue',
                  subtitle: 'Approved follow-ups ready for Email, WhatsApp & SMS',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ActionDraftsScreen()),
                  ),
                ),
                const Divider(height: 1),
                _HubRow(
                  icon: Icons.corporate_fare_outlined,
                  iconColor: isDark ? AppColors.semanticAmberDark : AppColors.semanticAmber,
                  title: 'Companies & Organizations',
                  subtitle: 'Client accounts, partner firms & linked employees',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OrganizationsScreen()),
                  ),
                ),
                const Divider(height: 1),
                _HubRow(
                  icon: Icons.notifications_none_rounded,
                  iconColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  title: 'Scheduled Reminders',
                  subtitle: 'Time-sensitive alerts and recurring notifications',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RemindersScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Network Health & Audit Section
          const AppSectionHeader(title: 'Relationship & Activity Audit'),
          const SizedBox(height: AppSpacing.xs),

          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _HubRow(
                  icon: Icons.favorite_border_rounded,
                  iconColor: isDark ? AppColors.semanticRedDark : AppColors.semanticRed,
                  title: 'Relationship Cadence Health',
                  subtitle: 'Touchpoint warmth and overdue contact outreach',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RelationshipHealthScreen()),
                  ),
                ),
                const Divider(height: 1),
                _HubRow(
                  icon: Icons.history_rounded,
                  iconColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  title: 'Activity Timeline',
                  subtitle: 'Chronological audit trail of logged interactions',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TimelineScreen()),
                  ),
                ),
                const Divider(height: 1),
                _HubRow(
                  icon: Icons.bar_chart_rounded,
                  iconColor: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                  title: 'Analytics & Delivery Rate',
                  subtitle: 'Promise fulfillment metrics and cadence analytics',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                  ),
                ),
                const Divider(height: 1),
                _HubRow(
                  icon: Icons.devices_other_rounded,
                  iconColor: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                  title: 'Hardware Companion',
                  subtitle: 'Wearable microphone and local companion pairing',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HardwareCompanionScreen()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HubRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HubRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        AppHaptics.lightImpact();
        onTap();
      },
      borderRadius: AppRadius.cardRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: iconColor),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      fontSize: AppTypography.bodySize,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      fontSize: AppTypography.captionSize,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
