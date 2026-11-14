import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reminder.dart';
import '../models/contact.dart';
import '../models/commitment.dart';
import '../services/database_service.dart';
import '../theme/app_haptics.dart';
import '../theme/design_tokens.dart';
import '../widgets/widgets.dart';

/// Form screen for creating or editing a reminder.
class ReminderFormScreen extends StatefulWidget {
  final Reminder? reminder;
  final Contact? preselectedContact;
  final Commitment? preselectedCommitment;

  const ReminderFormScreen({
    super.key,
    this.reminder,
    this.preselectedContact,
    this.preselectedCommitment,
  });

  @override
  State<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends State<ReminderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseService();

  late final TextEditingController _titleController;
  late final TextEditingController _notesController;

  DateTime _remindAt = DateTime.now().add(const Duration(hours: 1));
  bool _isRecurring = false;
  String? _recurringRule; // 'daily', 'weekly', 'monthly'

  Contact? _selectedContact;
  Commitment? _selectedCommitment;

  List<Contact> _contacts = [];
  List<Commitment> _commitments = [];
  bool _loadingRelations = true;

  bool get _isEditing => widget.reminder != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.reminder?.title ?? '');
    _notesController = TextEditingController(text: widget.reminder?.notes ?? '');

    if (widget.reminder != null) {
      _remindAt = widget.reminder!.remindAt;
      _isRecurring = widget.reminder!.isRecurring;
      _recurringRule = widget.reminder!.recurringRule;
    } else if (widget.preselectedCommitment != null) {
      _titleController.text = 'Follow up: ${widget.preselectedCommitment!.title}';
      if (widget.preselectedCommitment!.dueDate != null) {
        _remindAt = widget.preselectedCommitment!.dueDate!;
      }
    }

    _loadRelations();
  }

  Future<void> _loadRelations() async {
    final contacts = await _db.getAllContacts();
    final commitments = await _db.getAllCommitments();

    if (mounted) {
      setState(() {
        _contacts = contacts;
        _commitments = commitments;

        if (widget.preselectedContact != null) {
          _selectedContact = widget.preselectedContact;
        } else if (widget.reminder?.contactId != null) {
          _selectedContact = contacts.cast<Contact?>().firstWhere(
                (c) => c!.id == widget.reminder!.contactId,
                orElse: () => null,
              );
        }

        if (widget.preselectedCommitment != null) {
          _selectedCommitment = widget.preselectedCommitment;
        } else if (widget.reminder?.commitmentId != null) {
          _selectedCommitment = commitments.cast<Commitment?>().firstWhere(
                (c) => c!.id == widget.reminder!.commitmentId,
                orElse: () => null,
              );
        }

        _loadingRelations = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    AppHaptics.lightImpact();
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _remindAt.isBefore(now) ? now : _remindAt,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_remindAt),
      );

      if (time != null && mounted) {
        setState(() {
          _remindAt = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    AppHaptics.success();

    final reminder = Reminder(
      id: widget.reminder?.id,
      title: _titleController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      commitmentId: _selectedCommitment?.id,
      contactId: _selectedContact?.id,
      remindAt: _remindAt,
      isRecurring: _isRecurring,
      recurringRule: _isRecurring ? (_recurringRule ?? 'daily') : null,
      status: widget.reminder?.status ?? ReminderStatus.pending,
      createdAt: widget.reminder?.createdAt,
      contactName: _selectedContact?.name,
      commitmentTitle: _selectedCommitment?.title,
    );

    Navigator.pop(context, reminder);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, MMM d, yyyy · h:mm a');

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Reminder' : 'New Reminder', style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: AppButton(
              label: 'Save',
              size: AppButtonSize.sm,
              onPressed: _save,
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            AppTextField(
              controller: _titleController,
              label: 'Reminder Title *',
              hintText: 'e.g. Call client about contract follow-up',
              prefixIcon: Icons.alarm_rounded,
              autofocus: !_isEditing,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a reminder title' : null,
            ),
            const SizedBox(height: AppSpacing.md),

            AppTextField(
              controller: _notesController,
              label: 'Notes & Context (optional)',
              hintText: 'Any specifics to keep in mind...',
              prefixIcon: Icons.notes_rounded,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.md),

            // Remind At Card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              onTap: _pickDateTime,
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, size: 20, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REMIND AT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.muted(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateFormat.format(_remindAt),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_calendar_rounded, size: 18, color: Colors.grey),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Repeat Reminder
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.repeat_rounded, size: 20, color: _isRecurring ? AppColors.primary : Colors.grey),
                          const SizedBox(width: AppSpacing.sm),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Repeat Reminder', style: TextStyle(fontWeight: FontWeight.w600)),
                              Text(
                                _isRecurring ? 'Repeats on schedule' : 'One-time reminder',
                                style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _isRecurring,
                        activeColor: AppColors.primary,
                        onChanged: (val) {
                          AppHaptics.lightImpact();
                          setState(() {
                            _isRecurring = val;
                            if (val && _recurringRule == null) {
                              _recurringRule = 'daily';
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  if (_isRecurring) ...[
                    const Divider(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: ['daily', 'weekly', 'monthly'].map((rule) {
                        final isSel = (_recurringRule ?? 'daily') == rule;
                        return ChoiceChip(
                          label: Text(rule[0].toUpperCase() + rule.substring(1)),
                          selected: isSel,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                            color: isSel ? Colors.white : AppColors.foreground(context),
                          ),
                          onSelected: (_) {
                            AppHaptics.lightImpact();
                            setState(() => _recurringRule = rule);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Link to Contact and Commitment
            if (_loadingRelations)
              const LinearProgressIndicator()
            else ...[
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LINKED CONTEXT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.muted(context),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<int>(
                      value: _selectedContact?.id,
                      decoration: InputDecoration(
                        labelText: 'Associated Contact',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None')),
                        ..._contacts.map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            )),
                      ],
                      onChanged: (id) {
                        setState(() {
                          _selectedContact = id == null
                              ? null
                              : _contacts.firstWhere((c) => c.id == id);
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<int>(
                      value: _selectedCommitment?.id,
                      decoration: InputDecoration(
                        labelText: 'Associated Promise / Meeting',
                        prefixIcon: const Icon(Icons.handshake_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None')),
                        ..._commitments.map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.title, overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (id) {
                        setState(() {
                          _selectedCommitment = id == null
                              ? null
                              : _commitments.firstWhere((c) => c.id == id);
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
