import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/contact.dart';
import '../models/commitment.dart';
import '../models/interaction.dart';
import '../services/database_service.dart';
import 'contact_form_screen.dart';
import 'commitment_form_screen.dart';
import 'commitment_detail_screen.dart';
import 'briefing_screen.dart';

/// Detail screen for a single contact.
/// Shows their info and all related commitments.
class ContactDetailScreen extends StatefulWidget {
  final int contactId;

  const ContactDetailScreen({super.key, required this.contactId});

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  final _db = DatabaseService();
  Contact? _contact;
  List<Commitment> _commitments = [];
  List<Interaction> _interactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final contact = await _db.getContact(widget.contactId);
    final commitments = await _db.getCommitmentsForContact(widget.contactId);
    final interactions = await _db.getInteractions(contactId: widget.contactId, limit: 30);
    if (mounted) {
      setState(() {
        _contact = contact;
        _commitments = commitments;
        _interactions = interactions;
        _loading = false;
      });
    }
  }

  Future<void> _logInteractionDialog() async {
    if (_contact == null) return;
    InteractionType selectedType = InteractionType.call;
    final titleController = TextEditingController();
    final notesController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Log Activity with ${_contact!.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<InteractionType>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Activity Type'),
                  items: const [
                    DropdownMenuItem(
                      value: InteractionType.call,
                      child: Text('Phone / Video Call'),
                    ),
                    DropdownMenuItem(
                      value: InteractionType.meeting,
                      child: Text('In-person Meeting'),
                    ),
                    DropdownMenuItem(
                      value: InteractionType.note,
                      child: Text('Note / Context Memo'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedType = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Summary / Title *',
                    hintText: 'e.g. Discussed Q3 roadmap & pricing',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Details / Key Points (optional)',
                    hintText: 'Any specifics to remember...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                await _db.insertInteraction(Interaction(
                  type: selectedType,
                  title: titleController.text.trim(),
                  notes: notesController.text.trim().isEmpty
                      ? null
                      : notesController.text.trim(),
                  contactId: widget.contactId,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editContact() async {
    if (_contact == null) return;
    final result = await Navigator.push<Contact>(
      context,
      MaterialPageRoute(
        builder: (context) => ContactFormScreen(contact: _contact),
      ),
    );

    if (result != null) {
      await _db.updateContact(result);
      _loadData();
    }
  }

  Future<void> _deleteContact() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text(
          'Delete "${_contact?.name}"? This will not delete their commitments, but they will be unlinked.',
        ),
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
      await _db.deleteContact(widget.contactId);
      if (mounted) {
        Navigator.pop(context, true); // true = was deleted
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_contact == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Contact not found')),
      );
    }

    final theme = Theme.of(context);
    final contact = _contact!;
    final dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(contact.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_stories_outlined),
            tooltip: 'View Executive Dossier',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BriefingScreen(initialContact: contact),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editContact,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteContact,
          ),
        ],
      ),
      body: ListView(
        children: [
          // ── Contact header ──
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    contact.initials,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  contact.name,
                  style: theme.textTheme.headlineSmall,
                ),
                if (contact.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    contact.subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Contact details ──
          if (contact.phone != null) _detailTile(Icons.phone_outlined,
              'Phone', contact.phone!),
          if (contact.email != null) _detailTile(Icons.email_outlined,
              'Email', contact.email!),
          if (contact.company != null) _detailTile(Icons.business_outlined,
              'Company', contact.company!),
          if (contact.role != null) _detailTile(Icons.badge_outlined,
              'Role', contact.role!),
          if (contact.notes != null) _detailTile(Icons.notes_outlined,
              'Notes', contact.notes!),

          _detailTile(Icons.calendar_today_outlined, 'Added',
              dateFormat.format(contact.createdAt)),

          const Divider(height: 32),

          // ── Commitments for this contact ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Commitments',
                  style: theme.textTheme.titleMedium,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                  onPressed: () async {
                    final res = await Navigator.push<Commitment>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CommitmentFormScreen(
                          preselectedContact: _contact,
                        ),
                      ),
                    );
                    if (res != null) {
                      await _db.insertCommitment(res);
                      _loadData();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          if (_commitments.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No commitments linked to this contact yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ..._commitments.map((c) => ListTile(
                  leading: Icon(
                    c.status == CommitmentStatus.completed
                        ? Icons.check_circle_outline
                        : Icons.pending_outlined,
                    color: c.isOverdue
                        ? theme.colorScheme.error
                        : (c.status == CommitmentStatus.completed
                            ? Colors.green
                            : null),
                  ),
                  title: Text(c.title),
                  subtitle: Text(c.type.label),
                  trailing: c.dueDate != null
                      ? Text(
                          dateFormat.format(c.dueDate!),
                          style: TextStyle(
                            color: c.isOverdue
                                ? theme.colorScheme.error
                                : null,
                          ),
                        )
                      : null,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CommitmentDetailScreen(
                          commitmentId: c.id!,
                        ),
                      ),
                    );
                    _loadData();
                  },
                )),

          const Divider(height: 32),

          // ── Activity & Interactions Timeline ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Activity & Timeline',
                  style: theme.textTheme.titleMedium,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add_comment_outlined, size: 18),
                  label: const Text('Log Activity'),
                  onPressed: _logInteractionDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          if (_interactions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No activity logged with ${_contact!.name} yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ..._interactions.map((i) => ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      _getInteractionIcon(i.type),
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  title: Text(i.title, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    [
                      i.type.label,
                      if (i.notes != null && i.notes!.isNotEmpty) i.notes!,
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    DateFormat('MMM d, h:mm a').format(i.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                )),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  IconData _getInteractionIcon(InteractionType type) {
    switch (type) {
      case InteractionType.call:
        return Icons.phone_in_talk_outlined;
      case InteractionType.meeting:
        return Icons.groups_outlined;
      case InteractionType.note:
        return Icons.notes_outlined;
      case InteractionType.commitmentCreated:
        return Icons.add_task;
      case InteractionType.commitmentCompleted:
        return Icons.task_alt;
      case InteractionType.draftSent:
        return Icons.send_outlined;
      case InteractionType.reminderFired:
        return Icons.alarm_on_outlined;
    }
  }

  Widget _detailTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
    );
  }
}
