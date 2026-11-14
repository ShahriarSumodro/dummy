import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reminder.dart';
import '../services/database_service.dart';
import '../theme/app_haptics.dart';
import '../theme/design_tokens.dart';
import '../widgets/widgets.dart';
import 'reminder_form_screen.dart';

/// Reminders screen with tabs for filtering (Pending, Completed, All).
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseService();
  late TabController _tabController;
  List<Reminder> _reminders = [];
  bool _loading = true;

  String? _statusFilter = 'pending';

  static const _filters = [
    (label: 'Pending', status: 'pending'),
    (label: 'Completed', status: 'completed'),
    (label: 'All', status: null),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filters.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        AppHaptics.lightImpact();
        _statusFilter = _filters[_tabController.index].status;
        _loadReminders();
      }
    });
    _loadReminders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReminders() async {
    final reminders = await _db.getAllReminders(statusFilter: _statusFilter);
    if (mounted) {
      setState(() {
        _reminders = reminders;
        _loading = false;
      });
    }
  }

  Future<void> _addReminder() async {
    AppHaptics.lightImpact();
    final result = await Navigator.push<Reminder>(
      context,
      MaterialPageRoute(builder: (_) => const ReminderFormScreen()),
    );
    if (result != null) {
      await _db.insertReminder(result);
      _loadReminders();
    }
  }

  Future<void> _editReminder(Reminder reminder) async {
    AppHaptics.lightImpact();
    final result = await Navigator.push<Reminder>(
      context,
      MaterialPageRoute(
        builder: (_) => ReminderFormScreen(reminder: reminder),
      ),
    );
    if (result != null) {
      await _db.updateReminder(result);
      _loadReminders();
    }
  }

  Future<void> _toggleStatus(Reminder reminder) async {
    AppHaptics.mediumImpact();
    final isDone = reminder.status == ReminderStatus.completed;
    final updated = reminder.copyWith(
      status: isDone ? ReminderStatus.pending : ReminderStatus.completed,
    );
    await _db.updateReminder(updated);
    _loadReminders();
  }

  Future<void> _snooze(Reminder reminder, Duration duration) async {
    AppHaptics.lightImpact();
    final updated = reminder.copyWith(
      remindAt: DateTime.now().add(duration),
      status: ReminderStatus.snoozed,
    );
    await _db.updateReminder(updated);
    _loadReminders();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            duration.inHours >= 24
                ? 'Snoozed until tomorrow'
                : 'Snoozed for ${duration.inHours} hour(s)',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteReminder(Reminder reminder) async {
    AppHaptics.warning();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Reminder'),
        content: Text('Delete "${reminder.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      AppHaptics.success();
      await _db.deleteReminder(reminder.id!);
      _loadReminders();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        titleSpacing: AppSpacing.md,
        title: const Text('Reminders', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.subtle(context),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(AppRadius.full),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.muted(context),
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: _filters.map((f) => Tab(text: f.label)).toList(),
            ),
          ),
        ),
      ),
      body: _loading
          ? ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: 6,
              itemBuilder: (_, __) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppSkeleton(height: 72, borderRadius: BorderRadius.circular(AppRadius.lg)),
              ),
            )
          : _reminders.isEmpty
              ? Center(
                  child: AppEmptyState(
                    icon: Icons.notifications_outlined,
                    title: 'No reminders found',
                    message: 'Set reminders so you never forget a commitment, meeting follow-up, or deadline.',
                    actionLabel: 'Add Reminder',
                    onAction: _addReminder,
                  ),
                )
              : _buildList(),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 3,
          onPressed: _addReminder,
          child: const Icon(Icons.add_alarm_rounded),
        ),
      ),
    );
  }

  Widget _buildList() {
    final timeFormat = DateFormat('EEE, MMM d · h:mm a');

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 100),
      itemCount: _reminders.length,
      itemBuilder: (context, index) {
        final r = _reminders[index];
        final isCompleted = r.status == ReminderStatus.completed;
        final isPastDue = r.isPastDue;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: AppListRow(
            leading: InkWell(
              onTap: () => _toggleStatus(r),
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  isCompleted
                      ? Icons.check_circle_rounded
                      : (isPastDue ? Icons.warning_amber_rounded : Icons.alarm_rounded),
                  color: isCompleted
                      ? AppColors.success
                      : (isPastDue ? AppColors.error : AppColors.primary),
                  size: 22,
                ),
              ),
            ),
            title: r.title,
            subtitle: [
              timeFormat.format(r.remindAt),
              if (r.contactName != null) '👤 ${r.contactName}',
              if (r.commitmentTitle != null) '🤝 ${r.commitmentTitle}',
            ].join(' · '),
            badge: r.isRecurring
                ? AppBadge(label: r.recurringRule ?? 'repeat', variant: AppBadgeVariant.neutral)
                : (isPastDue && !isCompleted
                    ? const AppBadge(label: 'Past Due', variant: AppBadgeVariant.error)
                    : null),
            trailing: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, size: 18, color: AppColors.muted(context)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              onSelected: (val) {
                switch (val) {
                  case 'edit':
                    _editReminder(r);
                    break;
                  case 'snooze_1h':
                    _snooze(r, const Duration(hours: 1));
                    break;
                  case 'snooze_tomorrow':
                    _snooze(r, const Duration(days: 1));
                    break;
                  case 'delete':
                    _deleteReminder(r);
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (!isCompleted) ...[
                  const PopupMenuItem(value: 'snooze_1h', child: Text('Snooze 1 hour')),
                  const PopupMenuItem(value: 'snooze_tomorrow', child: Text('Snooze 1 day')),
                ],
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
            onTap: () => _editReminder(r),
          ),
        );
      },
    );
  }
}
