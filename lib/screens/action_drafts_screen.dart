import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/action_draft.dart';
import '../services/database_service.dart';
import '../theme/app_haptics.dart';
import '../theme/design_tokens.dart';
import '../widgets/widgets.dart';
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
        AppHaptics.lightImpact();
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
    AppHaptics.warning();
    await _db.deleteActionDraft(draft.id!);
    _loadDrafts();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d · h:mm a');

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        titleSpacing: AppSpacing.md,
        title: const Text('Action & Follow-up Drafts', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.subtle(context),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicator: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(AppRadius.full),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.muted(context),
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: _filters.map((f) => Tab(text: f.label)).toList(),
            ),
          ),
        ),
      ),
      body: _loading
          ? ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: 6,
              itemBuilder: (_, __) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppSkeleton(height: 72, borderRadius: BorderRadius.circular(AppRadius.lg)),
              ),
            )
          : _drafts.isEmpty
              ? Center(
                  child: AppEmptyState(
                    icon: Icons.drafts_outlined,
                    title: 'No drafts found',
                    message: 'Generate follow-up email and message drafts with AI directly from any commitment detail view.',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 100),
                  itemCount: _drafts.length,
                  itemBuilder: (context, index) {
                    final draft = _drafts[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: AppListRow(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.subtle(context),
                          child: Icon(
                            draft.type == DraftType.email
                                ? Icons.email_outlined
                                : Icons.chat_bubble_outline_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                        title: draft.title,
                        subtitle: [
                          if (draft.recipientName != null) 'To: ${draft.recipientName}',
                          dateFormat.format(draft.createdAt),
                        ].join(' · '),
                        badge: AppBadge(
                          label: draft.status.label,
                          variant: draft.status == DraftStatus.sent
                              ? AppBadgeVariant.success
                              : (draft.status == DraftStatus.approved
                                  ? AppBadgeVariant.neutral
                                  : AppBadgeVariant.warning),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.muted(context)),
                          onPressed: () => _deleteDraft(draft),
                        ),
                        onTap: () async {
                          AppHaptics.lightImpact();
                          final updated = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ActionDraftDetailScreen(draft: draft),
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
