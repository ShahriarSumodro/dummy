import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/commitment.dart';
import '../models/reminder.dart';
import '../services/database_service.dart';
import '../services/voice_service.dart';
import '../theme/design_tokens.dart';
import '../theme/app_haptics.dart';
import '../widgets/widgets.dart';
import 'commitment_detail_screen.dart';
import 'commitment_form_screen.dart';
import 'commitments_screen.dart';
import 'reminder_form_screen.dart';
import 'settings_screen.dart';
import 'assistant_chat_screen.dart';
import 'global_search_screen.dart';

/// Redesigned Executive Home & Assistant Dashboard.
/// Follows strict Linear/Things design aesthetics:
/// Restraint, calm typography, generous whitespace, skeleton loaders, and tactile feedback.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseService();

  int _overdueCount = 0;
  int _todayCount = 0;
  int _upcomingRemindersCount = 0;
  int _contactsCount = 0;

  List<Commitment> _urgentCommitments = [];
  List<Reminder> _todayReminders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    VoiceService().stop();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    try {
      final overdue = await _db.countOverdueCommitments();
      final today = await _db.countTodayCommitments();
      final upcoming = await _db.countUpcomingReminders();
      final contacts = await _db.countContacts();

      final allCommitments =
          await _db.getAllCommitments(statusFilter: 'pending');
      final urgent = allCommitments
          .where((c) => c.isOverdue || _isDueToday(c.dueDate))
          .take(5)
          .toList();

      final allReminders = await _db.getAllReminders(statusFilter: 'pending');
      final now = DateTime.now();
      final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final todayRems = allReminders
          .where((r) => r.remindAt.isBefore(endOfToday))
          .take(5)
          .toList();

      if (mounted) {
        setState(() {
          _overdueCount = overdue;
          _todayCount = today;
          _upcomingRemindersCount = upcoming;
          _contactsCount = contacts;
          _urgentCommitments = urgent;
          _todayReminders = todayRems;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isDueToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _buildSpokenBriefingSummary() {
    final buffer = StringBuffer();
    buffer.write('Good day. Here is your RemembrAI business memory briefing. ');
    if (_overdueCount > 0) {
      buffer.write(
          'You have $_overdueCount overdue promise${_overdueCount > 1 ? 's' : ''} requiring attention. ');
    } else {
      buffer.write('Zero overdue promises pending. ');
    }
    if (_todayCount > 0) {
      buffer.write(
          'You have $_todayCount promise${_todayCount > 1 ? 's' : ''} scheduled today. ');
    } else {
      buffer.write('No deliverables due today. ');
    }
    if (_urgentCommitments.isNotEmpty) {
      final top = _urgentCommitments.first;
      final topSpeech = VoiceService.formatCommitmentSpeech(
        title: top.title,
        type: top.type,
        contactName: top.contactName,
        dueDate: top.dueDate,
      );
      buffer.write('Priority item: $topSpeech ');
    }
    buffer.write('You are tracking $_contactsCount contacts in your business network.');
    return buffer.toString();
  }

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
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.screenSide),
          child: Center(
            child: GestureDetector(
              onTap: () async {
                AppHaptics.lightImpact();
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
                _loadDashboardData();
              },
              child: const AppAvatar(name: 'User', size: 34),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              'RemembrAI',
              style: TextStyle(
                color: primaryText,
                fontSize: AppTypography.subtitleSize,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.semanticGreen,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
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
          IconButton(
            icon: const Icon(Icons.psychology_outlined),
            tooltip: 'Ask Assistant',
            onPressed: () {
              AppHaptics.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AssistantChatScreen()),
              );
            },
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: _loading
          ? ListView(
              padding: const EdgeInsets.all(AppSpacing.screenSide),
              children: [
                AppSkeleton.card(height: 90),
                const SizedBox(height: AppSpacing.md),
                AppSkeleton.card(height: 72),
                const SizedBox(height: AppSpacing.lg),
                AppSkeleton.row(),
                const SizedBox(height: AppSpacing.xs),
                AppSkeleton.row(),
              ],
            )
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenSide,
                  AppSpacing.sm,
                  AppSpacing.screenSide,
                  100, // Space for floating bottom bar
                ),
                children: [
                  // 1. Spoken Executive Audio Briefing Module
                  ValueListenableBuilder<TtsState>(
                    valueListenable: VoiceService().ttsState,
                    builder: (context, ttsState, _) {
                      final isPlaying = ttsState == TtsState.playing;
                      return AppCard(
                        isSubtle: true,
                        onTap: () {
                          if (isPlaying) {
                            AppHaptics.lightImpact();
                            VoiceService().stop();
                          } else {
                            AppHaptics.mediumImpact();
                            final speech = _buildSpokenBriefingSummary();
                            VoiceService().speak(speech);
                          }
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: isPlaying
                                    ? (isDark
                                        ? AppColors.darkAccent
                                        : AppColors.lightAccent)
                                    : (isDark
                                        ? AppColors.darkSurface
                                        : AppColors.lightSurface),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.darkHairline
                                      : AppColors.lightHairline,
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                isPlaying
                                    ? Icons.stop_rounded
                                    : Icons.play_arrow_rounded,
                                size: 24,
                                color: isPlaying
                                    ? Colors.white
                                    : (isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isPlaying
                                        ? 'Speaking Morning Briefing...'
                                        : 'Daily Executive Briefing',
                                    style: TextStyle(
                                      color: primaryText,
                                      fontSize: AppTypography.bodySize,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.1,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isPlaying
                                        ? 'Tap to pause audio speech'
                                        : '$_todayCount due today · $_overdueCount overdue · $_contactsCount in network',
                                    style: TextStyle(
                                      color: secondaryText,
                                      fontSize: AppTypography.captionSize,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AppBadge(
                              label: isPlaying ? 'ACTIVE' : 'AUDIO',
                              variant: isPlaying
                                  ? AppBadgeVariant.accent
                                  : AppBadgeVariant.neutral,
                              isSmall: true,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 2. Overdue Attention Alert (Contextual)
                  if (_overdueCount > 0) ...[
                    AppCard(
                      backgroundColor: isDark
                          ? AppColors.semanticRedDarkSubtle
                          : AppColors.semanticRedLight,
                      borderColor: (isDark
                              ? AppColors.semanticRedDark
                              : AppColors.semanticRed)
                          .withValues(alpha: 0.3),
                      onTap: () {
                        AppHaptics.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CommitmentsScreen(),
                          ),
                        ).then((_) => _loadDashboardData());
                      },
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 20,
                            color: isDark
                                ? AppColors.semanticRedDark
                                : AppColors.semanticRed,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              '$_overdueCount overdue promise${_overdueCount > 1 ? 's' : ''} require attention',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.semanticRedDark
                                    : AppColors.semanticRed,
                                fontSize: AppTypography.secondarySize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: isDark
                                ? AppColors.semanticRedDark
                                : AppColors.semanticRed,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // 3. Compact High-Density Executive Metrics
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _MetricColumn(
                          count: _todayCount,
                          label: 'Today',
                          color: isDark
                              ? AppColors.darkAccent
                              : AppColors.lightAccent,
                        ),
                        _Divider(),
                        _MetricColumn(
                          count: _overdueCount,
                          label: 'Overdue',
                          color: _overdueCount > 0
                              ? (isDark
                                  ? AppColors.semanticRedDark
                                  : AppColors.semanticRed)
                              : secondaryText,
                        ),
                        _Divider(),
                        _MetricColumn(
                          count: _upcomingRemindersCount,
                          label: 'Alerts',
                          color: secondaryText,
                        ),
                        _Divider(),
                        _MetricColumn(
                          count: _contactsCount,
                          label: 'Network',
                          color: secondaryText,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // 4. Priority Deliverables & Commitments
                  AppSectionHeader(
                    title: 'Priority Commitments',
                    actionLabel: 'View All',
                    onAction: () {
                      AppHaptics.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CommitmentsScreen(),
                        ),
                      ).then((_) => _loadDashboardData());
                    },
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  if (_urgentCommitments.isEmpty)
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.lg,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            color: isDark
                                ? AppColors.semanticGreenDark
                                : AppColors.semanticGreen,
                            size: 22,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'All caught up today',
                                  style: TextStyle(
                                    color: primaryText,
                                    fontSize: AppTypography.secondarySize,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'No pending promises due right now.',
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
                    )
                  else
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (int i = 0; i < _urgentCommitments.length; i++) ...[
                            _CommitmentRow(
                              commitment: _urgentCommitments[i],
                              onTap: () async {
                                AppHaptics.lightImpact();
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CommitmentDetailScreen(
                                      commitmentId: _urgentCommitments[i].id!,
                                    ),
                                  ),
                                );
                                _loadDashboardData();
                              },
                            ),
                            if (i < _urgentCommitments.length - 1)
                              const Divider(height: 1),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xl),

                  // 5. Today's Scheduled Reminders
                  AppSectionHeader(
                    title: "Today's Alerts",
                    actionLabel: '+ New Alert',
                    onAction: () async {
                      AppHaptics.lightImpact();
                      final res = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ReminderFormScreen(),
                        ),
                      );
                      if (res != null) {
                        await _db.insertReminder(res);
                        _loadDashboardData();
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  if (_todayReminders.isEmpty)
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            color: secondaryText,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'No reminder alerts scheduled for the rest of today.',
                              style: TextStyle(
                                color: secondaryText,
                                fontSize: AppTypography.captionSize,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (int i = 0; i < _todayReminders.length; i++) ...[
                            _ReminderRow(
                              reminder: _todayReminders[i],
                              onComplete: () async {
                                AppHaptics.success();
                                final updated = _todayReminders[i]
                                    .copyWith(status: ReminderStatus.completed);
                                await _db.updateReminder(updated);
                                _loadDashboardData();
                              },
                            ),
                            if (i < _todayReminders.length - 1)
                              const Divider(height: 1),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _MetricColumn({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: AppTypography.titleSize,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
            fontSize: AppTypography.captionSize,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 1,
      height: 28,
      color: isDark ? AppColors.darkHairline : AppColors.lightHairline,
    );
  }
}

class _CommitmentRow extends StatelessWidget {
  final Commitment commitment;
  final VoidCallback onTap;

  const _CommitmentRow({
    required this.commitment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryText =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    AppBadge badge;
    if (commitment.isOverdue) {
      badge = AppBadge.overdue(isSmall: true);
    } else if (commitment.type == CommitmentType.promiseMade) {
      badge = const AppBadge(
        label: 'Promised',
        variant: AppBadgeVariant.accent,
        isSmall: true,
      );
    } else if (commitment.type == CommitmentType.promiseReceived) {
      badge = const AppBadge(
        label: 'Expecting',
        variant: AppBadgeVariant.neutral,
        isSmall: true,
      );
    } else {
      badge = const AppBadge(
        label: 'Task',
        variant: AppBadgeVariant.neutral,
        isSmall: true,
      );
    }

    final dateLabel = commitment.dueDate != null
        ? DateFormat('EEE · h:mm a').format(commitment.dueDate!)
        : 'Upcoming';

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    commitment.title,
                    style: TextStyle(
                      color: primaryText,
                      fontSize: AppTypography.bodySize,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    commitment.contactName != null
                        ? '${commitment.contactName} · $dateLabel'
                        : dateLabel,
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: AppTypography.captionSize,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            badge,
          ],
        ),
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  final Reminder reminder;
  final VoidCallback onComplete;

  const _ReminderRow({
    required this.reminder,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryText =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.circle_outlined, size: 20),
            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
            tooltip: 'Mark Complete',
            onPressed: onComplete,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.title,
                  style: TextStyle(
                    color: primaryText,
                    fontSize: AppTypography.secondarySize,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  DateFormat('h:mm a').format(reminder.remindAt),
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
    );
  }
}
