import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/commitment.dart';
import '../models/action_draft.dart';
import '../services/database_service.dart';
import '../services/action_draft_service.dart';
import 'commitment_form_screen.dart';
import 'action_draft_detail_screen.dart';

/// Detail screen for a single commitment.
class CommitmentDetailScreen extends StatefulWidget {
  final int commitmentId;

  const CommitmentDetailScreen({super.key, required this.commitmentId});

  @override
  State<CommitmentDetailScreen> createState() => _CommitmentDetailScreenState();
}

class _CommitmentDetailScreenState extends State<CommitmentDetailScreen> {
  final _db = DatabaseService();
  Commitment? _commitment;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final all = await _db.getAllCommitments();
    final match = all.cast<Commitment?>().firstWhere(
          (c) => c!.id == widget.commitmentId,
          orElse: () => null,
        );
    if (mounted) {
      setState(() {
        _commitment = match;
        _loading = false;
      });
    }
  }

  Future<void> _edit() async {
    if (_commitment == null) return;
    final result = await Navigator.push<Commitment>(
      context,
      MaterialPageRoute(
        builder: (_) => CommitmentFormScreen(commitment: _commitment),
      ),
    );
    if (result != null) {
      await _db.updateCommitment(result);
      _loadData();
    }
  }

  Future<void> _toggleComplete() async {
    if (_commitment == null) return;
    final isCompleting = _commitment!.status != CommitmentStatus.completed;
    final updated = _commitment!.copyWith(
      status: isCompleting
          ? CommitmentStatus.completed
          : CommitmentStatus.pending,
      completedAt: isCompleting ? DateTime.now() : null,
    );
    await _db.updateCommitment(updated);
    _loadData();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Commitment'),
        content: Text('Delete "${_commitment?.title}"?'),
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
      await _db.deleteCommitment(widget.commitmentId);
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _prepareFollowUpDraft() async {
    if (_commitment == null) return;
    final draftService = ActionDraftService();

    final draftType = await showModalBottomSheet<DraftType>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(
              title: Text('Select Draft Format', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email Draft'),
              onTap: () => Navigator.pop(ctx, DraftType.email),
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('WhatsApp / SMS Message'),
              onTap: () => Navigator.pop(ctx, DraftType.whatsapp),
            ),
          ],
        ),
      ),
    );

    if (draftType == null || !mounted) return;

    final contact = _commitment!.contactId != null
        ? await _db.getContact(_commitment!.contactId!)
        : null;

    final draft = await draftService.generateDraftForCommitment(
      commitment: _commitment!,
      contact: contact,
      type: draftType,
    );

    final id = await _db.insertActionDraft(draft);
    final savedDraft = draft.copyWith(id: id);

    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActionDraftDetailScreen(draft: savedDraft),
        ),
      );
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
    if (_commitment == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Commitment not found')),
      );
    }

    final theme = Theme.of(context);
    final c = _commitment!;
    final dateFormat = DateFormat('EEE, MMM d, yyyy · h:mm a');
    final isComplete = c.status == CommitmentStatus.completed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Commitment'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _edit),
          IconButton(
              icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status chip + type
          Row(
            children: [
              _StatusChip(status: c.isOverdue && !isComplete
                  ? CommitmentStatus.overdue
                  : c.status),
              const SizedBox(width: 8),
              Chip(label: Text(c.type.label)),
            ],
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            c.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              decoration:
                  isComplete ? TextDecoration.lineThrough : null,
            ),
          ),

          if (c.description != null && c.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(c.description!, style: theme.textTheme.bodyLarge),
          ],

          const Divider(height: 32),

          if (c.contactName != null)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Person'),
              subtitle: Text(c.contactName!),
            ),

          if (c.dueDate != null)
            ListTile(
              leading: Icon(
                Icons.calendar_today_outlined,
                color: c.isOverdue ? theme.colorScheme.error : null,
              ),
              title: const Text('Due date'),
              subtitle: Text(
                dateFormat.format(c.dueDate!),
                style: TextStyle(
                  color: c.isOverdue ? theme.colorScheme.error : null,
                ),
              ),
            ),

          if (c.completedAt != null)
            ListTile(
              leading: const Icon(Icons.check_circle_outline,
                  color: Colors.green),
              title: const Text('Completed'),
              subtitle: Text(dateFormat.format(c.completedAt!)),
            ),

          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('Created'),
            subtitle: Text(dateFormat.format(c.createdAt)),
          ),

          const SizedBox(height: 24),

          // Action button
          FilledButton.icon(
            onPressed: _toggleComplete,
            icon: Icon(isComplete ? Icons.undo : Icons.check),
            label: Text(isComplete ? 'Mark as Pending' : 'Mark as Complete'),
            style: FilledButton.styleFrom(
              backgroundColor: isComplete ? null : Colors.green,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _prepareFollowUpDraft,
            icon: const Icon(Icons.edit_note),
            label: const Text('Prepare Follow-Up Draft (AI)'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final CommitmentStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      CommitmentStatus.pending => (Colors.orange, Icons.pending_outlined),
      CommitmentStatus.completed => (Colors.green, Icons.check_circle_outline),
      CommitmentStatus.overdue => (Colors.red, Icons.warning_amber_rounded),
      CommitmentStatus.cancelled => (Colors.grey, Icons.cancel_outlined),
    };
    return Chip(
      avatar: Icon(icon, color: color, size: 18),
      label: Text(status.label, style: TextStyle(color: color)),
      side: BorderSide(color: color.withValues(alpha: 0.5)),
    );
  }
}
