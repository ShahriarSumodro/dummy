import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/commitment.dart';
import '../models/reminder.dart';
import '../services/database_service.dart';
import '../services/voice_service.dart';
import 'contact_form_screen.dart';
import 'commitment_form_screen.dart';
import 'reminder_form_screen.dart';
import 'commitment_detail_screen.dart';
import 'settings_screen.dart';
import 'ai_capture_sheet.dart';
import 'assistant_chat_screen.dart';
import 'meetings_screen.dart';
import 'organizations_screen.dart';
import 'briefing_screen.dart';
import 'relationship_health_screen.dart';
import 'action_drafts_screen.dart';
import 'global_search_screen.dart';
import 'commitments_screen.dart';
import 'analytics_screen.dart';
import 'voice_capture_screen.dart';

/// Home / Dashboard screen.
/// Shows live metrics, quick actions, and urgent follow-ups.
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

  Future<void> _loadDashboardData() async {
    try {
      final overdue = await _db.countOverdueCommitments();
      final today = await _db.countTodayCommitments();
      final upcoming = await _db.countUpcomingReminders();
      final contacts = await _db.countContacts();

      final allCommitments = await _db.getAllCommitments(statusFilter: 'pending');
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
    } catch (e, stack) {
      debugPrint('HomeScreen error loading dashboard: $e\n$stack');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    VoiceService().stop();
    super.dispose();
  }

  String _buildSpokenBriefingSummary() {
    final buffer = StringBuffer();
    buffer.write('Good day! Here is your RemembrAI business memory briefing. ');
    if (_overdueCount > 0) {
      buffer.write('You have $_overdueCount overdue promise${_overdueCount > 1 ? 's' : ''} that need attention. ');
    } else {
      buffer.write('You have zero overdue promises. ');
    }
    if (_todayCount > 0) {
      buffer.write('You have $_todayCount promise${_todayCount > 1 ? 's' : ''} due today. ');
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

  bool _isDueToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'RemembrAI',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search Memory',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.psychology_outlined),
            tooltip: 'Talk to Assistant',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AssistantChatScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _loadDashboardData();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Greeting & Subtitle
                  Text(
                    'Personal Business Memory',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Track promises, follow-ups, and commitments.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Overdue attention alert banner
                  if (_overdueCount > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.error.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: theme.colorScheme.error, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$_overdueCount Overdue Promise${_overdueCount > 1 ? 's' : ''} Need Action',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tap to view and prepare instant follow-up drafts.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.error,
                              foregroundColor: theme.colorScheme.onError,
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CommitmentsScreen(),
                                ),
                              );
                            },
                            child: const Text('Review', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),

                  // Voice Audio Briefing Card
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ValueListenableBuilder<TtsState>(
                      valueListenable: VoiceService().ttsState,
                      builder: (context, state, _) {
                        final isSpeaking = state == TtsState.playing;
                        return Material(
                          color: isSpeaking
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              if (isSpeaking) {
                                VoiceService().stop();
                              } else {
                                final spokenText = _buildSpokenBriefingSummary();
                                VoiceService().speak(spokenText);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Icon(
                                    isSpeaking ? Icons.stop_circle : Icons.record_voice_over_outlined,
                                    color: isSpeaking ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isSpeaking ? 'Speaking Daily Briefing...' : 'Listen to Morning Audio Briefing',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isSpeaking ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                          ),
                                        ),
                                        Text(
                                          isSpeaking
                                              ? 'Tap to stop voice playback'
                                              : '$_todayCount due today • $_overdueCount overdue • $_contactsCount contacts',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    isSpeaking ? 'STOP' : 'LISTEN',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Speak to RemembrAI Voice Decoder Card
                  Card(
                    color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: theme.colorScheme.secondary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.secondary,
                        foregroundColor: theme.colorScheme.onSecondary,
                        child: const Icon(Icons.mic),
                      ),
                      title: const Text(
                        'Speak with RemembrAI (Voice AI)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text('Speak naturally → decodes commitments & sets up reminders'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final res = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (_) => const VoiceCaptureScreen()),
                        );
                        if (res == true) {
                          _loadDashboardData();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // AI Smart Capture Card
                  Card(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        child: const Icon(Icons.auto_awesome),
                      ),
                      title: const Text(
                        'AI Memory Capture',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text('Note or conversation → structured promises & follow-ups'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _openAiCapture,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quick Action Buttons Row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final res = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ContactFormScreen(),
                              ),
                            );
                            if (res != null) {
                              await _db.insertContact(res);
                              _loadDashboardData();
                            }
                          },
                          icon: const Icon(Icons.person_add, size: 18),
                          label: const Text('Contact', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () async {
                            final res = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CommitmentFormScreen(),
                              ),
                            );
                            if (res != null) {
                              await _db.insertCommitment(res);
                              _loadDashboardData();
                            }
                          },
                          icon: const Icon(Icons.add_task, size: 18),
                          label: const Text('Commit', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
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
                          icon: const Icon(Icons.alarm_add, size: 18),
                          label: const Text('Reminder', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 2x2 Grid of Key Metrics
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.warning_amber_rounded,
                          count: _overdueCount,
                          label: 'Overdue',
                          color: theme.colorScheme.error,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.today,
                          count: _todayCount,
                          label: 'Due Today',
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.notifications_active_outlined,
                          count: _upcomingRemindersCount,
                          label: 'Upcoming (7d)',
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.contacts_outlined,
                          count: _contactsCount,
                          label: 'Contacts',
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Executive Hub Shortcuts
                  Text(
                    'Executive Toolkit',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _ToolPill(
                          icon: Icons.psychology,
                          label: 'AI Chat',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AssistantChatScreen(),
                            ),
                          ),
                        ),
                        _ToolPill(
                          icon: Icons.auto_stories_outlined,
                          label: 'Briefing Memo',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BriefingScreen(),
                            ),
                          ),
                        ),
                        _ToolPill(
                          icon: Icons.groups_outlined,
                          label: 'Meetings',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MeetingsScreen(),
                            ),
                          ),
                        ),
                        _ToolPill(
                          icon: Icons.business_outlined,
                          label: 'Companies',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const OrganizationsScreen(),
                            ),
                          ),
                        ),
                        _ToolPill(
                          icon: Icons.drafts_outlined,
                          label: 'Drafts',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ActionDraftsScreen(),
                            ),
                          ),
                        ),
                        _ToolPill(
                          icon: Icons.radar,
                          label: 'Health Radar',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RelationshipHealthScreen(),
                            ),
                          ),
                        ),
                        _ToolPill(
                          icon: Icons.insights_outlined,
                          label: 'Say-Do Stats',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AnalyticsScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Urgent Commitments Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Needs Attention',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_urgentCommitments.isNotEmpty)
                        Text(
                          '${_urgentCommitments.length} pending',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_urgentCommitments.isEmpty)
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: Colors.green),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'You are all caught up! No overdue or due-today commitments.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._urgentCommitments.map((c) => _buildCommitmentTile(c, theme)),

                  const SizedBox(height: 24),

                  // Today's Reminders Section
                  Text(
                    "Today's Reminders",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (_todayReminders.isEmpty)
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No reminders scheduled for today.'),
                      ),
                    )
                  else
                    ..._todayReminders.map((r) => _buildReminderTile(r, theme)),

                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAiCapture,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('AI Capture'),
      ),
    );
  }

  Future<void> _openAiCapture() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const AiCaptureSheet(),
    );
    if (saved == true) {
      _loadDashboardData();
    }
  }

  Widget _buildCommitmentTile(Commitment c, ThemeData theme) {
    final dateFormat = DateFormat('MMM d, h:mm a');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          c.isOverdue ? Icons.error_outline : Icons.schedule,
          color: c.isOverdue ? theme.colorScheme.error : theme.colorScheme.primary,
        ),
        title: Text(
          c.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [
            c.type.label,
            if (c.contactName != null) c.contactName!,
            if (c.dueDate != null) dateFormat.format(c.dueDate!),
          ].join(' · '),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CommitmentDetailScreen(commitmentId: c.id!),
            ),
          );
          _loadDashboardData();
        },
      ),
    );
  }

  Widget _buildReminderTile(Reminder r, ThemeData theme) {
    final timeFormat = DateFormat('h:mm a');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          Icons.alarm,
          color: r.isPastDue ? theme.colorScheme.error : theme.colorScheme.secondary,
        ),
        title: Text(r.title),
        subtitle: Text('Due at ${timeFormat.format(r.remindAt)}'),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 18, color: theme.colorScheme.primary),
        label: Text(label),
        onPressed: onTap,
      ),
    );
  }
}
