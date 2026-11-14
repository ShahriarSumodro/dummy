import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/action_draft_service.dart';
import '../models/commitment.dart';
import '../theme/app_haptics.dart';
import '../theme/design_tokens.dart';
import '../widgets/widgets.dart';
import 'contact_detail_screen.dart';
import 'action_draft_detail_screen.dart';

/// Relationship Health & Follow-up Radar screen.
/// Surfaces forgotten relationships and pending commitments before they go cold.
class RelationshipHealthScreen extends StatefulWidget {
  const RelationshipHealthScreen({super.key});

  @override
  State<RelationshipHealthScreen> createState() =>
      _RelationshipHealthScreenState();
}

class _RelationshipHealthScreenState extends State<RelationshipHealthScreen> {
  final _db = DatabaseService();
  List<Map<String, dynamic>> _healthData = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHealthData();
  }

  Future<void> _loadHealthData() async {
    final data = await _db.getRelationshipHealthCheck();
    if (mounted) {
      setState(() {
        _healthData = data;
        _loading = false;
      });
    }
  }

  Future<void> _generateDraftForContact(int contactId, String contactName) async {
    AppHaptics.lightImpact();
    final commitments = await _db.getCommitmentsForContact(contactId);
    final contact = await _db.getContact(contactId);
    final targetCommitment = commitments.where((c) => c.isOverdue || c.status == CommitmentStatus.pending).firstOrNull ??
        Commitment(
          title: 'Check-in & reconnect with $contactName',
          contactId: contactId,
          contactName: contactName,
          type: CommitmentType.followUp,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Preparing AI follow-up draft for $contactName...'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      );
    }

    final draftService = ActionDraftService();
    final draft = await draftService.generateDraftForCommitment(
      commitment: targetCommitment,
      contact: contact,
    );
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActionDraftDetailScreen(draft: draft),
      ),
    );
    _loadHealthData();
  }

  @override
  Widget build(BuildContext context) {
    final overdueList = _healthData.where((item) {
      final overdueCount = (item['overdue_commitments'] as num?)?.toInt() ?? 0;
      final cadenceDays = (item['cadence_days'] as num?)?.toInt() ?? 30;
      final lastCommitment = item['last_commitment_date'] as String?;
      final isCadenceOverdue = lastCommitment != null &&
          DateTime.tryParse(lastCommitment) != null &&
          DateTime.now().difference(DateTime.tryParse(lastCommitment)!).inDays >= cadenceDays;
      return overdueCount > 0 || isCadenceOverdue;
    }).toList();

    final healthyList = _healthData.where((item) => !overdueList.contains(item)).toList();

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text('Relationship Health Radar', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _healthData.isEmpty
              ? const Center(
                  child: AppEmptyState(
                    icon: Icons.radar_rounded,
                    title: 'No contacts monitored',
                    message: 'Add contacts and touchpoint cadences to start monitoring relationship health.',
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxl),
                  children: [
                    // Overview Header Banner
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.radar_rounded, color: AppColors.primary, size: 22),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'RemembrAI monitors your interactions and alerts you when client relationships risk going cold.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.foreground(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    if (overdueList.isNotEmpty) ...[
                      AppSectionHeader(
                        title: 'Needs Immediate Attention',
                        count: overdueList.length,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ...overdueList.map((item) => _buildContactHealthCard(item, isCritical: true)),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    AppSectionHeader(
                      title: 'Healthy Cadences',
                      count: healthyList.length,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ...healthyList.map((item) => _buildContactHealthCard(item, isCritical: false)),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
    );
  }

  Widget _buildContactHealthCard(Map<String, dynamic> item, {required bool isCritical}) {
    final name = item['name'] as String? ?? 'Contact';
    final company = item['company'] as String?;
    final overdueCount = (item['overdue_commitments'] as num?)?.toInt() ?? 0;
    final pendingCount = (item['pending_commitments'] as num?)?.toInt() ?? 0;
    final lastCommitment = item['last_commitment_date'] as String?;
    final cadenceDays = (item['cadence_days'] as num?)?.toInt() ?? 30;

    int? daysSinceLast;
    int? daysRemaining;
    if (lastCommitment != null) {
      final lastDate = DateTime.tryParse(lastCommitment);
      if (lastDate != null) {
        daysSinceLast = DateTime.now().difference(lastDate).inDays;
        daysRemaining = cadenceDays - daysSinceLast;
      }
    }
    final isStale = daysRemaining != null && daysRemaining <= 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: AppListRow(
        leading: AppAvatar(name: name, size: AppAvatarSize.md),
        title: name,
        subtitle: [
          if (company != null) company,
          overdueCount > 0
              ? '$overdueCount overdue promise(s)!'
              : (pendingCount > 0
                  ? '$pendingCount active promise(s)'
                  : (lastCommitment != null ? 'Active: ${lastCommitment.substring(0, 10)}' : 'No promises yet')),
        ].join(' · '),
        badge: isStale
            ? AppBadge(label: 'Cold (-${daysRemaining!.abs()}d)', variant: AppBadgeVariant.error)
            : (daysRemaining != null && daysRemaining <= 3
                ? AppBadge(label: 'Due in ${daysRemaining}d', variant: AppBadgeVariant.warning)
                : const AppBadge(label: 'Healthy', variant: AppBadgeVariant.success)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCritical || overdueCount > 0 || isStale)
              IconButton(
                icon: const Icon(Icons.drafts_outlined, size: 18, color: AppColors.primary),
                tooltip: 'Draft Follow-up',
                onPressed: () => _generateDraftForContact(item['id'] as int, name),
              ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
          ],
        ),
        onTap: () {
          AppHaptics.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ContactDetailScreen(contactId: item['id'] as int),
            ),
          );
        },
      ),
    );
  }
}
