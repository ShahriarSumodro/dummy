import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/contact.dart';
import '../services/database_service.dart';
import '../services/voice_service.dart';
import '../theme/app_haptics.dart';
import '../theme/design_tokens.dart';
import '../widgets/widgets.dart';

/// Pre-Meeting & Executive Daily Briefing Screen.
class BriefingScreen extends StatefulWidget {
  final Contact? initialContact;

  const BriefingScreen({super.key, this.initialContact});

  @override
  State<BriefingScreen> createState() => _BriefingScreenState();
}

class _BriefingScreenState extends State<BriefingScreen> {
  final _db = DatabaseService();

  bool _isDailyBriefing = true;
  Contact? _selectedContact;
  List<Contact> _allContacts = [];

  String _briefingContent = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialContact != null) {
      _isDailyBriefing = false;
      _selectedContact = widget.initialContact;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    final contacts = await _db.getAllContacts();
    _allContacts = contacts;
    await _generateBriefing();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _generateBriefing() async {
    setState(() => _loading = true);
    final buffer = StringBuffer();
    final dateFormat = DateFormat('EEEE, MMM d, yyyy');

    if (_isDailyBriefing) {
      final now = DateTime.now();
      buffer.writeln('# Executive Briefing — ${dateFormat.format(now)}\n');

      final overdueCommitments = (await _db.getAllCommitments())
          .where((c) => c.isOverdue)
          .toList();
      final todayCommitments = (await _db.getAllCommitments())
          .where((c) =>
              c.dueDate != null &&
              c.dueDate!.year == now.year &&
              c.dueDate!.month == now.month &&
              c.dueDate!.day == now.day)
          .toList();
      final meetings = (await _db.getAllMeetings())
          .where((m) =>
              m.meetingDate.year == now.year &&
              m.meetingDate.month == now.month &&
              m.meetingDate.day == now.day)
          .toList();
      final upcomingReminders = await _db.getAllReminders(statusFilter: 'pending');

      buffer.writeln('### ⚠️ Priority Overdue Items (${overdueCommitments.length})');
      if (overdueCommitments.isEmpty) {
        buffer.writeln('• No overdue commitments. You are in good shape!\n');
      } else {
        for (final c in overdueCommitments) {
          buffer.writeln('• **[${c.type.label}]** ${c.title} (With: ${c.contactName ?? 'General'})');
        }
        buffer.writeln();
      }

      buffer.writeln('### 📅 Commitments Due Today (${todayCommitments.length})');
      if (todayCommitments.isEmpty) {
        buffer.writeln('• No deliverables due today.\n');
      } else {
        for (final c in todayCommitments) {
          buffer.writeln('• ${c.title} (Person: ${c.contactName ?? 'N/A'})');
        }
        buffer.writeln();
      }

      buffer.writeln('### 🤝 Scheduled Meetings Today (${meetings.length})');
      if (meetings.isEmpty) {
        buffer.writeln('• No meetings scheduled for today.\n');
      } else {
        for (final m in meetings) {
          buffer.writeln('• **${m.title}** at ${DateFormat('h:mm a').format(m.meetingDate)} (Location: ${m.location ?? 'TBD'})');
        }
        buffer.writeln();
      }

      buffer.writeln('### ⏰ Pending Reminders (${upcomingReminders.length})');
      for (final r in upcomingReminders.take(5)) {
        buffer.writeln('• ${r.title} — ${DateFormat('h:mm a').format(r.remindAt)}');
      }
    } else {
      // Contact Specific Briefing
      final contact = _selectedContact;
      if (contact == null) {
        buffer.writeln('Please select a contact to generate briefing.');
      } else {
        buffer.writeln('# Pre-Meeting Dossier: ${contact.name}\n');
        buffer.writeln('**Company:** ${contact.company ?? 'N/A'}');
        buffer.writeln('**Role:** ${contact.role ?? 'N/A'}');
        buffer.writeln('**Phone:** ${contact.phone ?? 'N/A'} | **Email:** ${contact.email ?? 'N/A'}');
        if (contact.notes != null) {
          buffer.writeln('**Background Notes:** ${contact.notes}\n');
        } else {
          buffer.writeln();
        }

        final commitments = await _db.getCommitmentsForContact(contact.id!);
        final promisesMade = commitments
            .where((c) => c.type.name == 'promiseMade')
            .toList();
        final promisesReceived = commitments
            .where((c) => c.type.name == 'promiseReceived')
            .toList();
        final others = commitments
            .where((c) =>
                c.type.name != 'promiseMade' && c.type.name != 'promiseReceived')
            .toList();

        buffer.writeln('### 📌 Promises You Made to ${contact.name} (${promisesMade.length})');
        if (promisesMade.isEmpty) {
          buffer.writeln('• None recorded.\n');
        } else {
          for (final c in promisesMade) {
            buffer.writeln('• [${c.status.label}] ${c.title} (Due: ${c.dueDate != null ? DateFormat('MMM d').format(c.dueDate!) : 'None'})');
          }
          buffer.writeln();
        }

        buffer.writeln('### 📬 Promises They Made to You (${promisesReceived.length})');
        if (promisesReceived.isEmpty) {
          buffer.writeln('• None recorded.\n');
        } else {
          for (final c in promisesReceived) {
            buffer.writeln('• [${c.status.label}] ${c.title} (Due: ${c.dueDate != null ? DateFormat('MMM d').format(c.dueDate!) : 'None'})');
          }
          buffer.writeln();
        }

        if (others.isNotEmpty) {
          buffer.writeln('### 📋 Other Follow-ups & Tasks (${others.length})');
          for (final c in others) {
            buffer.writeln('• [${c.status.label}] ${c.title}');
          }
          buffer.writeln();
        }

        buffer.writeln('### 💡 Suggested Conversation Openers');
        buffer.writeln('• Reconnect on pending deliverables.');
        buffer.writeln('• Confirm updates since your last discussion.');
      }
    }

    if (mounted) {
      setState(() {
        _briefingContent = buffer.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    VoiceService().stop();
    super.dispose();
  }

  void _copyBriefing() {
    AppHaptics.lightImpact();
    Clipboard.setData(ClipboardData(text: _briefingContent));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Briefing copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text('Executive Briefing Engine', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          ValueListenableBuilder<TtsState>(
            valueListenable: VoiceService().ttsState,
            builder: (context, state, _) {
              final isPlaying = state == TtsState.playing;
              return IconButton(
                icon: Icon(isPlaying ? Icons.stop_circle_rounded : Icons.volume_up_rounded),
                color: isPlaying ? AppColors.error : AppColors.primary,
                tooltip: isPlaying ? 'Stop Audio' : 'Listen Aloud',
                onPressed: () {
                  AppHaptics.lightImpact();
                  if (isPlaying) {
                    VoiceService().stop();
                  } else {
                    VoiceService().speak(_briefingContent);
                  }
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy Briefing',
            onPressed: _copyBriefing,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Regenerate',
            onPressed: () {
              AppHaptics.lightImpact();
              _generateBriefing();
            },
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: _loading
          ? ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: const [
                AppSkeleton(height: 50),
                SizedBox(height: AppSpacing.md),
                AppSkeleton(height: 300),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxl),
              children: [
                // Selector Row
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.wb_sunny_outlined, size: 16),
                      label: Text('Daily Briefing'),
                    ),
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.person_outline, size: 16),
                      label: Text('Contact Dossier'),
                    ),
                  ],
                  selected: {_isDailyBriefing},
                  onSelectionChanged: (set) {
                    AppHaptics.lightImpact();
                    setState(() {
                      _isDailyBriefing = set.first;
                    });
                    _generateBriefing();
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                if (!_isDailyBriefing) ...[
                  DropdownButtonFormField<int>(
                    value: _selectedContact?.id,
                    decoration: InputDecoration(
                      labelText: 'Select Person for Dossier',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    items: _allContacts
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ))
                        .toList(),
                    onChanged: (id) {
                      AppHaptics.lightImpact();
                      setState(() {
                        _selectedContact = _allContacts.firstWhere((c) => c.id == id);
                      });
                      _generateBriefing();
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Briefing Card
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: SelectableText(
                    _briefingContent,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.55,
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Copy Executive Memo',
                  icon: Icons.copy_rounded,
                  variant: AppButtonVariant.tonal,
                  fullWidth: true,
                  size: AppButtonSize.lg,
                  onPressed: _copyBriefing,
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
    );
  }
}
