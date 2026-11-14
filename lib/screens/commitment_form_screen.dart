import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/commitment.dart';
import '../models/contact.dart';
import '../services/database_service.dart';

/// Form screen for creating or editing a commitment.
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
        // Set preselected contact.
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
          _dueDate = DateTime(
              date.year, date.month, date.day, time.hour, time.minute);
        } else {
          _dueDate =
              DateTime(date.year, date.month, date.day, 23, 59);
        }
        _loadingContacts = false;
      });
      _checkConflicts(_dueDate!);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

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
    final dateFormat = DateFormat('EEE, MMM d, yyyy · h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Commitment' : 'New Commitment'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type selector
            Text('Type',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<CommitmentType>(
              segments: CommitmentType.values
                  .map((t) => ButtonSegment(
                        value: t,
                        label: Text(t.label, style: const TextStyle(fontSize: 11)),
                      ))
                  .toList(),
              selected: {_type},
              onSelectionChanged: (v) => setState(() => _type = v.first),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'What? *',
                hintText: _type.hint,
                prefixIcon: const Icon(Icons.title),
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please describe the commitment'
                  : null,
              autofocus: !_isEditing,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Details (optional)',
                hintText: 'Any additional context...',
                prefixIcon: Icon(Icons.notes_outlined),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // Contact picker
            if (_loadingContacts)
              const LinearProgressIndicator()
            else
              DropdownButtonFormField<int>(
                key: ValueKey(_selectedContact?.id),
                initialValue: _selectedContact?.id,
              decoration: const InputDecoration(
                labelText: 'Related person (optional)',
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

            // Due date
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(_dueDate != null
                  ? dateFormat.format(_dueDate!)
                  : 'No due date'),
              subtitle: const Text('Tap to set due date'),
              trailing: _dueDate != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() {
                        _dueDate = null;
                        _conflicts = [];
                      }),
                    )
                  : null,
              onTap: _pickDueDate,
            ),
            if (_conflicts.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade700, width: 0.8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.amber.shade900, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Potential Schedule Conflict',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Overlaps with ${_conflicts.first['label']} (${DateFormat('MMM d, h:mm a').format(_conflicts.first['date'] as DateTime)})',
                            style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
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
