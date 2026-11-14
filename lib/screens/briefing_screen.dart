import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/contact.dart';
import '../services/database_service.dart';
import '../services/voice_service.dart';

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
    Clipboard.setData(ClipboardData(text: _briefingContent));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Briefing copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Executive Briefing Engine'),
        actions: [
          ValueListenableBuilder<TtsState>(
            valueListenable: VoiceService().ttsState,
            builder: (context, state, _) {
              final isPlaying = state == TtsState.playing;
              return IconButton(
                icon: Icon(isPlaying ? Icons.stop_circle : Icons.volume_up),
                color: isPlaying ? Colors.tealAccent : null,
                tooltip: isPlaying ? 'Stop Audio' : 'Listen Aloud',
                onPressed: () {
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
            icon: const Icon(Icons.copy),
            tooltip: 'Copy Briefing',
            onPressed: _copyBriefing,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Regenerate',
            onPressed: _generateBriefing,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Selector Row
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.wb_sunny_outlined),
                      label: Text('Daily Briefing'),
                    ),
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.person_outline),
                      label: Text('Contact Dossier'),
                    ),
                  ],
                  selected: {_isDailyBriefing},
                  onSelectionChanged: (set) {
                    setState(() {
                      _isDailyBriefing = set.first;
                    });
                    _generateBriefing();
                  },
                ),
                const SizedBox(height: 16),

                if (!_isDailyBriefing) ...[
                  DropdownButtonFormField<int>(
                    initialValue: _selectedContact?.id,
                    decoration: const InputDecoration(
                      labelText: 'Select Person for Dossier',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    items: _allContacts
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ))
                        .toList(),
                    onChanged: (id) {
                      setState(() {
                        _selectedContact =
                            _allContacts.firstWhere((c) => c.id == id);
                      });
                      _generateBriefing();
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Briefing Card
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: SelectableText(
                      _briefingContent,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                FilledButton.tonalIcon(
                  onPressed: _copyBriefing,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Executive Memo'),
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }
}
