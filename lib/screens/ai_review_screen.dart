import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ai_extraction_result.dart';
import '../models/commitment.dart';
import '../models/reminder.dart';
import '../services/database_service.dart';

/// Review & Confirm Screen.
/// Follows the Master Rule: Never silently turn AI inferences into permanent facts.
/// The user explicitly reviews, edits, and confirms before anything is saved to SQLite.
class AiReviewScreen extends StatefulWidget {
  final AiExtractionResult extraction;

  const AiReviewScreen({super.key, required this.extraction});

  @override
  State<AiReviewScreen> createState() => _AiReviewScreenState();
}

class _AiReviewScreenState extends State<AiReviewScreen> {
  final _db = DatabaseService();
  bool _isSaving = false;

  late final AiExtractionResult _result;

  @override
  void initState() {
    super.initState();
    _result = widget.extraction;
  }

  Future<void> _saveAll() async {
    setState(() => _isSaving = true);

    try {
      // 1. Save approved contacts
      final contactIdMap = <String, int>{};
      for (final ec in _result.contacts.where((c) => c.isSelected)) {
        if (ec.matchedExistingContactId != null) {
          contactIdMap[ec.name.toLowerCase()] = ec.matchedExistingContactId!;
        } else {
          final newContact = ec.toContact();
          final id = await _db.insertContact(newContact);
          contactIdMap[ec.name.toLowerCase()] = id;
        }
      }

      // 2. Save approved commitments
      final savedCommitmentIds = <int>[];
      for (final ec in _result.commitments.where((c) => c.isSelected)) {
        int? linkedContactId = ec.matchedContactId;
        if (linkedContactId == null && ec.contactName != null) {
          linkedContactId = contactIdMap[ec.contactName!.toLowerCase()];
        }

        final commitment = Commitment(
          title: ec.title,
          description: ec.description,
          type: ec.type,
          dueDate: ec.dueDate,
          contactId: linkedContactId,
          status: CommitmentStatus.pending,
        );

        final id = await _db.insertCommitment(commitment);
        savedCommitmentIds.add(id);
      }

      // 3. Save approved reminders
      for (final er in _result.reminders.where((r) => r.isSelected)) {
        final reminder = Reminder(
          title: er.title,
          remindAt: er.remindAt,
          isRecurring: er.isRecurring,
          recurringRule: er.recurringRule,
          commitmentId:
              savedCommitmentIds.isNotEmpty ? savedCommitmentIds.first : null,
          status: ReminderStatus.pending,
        );
        await _db.insertReminder(reminder);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Memories and commitments confirmed & saved!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // true = saved
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('EEE, MMM d · h:mm a');

    final selectedCommitmentsCount =
        _result.commitments.where((c) => c.isSelected).length;
    final selectedContactsCount =
        _result.contacts.where((c) => c.isSelected).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Extracted Memory'),
      ),
      body: _isSaving
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Saving to your personal memory database...'),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info banner explaining confirmation principle
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Review and edit AI-detected items below. Only checked items will be committed to your memory.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Commitments Section ──
                if (_result.commitments.isNotEmpty) ...[
                  Text(
                    'Commitments & Responsibilities',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._result.commitments.map((c) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: c.isSelected,
                                    onChanged: (val) {
                                      setState(() => c.isSelected = val ?? false);
                                    },
                                  ),
                                  Expanded(
                                    child: Chip(
                                      label: Text(
                                        c.type.label,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: c.confidence >= 0.85
                                          ? Colors.green.withValues(alpha: 0.15)
                                          : (c.confidence >= 0.65
                                              ? Colors.amber.withValues(alpha: 0.15)
                                              : Colors.orange.withValues(alpha: 0.15)),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: c.confidence >= 0.85
                                            ? Colors.green
                                            : (c.confidence >= 0.65 ? Colors.amber : Colors.orange),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      c.confidenceLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: c.confidence >= 0.85
                                            ? Colors.green.shade800
                                            : (c.confidence >= 0.65
                                                ? Colors.amber.shade900
                                                : Colors.orange.shade900),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              TextFormField(
                                initialValue: c.title,
                                decoration: const InputDecoration(
                                  labelText: 'Commitment Title',
                                  isDense: true,
                                ),
                                onChanged: (val) => c.title = val,
                              ),
                              const SizedBox(height: 8),
                              if (c.sourceExcerpt != null && c.sourceExcerpt!.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.format_quote, size: 14, color: theme.colorScheme.outline),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Source: "${c.sourceExcerpt}"',
                                          style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (c.dueDate != null)
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.event, size: 20),
                                  title: Text('Due: ${dateFormat.format(c.dueDate!)}'),
                                  trailing: const Icon(Icons.edit, size: 16),
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: c.dueDate!,
                                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (picked != null && mounted) {
                                      setState(() {
                                        c.dueDate = DateTime(
                                          picked.year,
                                          picked.month,
                                          picked.day,
                                          c.dueDate!.hour,
                                          c.dueDate!.minute,
                                        );
                                      });
                                    }
                                  },
                                ),
                              if (c.contactName != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Linked to: ${c.contactName}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )),
                  const SizedBox(height: 16),
                ],

                // ── Contacts Section ──
                if (_result.contacts.isNotEmpty) ...[
                  Text(
                    'People Mentioned',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._result.contacts.map((contact) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: CheckboxListTile(
                          value: contact.isSelected,
                          onChanged: (val) {
                            setState(() => contact.isSelected = val ?? false);
                          },
                          title: Text(contact.name),
                          subtitle: Text(
                            contact.matchedExistingContactId != null
                                ? 'Matches existing contact in your database'
                                : (contact.company != null
                                    ? 'New contact at ${contact.company}'
                                    : 'New contact'),
                          ),
                          secondary: CircleAvatar(
                            child: Text(contact.name.isNotEmpty ? contact.name[0] : '?'),
                          ),
                        ),
                      )),
                  const SizedBox(height: 16),
                ],

                // ── Reminders Section ──
                if (_result.reminders.isNotEmpty) ...[
                  Text(
                    'Suggested Reminders',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._result.reminders.map((r) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: CheckboxListTile(
                          value: r.isSelected,
                          onChanged: (val) {
                            setState(() => r.isSelected = val ?? false);
                          },
                          title: Text(r.title),
                          subtitle: Text('Remind at: ${dateFormat.format(r.remindAt)}'),
                          secondary: const Icon(Icons.alarm),
                        ),
                      )),
                  const SizedBox(height: 24),
                ],

                // Save Button
                FilledButton.icon(
                  onPressed: _saveAll,
                  icon: const Icon(Icons.check),
                  label: Text(
                    'Confirm & Save ($selectedCommitmentsCount commitments, $selectedContactsCount contacts)',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}
