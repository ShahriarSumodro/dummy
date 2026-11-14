import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reminder.dart';
import '../services/database_service.dart';
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
    final isDone = reminder.status == ReminderStatus.completed;
    final updated = reminder.copyWith(
      status: isDone ? ReminderStatus.pending : ReminderStatus.completed,
    );
    await _db.updateReminder(updated);
    _loadReminders();
  }

  Future<void> _snooze(Reminder reminder, Duration duration) async {
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
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteReminder(Reminder reminder) async {
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _db.deleteReminder(reminder.id!);
      _loadReminders();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _filters.map((f) => Tab(text: f.label)).toList(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reminders.isEmpty
              ? _buildEmptyState(theme)
              : _buildList(theme),
      floatingActionButton: FloatingActionButton(
        onPressed: _addReminder,
        child: const Icon(Icons.add_alarm),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_outlined,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No reminders found',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Set reminders so you never forget a commitment or meeting follow-up.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(ThemeData theme) {
    final timeFormat = DateFormat('EEE, MMM d · h:mm a');

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _reminders.length,
      itemBuilder: (context, index) {
        final r = _reminders[index];
        final isCompleted = r.status == ReminderStatus.completed;
        final isPastDue = r.isPastDue;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            leading: IconButton(
              icon: Icon(
                isCompleted
                    ? Icons.check_circle
                    : (isPastDue
                        ? Icons.warning_amber_rounded
                        : Icons.alarm),
                color: isCompleted
                    ? Colors.green
                    : (isPastDue ? theme.colorScheme.error : theme.colorScheme.primary),
              ),
              onPressed: () => _toggleStatus(r),
            ),
            title: Text(
              r.title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: isPastDue ? theme.colorScheme.error : theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeFormat.format(r.remindAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: isPastDue ? theme.colorScheme.error : null,
                        fontWeight: isPastDue ? FontWeight.bold : null,
                      ),
                    ),
                    if (r.isRecurring) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          r.recurringRule ?? 'repeat',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (r.contactName != null || r.commitmentTitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (r.contactName != null) '👤 ${r.contactName}',
                      if (r.commitmentTitle != null) '🤝 ${r.commitmentTitle}',
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            trailing: PopupMenuButton<String>(
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
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
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
