import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/interaction.dart';
import '../services/database_service.dart';
import '../theme/app_haptics.dart';
import '../theme/design_tokens.dart';
import '../widgets/widgets.dart';

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
    AppHaptics.lightImpact();
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
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Log'),
          ),
        ],
      ),
    );

    if (res != null && res.trim().isNotEmpty) {
      AppHaptics.success();
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
    final dateFormat = DateFormat('MMM d, yyyy · h:mm a');

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(widget.title ?? 'Activity Timeline', style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Log Note',
            onPressed: _logManualNote,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: _loading
          ? ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: 6,
              itemBuilder: (_, __) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppSkeleton(height: 64, borderRadius: BorderRadius.circular(AppRadius.lg)),
              ),
            )
          : _interactions.isEmpty
              ? Center(
                  child: AppEmptyState(
                    icon: Icons.timeline_rounded,
                    title: 'No activity logged yet',
                    message: 'Interactions, promises created, and meeting decisions will form your relationship audit trail.',
                    actionLabel: 'Log First Note',
                    onAction: _logManualNote,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 100),
                  itemCount: _interactions.length,
                  itemBuilder: (context, index) {
                    final item = _interactions[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: AppListRow(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.subtle(context),
                          child: Icon(
                            _getIcon(item.type),
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
                        title: item.title,
                        subtitle: [
                          item.type.label,
                          if (item.notes != null && item.notes!.isNotEmpty) item.notes!,
                        ].join(' · '),
                        trailing: Text(
                          dateFormat.format(item.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.muted(context),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  IconData _getIcon(InteractionType type) {
    switch (type) {
      case InteractionType.call:
        return Icons.phone_in_talk_rounded;
      case InteractionType.meeting:
        return Icons.groups_rounded;
      case InteractionType.note:
        return Icons.notes_rounded;
      case InteractionType.commitmentCreated:
        return Icons.add_task_rounded;
      case InteractionType.commitmentCompleted:
        return Icons.task_alt_rounded;
      case InteractionType.draftSent:
        return Icons.send_rounded;
      case InteractionType.reminderFired:
        return Icons.alarm_on_rounded;
    }
  }
}
