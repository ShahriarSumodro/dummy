import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/action_draft.dart';
import '../services/database_service.dart';
import 'action_draft_detail_screen.dart';

/// Screen listing all prepared action drafts (Email, WhatsApp, Messages).
class ActionDraftsScreen extends StatefulWidget {
  const ActionDraftsScreen({super.key});

  @override
  State<ActionDraftsScreen> createState() => _ActionDraftsScreenState();
}

class _ActionDraftsScreenState extends State<ActionDraftsScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseService();
  late TabController _tabController;
  List<ActionDraft> _drafts = [];
  bool _loading = true;

  String? _statusFilter = 'draft';

  static const _filters = [
    (label: 'Pending Review', status: 'draft'),
    (label: 'Approved', status: 'approved'),
    (label: 'Sent', status: 'sent'),
    (label: 'All', status: null),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filters.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _statusFilter = _filters[_tabController.index].status;
        _loadDrafts();
      }
    });
    _loadDrafts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDrafts() async {
    final drafts = await _db.getAllActionDrafts(statusFilter: _statusFilter);
    if (mounted) {
      setState(() {
        _drafts = drafts;
        _loading = false;
      });
    }
  }

  Future<void> _deleteDraft(ActionDraft draft) async {
    await _db.deleteActionDraft(draft.id!);
    _loadDrafts();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d · h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Action & Follow-up Drafts'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _filters.map((f) => Tab(text: f.label)).toList(),
          isScrollable: true,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _drafts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.drafts_outlined,
                          size: 70,
                          color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No drafts found',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You can generate follow-up email and message drafts directly from any commitment.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _drafts.length,
                  itemBuilder: (context, index) {
                    final draft = _drafts[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Icon(
                            draft.type == DraftType.email
                                ? Icons.email_outlined
                                : Icons.chat_bubble_outline,
                            color: theme.colorScheme.onPrimaryContainer,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          draft.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (draft.recipientName != null)
                              Text('To: ${draft.recipientName}'),
                            Text(
                              dateFormat.format(draft.createdAt),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _deleteDraft(draft),
                        ),
                        onTap: () async {
                          final updated = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ActionDraftDetailScreen(draft: draft),
                            ),
                          );
                          if (updated == true) _loadDrafts();
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
