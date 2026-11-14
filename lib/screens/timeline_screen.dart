import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/interaction.dart';
import '../services/database_service.dart';
import 'contact_detail_screen.dart';

/// Activity Timeline & Interaction Audit Trail screen.
class TimelineScreen extends StatefulWidget {
  final int? contactId;
  final String? title;

  const TimelineScreen({super.key, this.contactId, this.title});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final _db = DatabaseService();
  List<Interaction> _interactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    final list = await _db.getInteractions(contactId: widget.contactId);
    if (mounted) {
      setState(() {
        _interactions = list;
        _loading = false;
      });
    }
  }

  Future<void> _logManualNote() async {
    final controller = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log Activity Note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Called client to discuss scope...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Log'),
          ),
        ],
      ),
    );

    if (res != null && res.trim().isNotEmpty) {
      final interaction = Interaction(
        type: InteractionType.note,
        title: res.trim(),
        contactId: widget.contactId,
      );
      await _db.insertInteraction(interaction);
      _loadTimeline();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, yyyy · h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Activity Timeline'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Log Note',
            onPressed: _logManualNote,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _interactions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.timeline,
                          size: 70,
                          color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No activity logged yet',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Interactions, commitments created, and meeting decisions will form your relationship timeline.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonal(
                          onPressed: _logManualNote,
                          child: const Text('+ Log an Activity Note'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _interactions.length,
                  itemBuilder: (context, index) {
                    final item = _interactions[index];
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left timeline line & icon
                          Column(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: theme.colorScheme.primaryContainer,
                                child: Icon(
                                  _getIconForType(item.type),
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              if (index < _interactions.length - 1)
                                Expanded(
                                  child: Container(
                                    width: 2,
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 14),

                          // Right content card
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: Card(
                                margin: EdgeInsets.zero,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            item.type.label,
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                              color: theme.colorScheme.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            dateFormat.format(item.timestamp),
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              fontSize: 11,
                                              color: theme.colorScheme.outline,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        item.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (item.contactName != null) ...[
                                        const SizedBox(height: 4),
                                        InkWell(
                                          onTap: () {
                                            if (item.contactId != null) {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      ContactDetailScreen(
                                                    contactId: item.contactId!,
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          child: Text(
                                            '👤 ${item.contactName}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  theme.colorScheme.secondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (item.notes != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          item.notes!,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  IconData _getIconForType(InteractionType type) {
    return switch (type) {
      InteractionType.note => Icons.notes,
      InteractionType.call => Icons.phone_in_talk,
      InteractionType.meeting => Icons.meeting_room,
      InteractionType.commitmentCreated => Icons.handshake,
      InteractionType.commitmentCompleted => Icons.check_circle,
      InteractionType.draftSent => Icons.send,
      InteractionType.reminderFired => Icons.alarm,
    };
  }
}
