import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/commitment.dart';
import '../models/contact.dart';
import '../services/database_service.dart';
import '../theme/design_tokens.dart';
import '../theme/app_haptics.dart';
import '../widgets/widgets.dart';

/// Redesigned Commitment Creation & Edit Form.
class CommitmentFormScreen extends StatefulWidget {
  final Commitment? commitment;
  final Contact? preselectedContact;

  const CommitmentFormScreen({
    super.key,
    this.commitment,
    this.preselectedContact,
  });

  @override
  State<CommitmentFormScreen> createState() => _CommitmentFormScreenState();
}

class _CommitmentFormScreenState extends State<CommitmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseService();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  CommitmentType _type = CommitmentType.task;
  DateTime? _dueDate;
  Contact? _selectedContact;
  List<Contact> _contacts = [];
  List<Map<String, dynamic>> _conflicts = [];
  bool _loadingContacts = true;

  bool get _isEditing => widget.commitment != null;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.commitment?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.commitment?.description ?? '');

    if (widget.commitment != null) {
      _type = widget.commitment!.type;
      _dueDate = widget.commitment!.dueDate;
      if (_dueDate != null) {
        _checkConflicts(_dueDate!);
      }
    }

    _loadContacts();
  }

  Future<void> _checkConflicts(DateTime date) async {
    final conflicts = await _db.checkScheduleConflicts(
      date,
      excludeCommitmentId: widget.commitment?.id,
    );
    if (mounted) {
      setState(() => _conflicts = conflicts);
    }
  }

  Future<void> _loadContacts() async {
    final contacts = await _db.getAllContacts();
    if (mounted) {
      setState(() {
        _contacts = contacts;
        if (widget.preselectedContact != null) {
          _selectedContact = widget.preselectedContact;
        } else if (widget.commitment?.contactId != null) {
          _selectedContact = contacts.cast<Contact?>().firstWhere(
                (c) => c!.id == widget.commitment!.contactId,
                orElse: () => null,
              );
        }
        _loadingContacts = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    AppHaptics.lightImpact();
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_dueDate ?? now),
      );

      setState(() {
        if (time != null) {
          _dueDate =
              DateTime(date.year, date.month, date.day, time.hour, time.minute);
        } else {
          _dueDate = DateTime(date.year, date.month, date.day, 17, 0);
        }
      });
      _checkConflicts(_dueDate!);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    AppHaptics.success();

    final commitment = Commitment(
      id: widget.commitment?.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      contactId: _selectedContact?.id,
      type: _type,
      status: widget.commitment?.status ?? CommitmentStatus.pending,
      dueDate: _dueDate,
      completedAt: widget.commitment?.completedAt,
      createdAt: widget.commitment?.createdAt,
      contactName: _selectedContact?.name,
    );

    Navigator.pop(context, commitment);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('EEE, MMM d, yyyy · h:mm a');

    final primaryText =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Commitment' : 'New Commitment'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: AppButton(
              label: 'Save',
              onPressed: _save,
              size: AppButtonSize.medium,
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenSide),
          children: [
            // 1. Type Selector Pills
            Text(
              'COMMITMENT TYPE',
              style: TextStyle(
                color: secondaryText,
                fontSize: AppTypography.captionSize,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: CommitmentType.values.map((t) {
                  final isSelected = _type == t;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(t.label),
                      selected: isSelected,
                      selectedColor: isDark
                          ? AppColors.darkAccentSubtle
                          : AppColors.lightAccentSubtle,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? (isDark
                                ? AppColors.darkAccent
                                : AppColors.lightAccent)
                            : secondaryText,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        fontSize: AppTypography.secondarySize,
                      ),
                      onSelected: (val) {
                        if (val) {
                          AppHaptics.selectionClick();
                          setState(() => _type = t);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // 2. Title Input
            AppTextField(
              controller: _titleController,
              label: 'Title *',
              hintText: _type.hint,
              textCapitalization: TextCapitalization.sentences,
              autofocus: !_isEditing,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please describe the commitment'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),

            // 3. Description Input
            AppTextField(
              controller: _descriptionController,
              label: 'Context & Notes (optional)',
              hintText: 'Additional details or background...',
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.md),

            // 4. Contact Association Card
            Text(
              'ASSOCIATED CONTACT',
              style: TextStyle(
                color: secondaryText,
                fontSize: AppTypography.captionSize,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (_loadingContacts)
              const LinearProgressIndicator()
            else
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: _selectedContact?.id,
                    hint: Text(
                      'Select a contact (optional)',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextTertiary,
                      ),
                    ),
                    items: [
                      DropdownMenuItem<int>(
                        value: null,
                        child: Text(
                          'None',
                          style: TextStyle(color: secondaryText),
                        ),
                      ),
                      ..._contacts.map(
                        (c) => DropdownMenuItem<int>(
                          value: c.id,
                          child: Text(
                            c.name,
                            style: TextStyle(color: primaryText),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (id) {
                      AppHaptics.selectionClick();
                      setState(() {
                        _selectedContact = id == null
                            ? null
                            : _contacts.firstWhere((c) => c.id == id);
                      });
                    },
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),

            // 5. Due Date Card
            Text(
              'DEADLINE',
              style: TextStyle(
                color: secondaryText,
                fontSize: AppTypography.captionSize,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppCard(
              onTap: _pickDueDate,
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 20,
                    color: isDark
                        ? AppColors.darkAccent
                        : AppColors.lightAccent,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _dueDate != null
                              ? dateFormat.format(_dueDate!)
                              : 'No deadline set',
                          style: TextStyle(
                            color: primaryText,
                            fontSize: AppTypography.bodySize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Tap to pick date & time',
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: AppTypography.captionSize,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_dueDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 20),
                      onPressed: () {
                        setState(() {
                          _dueDate = null;
                          _conflicts = [];
                        });
                      },
                    ),
                ],
              ),
            ),

            // 6. Schedule Conflict Warning
            if (_conflicts.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                backgroundColor: isDark
                    ? AppColors.semanticAmberDarkSubtle
                    : AppColors.semanticAmberLight,
                borderColor: (isDark
                        ? AppColors.semanticAmberDark
                        : AppColors.semanticAmber)
                    .withValues(alpha: 0.3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: isDark
                          ? AppColors.semanticAmberDark
                          : AppColors.semanticAmber,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Schedule Conflict Detected',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.semanticAmberDark
                                  : AppColors.semanticAmber,
                              fontSize: AppTypography.secondarySize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Overlaps within ±2 hours with ${_conflicts.first['label']} (${DateFormat('MMM d, h:mm a').format(_conflicts.first['date'] as DateTime)})',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.semanticAmberDark
                                  : AppColors.semanticAmber,
                              fontSize: AppTypography.captionSize,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
