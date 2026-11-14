import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reminder.dart';
import '../models/contact.dart';
import '../models/commitment.dart';
import '../services/database_service.dart';

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
    _titleController =
        TextEditingController(text: widget.reminder?.title ?? '');
    _notesController =
        TextEditingController(text: widget.reminder?.notes ?? '');

    if (widget.reminder != null) {
      _remindAt = widget.reminder!.remindAt;
      _isRecurring = widget.reminder!.isRecurring;
      _recurringRule = widget.reminder!.recurringRule;
    } else if (widget.preselectedCommitment != null) {
      _titleController.text =
          'Follow up: ${widget.preselectedCommitment!.title}';
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

    final reminder = Reminder(
      id: widget.reminder?.id,
      title: _titleController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
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
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Reminder' : 'New Reminder'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Reminder title *',
                hintText: 'e.g. Call client about quotation',
                prefixIcon: Icon(Icons.alarm),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please enter a reminder title'
                  : null,
              autofocus: !_isEditing,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Additional details or context...',
                prefixIcon: Icon(Icons.notes_outlined),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // Remind at DateTime picker tile
            ListTile(
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('Remind At'),
              subtitle: Text(
                dateFormat.format(_remindAt),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _pickDateTime,
            ),
            const SizedBox(height: 16),

            // Recurring options
            SwitchListTile(
              title: const Text('Repeat Reminder'),
              subtitle: Text(_isRecurring ? 'Recurring active' : 'One-time reminder'),
              value: _isRecurring,
              onChanged: (val) {
                setState(() {
                  _isRecurring = val;
                  if (val && _recurringRule == null) {
                    _recurringRule = 'daily';
                  }
                });
              },
            ),

            if (_isRecurring) ...[
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'daily', label: Text('Daily')),
                  ButtonSegment(value: 'weekly', label: Text('Weekly')),
                  ButtonSegment(value: 'monthly', label: Text('Monthly')),
                ],
                selected: {_recurringRule ?? 'daily'},
                onSelectionChanged: (val) {
                  setState(() => _recurringRule = val.first);
                },
              ),
              const SizedBox(height: 16),
            ],

            const Divider(height: 32),

            // Link contact & commitment
            if (_loadingRelations)
              const LinearProgressIndicator()
            else ...[
              DropdownButtonFormField<int>(
                key: ValueKey(_selectedContact?.id),
                initialValue: _selectedContact?.id,
                decoration: const InputDecoration(
                  labelText: 'Link to Contact (optional)',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
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
              const SizedBox(height: 16),

              DropdownButtonFormField<int>(
                key: ValueKey(_selectedCommitment?.id),
                initialValue: _selectedCommitment?.id,
                decoration: const InputDecoration(
                  labelText: 'Link to Commitment (optional)',
                  prefixIcon: Icon(Icons.handshake_outlined),
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ..._commitments.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          c.title,
                          overflow: TextOverflow.ellipsis,
                        ),
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
          ],
        ),
      ),
    );
  }
}
