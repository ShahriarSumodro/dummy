import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/action_draft_service.dart';
import '../models/commitment.dart';
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
        SnackBar(content: Text('Preparing AI follow-up for $contactName...')),
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
    final theme = Theme.of(context);

    final overdueList = _healthData.where((item) {
      final overdueCount =
          (item['overdue_commitments'] as num?)?.toInt() ?? 0;
      final cadenceDays = (item['cadence_days'] as num?)?.toInt() ?? 30;
      final lastCommitment = item['last_commitment_date'] as String?;
      final isCadenceOverdue = lastCommitment != null &&
          DateTime.tryParse(lastCommitment) != null &&
          DateTime.now()
                  .difference(DateTime.tryParse(lastCommitment)!)
                  .inDays >=
              cadenceDays;
      return overdueCount > 0 || isCadenceOverdue;
    }).toList();

    final healthyList =
        _healthData.where((item) => !overdueList.contains(item)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relationship Health Radar'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _healthData.isEmpty
              ? const Center(child: Text('No contacts to evaluate.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Overview header banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.radar, color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'RemembrAI monitors your interactions and alerts you when client relationships risk going cold.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (overdueList.isNotEmpty) ...[
                      Text(
                        'Needs Immediate Attention (${overdueList.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...overdueList.map((item) => _buildContactHealthTile(
                            item,
                            theme,
                            isCritical: true,
                          )),
                      const SizedBox(height: 24),
                    ],

                    Text(
                      'All Monitored Contacts (${healthyList.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...healthyList.map((item) => _buildContactHealthTile(
                          item,
                          theme,
                          isCritical: false,
                        )),
                    const SizedBox(height: 40),
                  ],
                ),
    );
  }

  Widget _buildContactHealthTile(
    Map<String, dynamic> item,
    ThemeData theme, {
    required bool isCritical,
  }) {
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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (isCritical || isStale)
              ? theme.colorScheme.errorContainer
              : theme.colorScheme.primaryContainer,
          child: Icon(
            (isCritical || isStale)
                ? Icons.warning_amber
                : Icons.person_outline,
            color: (isCritical || isStale)
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (company != null) Text(company),
            const SizedBox(height: 2),
            Text(
              overdueCount > 0
                  ? '$overdueCount overdue promise(s)!'
                  : (pendingCount > 0
                      ? '$pendingCount active commitment(s)'
                      : (lastCommitment != null
                          ? 'Last active: ${lastCommitment.substring(0, 10)}'
                          : 'No recorded commitments yet')),
              style: TextStyle(
                fontSize: 12,
                color: overdueCount > 0 ? theme.colorScheme.error : null,
                fontWeight: overdueCount > 0 ? FontWeight.bold : null,
              ),
            ),
            const SizedBox(height: 4),
            // Cadence Countdown Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isStale
                    ? Colors.red.withValues(alpha: 0.12)
                    : (daysRemaining != null && daysRemaining <= 3)
                        ? Colors.orange.withValues(alpha: 0.15)
                        : Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                daysRemaining == null
                    ? 'Target Cadence: ${cadenceDays}d'
                    : isStale
                        ? 'Cold: Overdue by ${daysRemaining.abs()}d (Cadence ${cadenceDays}d)'
                        : (daysRemaining <= 3
                            ? 'Touchpoint due in ${daysRemaining}d'
                            : '$daysRemaining days until touchpoint (${cadenceDays}d cadence)'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isStale
                      ? Colors.red.shade900
                      : (daysRemaining != null && daysRemaining <= 3)
                          ? Colors.orange.shade900
                          : Colors.green.shade900,
                ),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCritical || overdueCount > 0 || isStale)
              IconButton(
                icon: const Icon(Icons.drafts_outlined, size: 20),
                tooltip: 'Draft Follow-up Message',
                onPressed: () => _generateDraftForContact(item['id'] as int, name),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () {
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
