import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ai_extraction_result.dart';
import '../models/commitment.dart';
import '../models/memory_item.dart';
import '../models/reminder.dart';
import '../services/database_service.dart';
import '../theme/app_haptics.dart';
import '../theme/design_tokens.dart';
import '../widgets/widgets.dart';

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
    AppHaptics.mediumImpact();
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
          commitmentId: savedCommitmentIds.isNotEmpty ? savedCommitmentIds.first : null,
          status: ReminderStatus.pending,
        );
        await _db.insertReminder(reminder);
      }

      // 4. Save approved memories (Module 2)
      for (final em in _result.memories.where((m) => m.isSelected)) {
        int? linkedContactId = em.matchedContactId;
        if (linkedContactId == null && em.contactName != null) {
          linkedContactId = contactIdMap[em.contactName!.toLowerCase()];
        }

        final memory = MemoryItem(
          category: MemoryCategory.fromString(em.category),
          content: em.content,
          contactId: linkedContactId,
          source: 'extracted_note',
          confidence: em.confidence,
          isVerified: true,
        );

        await _db.insertMemory(memory);
      }

      if (mounted) {
        AppHaptics.success();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Memories and commitments confirmed & saved!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        );
        Navigator.pop(context, true); // true = saved
      }
    } catch (e) {
      if (mounted) {
        AppHaptics.warning();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, MMM d · h:mm a');

    final selectedCommitmentsCount = _result.commitments.where((c) => c.isSelected).length;
    final selectedContactsCount = _result.contacts.where((c) => c.isSelected).length;
    final selectedRemindersCount = _result.reminders.where((r) => r.isSelected).length;
    final selectedMemoriesCount = _result.memories.where((m) => m.isSelected).length;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text('Review Extracted Memory', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _isSaving
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: AppSpacing.md),
                  Text('Saving to your personal memory database...', style: TextStyle(color: AppColors.muted(context))),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxl),
              children: [
                // Info Banner explaining confirmation gate
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: AppColors.primary, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Confirmation Gate: Review and edit AI-detected items below. Only checked items will be committed to permanent memory.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.foreground(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Commitments Section ──
                if (_result.commitments.isNotEmpty) ...[
                  AppSectionHeader(
                    title: 'Commitments & Promises',
                    count: _result.commitments.length,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ..._result.commitments.map((c) => AppCard(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: c.isSelected,
                                  activeColor: AppColors.primary,
                                  onChanged: (val) {
                                    AppHaptics.lightImpact();
                                    setState(() => c.isSelected = val ?? false);
                                  },
                                ),
                                AppBadge(
                                  label: c.type.label,
                                  variant: AppBadgeVariant.neutral,
                                ),
                                const Spacer(),
                                AppBadge(
                                  label: c.confidenceLabel,
                                  variant: c.confidence >= 0.85
                                      ? AppBadgeVariant.success
                                      : (c.confidence >= 0.65
                                          ? AppBadgeVariant.warning
                                          : AppBadgeVariant.error),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            TextFormField(
                              initialValue: c.title,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              decoration: const InputDecoration(
                                labelText: 'Commitment Title',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (val) => c.title = val,
                            ),
                            if (c.sourceExcerpt != null && c.sourceExcerpt!.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.subtle(context),
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.format_quote_rounded, size: 14, color: AppColors.muted(context)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Source: "${c.sourceExcerpt}"',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                          color: AppColors.muted(context),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (c.dueDate != null) ...[
                              const SizedBox(height: AppSpacing.xs),
                              InkWell(
                                onTap: () async {
                                  AppHaptics.lightImpact();
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
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.event_rounded, size: 16, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Due: ${dateFormat.format(c.dueDate!)}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                      const Spacer(),
                                      const Icon(Icons.edit_calendar_rounded, size: 14, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            if (c.contactName != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Linked to: ${c.contactName}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )),
                  const SizedBox(height: AppSpacing.md),
                ],

                // ── Personal & Business Facts Section (Module 2) ──
                if (_result.memories.isNotEmpty) ...[
                  AppSectionHeader(
                    title: 'Personal & Business Facts',
                    count: _result.memories.length,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ..._result.memories.map((mem) => AppCard(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: mem.isSelected,
                                  activeColor: AppColors.primary,
                                  onChanged: (val) {
                                    AppHaptics.lightImpact();
                                    setState(() => mem.isSelected = val ?? false);
                                  },
                                ),
                                DropdownButton<String>(
                                  value: MemoryCategory.values
                                          .any((c) => c.name == mem.category)
                                      ? mem.category
                                      : MemoryCategory.fact.name,
                                  isDense: true,
                                  underline: const SizedBox(),
                                  items: MemoryCategory.values.map((cat) {
                                    return DropdownMenuItem<String>(
                                      value: cat.name,
                                      child: AppBadge(
                                        label: cat.label,
                                        variant: AppBadgeVariant.neutral,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (newCat) {
                                    if (newCat != null) {
                                      setState(() => mem.category = newCat);
                                    }
                                  },
                                ),
                                const Spacer(),
                                if (mem.contactName != null)
                                  AppBadge(
                                    label: mem.contactName!,
                                    variant: AppBadgeVariant.accent,
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            TextFormField(
                              initialValue: mem.content,
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                              decoration: const InputDecoration(
                                labelText: 'Memory Fact / Preference',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (val) => mem.content = val,
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: AppSpacing.md),
                ],

                // ── Contacts Section ──
                if (_result.contacts.isNotEmpty) ...[
                  AppSectionHeader(
                    title: 'People Mentioned',
                    count: _result.contacts.length,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ..._result.contacts.map((contact) => AppCard(
                        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                        child: CheckboxListTile(
                          value: contact.isSelected,
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) {
                            AppHaptics.lightImpact();
                            setState(() => contact.isSelected = val ?? false);
                          },
                          title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(
                            contact.matchedExistingContactId != null
                                ? 'Matches existing contact in directory'
                                : (contact.company != null
                                    ? 'New contact at ${contact.company}'
                                    : 'New contact record'),
                            style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
                          ),
                          secondary: AppAvatar(name: contact.name, size: AppAvatarSize.sm),
                        ),
                      )),
                  const SizedBox(height: AppSpacing.md),
                ],

                // ── Reminders Section ──
                if (_result.reminders.isNotEmpty) ...[
                  AppSectionHeader(
                    title: 'Suggested Reminders',
                    count: _result.reminders.length,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ..._result.reminders.map((r) => AppCard(
                        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                        child: CheckboxListTile(
                          value: r.isSelected,
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) {
                            AppHaptics.lightImpact();
                            setState(() => r.isSelected = val ?? false);
                          },
                          title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(
                            'Remind at: ${dateFormat.format(r.remindAt)}',
                            style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
                          ),
                          secondary: const Icon(Icons.alarm_rounded, color: AppColors.primary),
                        ),
                      )),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Confirm and Save Button
                AppButton(
                  label: () {
                    final parts = <String>[];
                    if (selectedCommitmentsCount > 0) parts.add('$selectedCommitmentsCount commitments');
                    if (selectedContactsCount > 0) parts.add('$selectedContactsCount contacts');
                    if (selectedRemindersCount > 0) parts.add('$selectedRemindersCount reminders');
                    if (selectedMemoriesCount > 0) parts.add('$selectedMemoriesCount memories');
                    if (parts.isEmpty) return 'Confirm & Save';
                    return 'Confirm & Save (${parts.join(', ')})';
                  }(),
                  icon: Icons.check_circle_rounded,
                  fullWidth: true,
                  size: AppButtonSize.lg,
                  onPressed: _saveAll,
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
    );
  }
}
