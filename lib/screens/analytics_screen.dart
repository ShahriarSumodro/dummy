import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'commitments_screen.dart';
import 'relationship_health_screen.dart';

/// "Say-Do" Dependability Analytics Dashboard.
/// Visualizes the executive ratio of promises made versus promises kept on time.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _db = DatabaseService();
  Map<String, dynamic>? _analytics;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    final data = await _db.getSayDoAnalytics();
    if (mounted) {
      setState(() {
        _analytics = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dependability Analytics')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final data = _analytics ?? {};
    final double sayDoRatio = (data['sayDoRatio'] as num?)?.toDouble() ?? 100.0;
    final double promisesMadeSayDo =
        (data['promisesMadeSayDo'] as num?)?.toDouble() ?? 100.0;

    final int totalTracked = (data['totalTracked'] as num?)?.toInt() ?? 0;
    final int completedCount = (data['completedCount'] as num?)?.toInt() ?? 0;
    final int completedOnTime =
        (data['completedOnTimeCount'] as num?)?.toInt() ?? 0;
    final int overdueCount = (data['overdueCount'] as num?)?.toInt() ?? 0;
    final int pendingCount = (data['pendingCount'] as num?)?.toInt() ?? 0;

    final int promisesMadeTotal =
        (data['promisesMadeTotal'] as num?)?.toInt() ?? 0;
    final int promisesMadeCompleted =
        (data['promisesMadeCompleted'] as num?)?.toInt() ?? 0;
    final int promisesMadeOverdue =
        (data['promisesMadeOverdue'] as num?)?.toInt() ?? 0;

    final int promisesReceivedTotal =
        (data['promisesReceivedTotal'] as num?)?.toInt() ?? 0;
    final int promisesReceivedCompleted =
        (data['promisesReceivedCompleted'] as num?)?.toInt() ?? 0;
    final int promisesReceivedOverdue =
        (data['promisesReceivedOverdue'] as num?)?.toInt() ?? 0;

    final double avgTurnaround =
        (data['avgTurnaroundDays'] as num?)?.toDouble() ?? 0.0;

    // Rating tier
    final Color scoreColor;
    final String tierLabel;
    final String tierDescription;

    if (sayDoRatio >= 90) {
      scoreColor = Colors.green.shade700;
      tierLabel = 'Elite Dependability';
      tierDescription =
          'You consistently honor commitments on time. High trust capital.';
    } else if (sayDoRatio >= 75) {
      scoreColor = Colors.blue.shade700;
      tierLabel = 'Strong Follow-Through';
      tierDescription =
          'Solid track record with minor delivery delays on some commitments.';
    } else if (sayDoRatio >= 50) {
      scoreColor = Colors.orange.shade800;
      tierLabel = 'Needs Attention';
      tierDescription =
          'A notable portion of your commitments slipped past due dates.';
    } else {
      scoreColor = Colors.red.shade700;
      tierLabel = 'Critical Risk';
      tierDescription =
          'Multiple overdue obligations risk eroding professional credibility.';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Say-Do Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh analytics',
            onPressed: () {
              setState(() => _loading = true);
              _loadAnalytics();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Scorecard
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: scoreColor.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Say-Do Ratio',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: scoreColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tierLabel,
                              style: TextStyle(
                                color: scoreColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 72,
                            height: 72,
                            child: CircularProgressIndicator(
                              value: totalTracked == 0 ? 1.0 : sayDoRatio / 100.0,
                              strokeWidth: 8,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              color: scoreColor,
                            ),
                          ),
                          Text(
                            totalTracked == 0
                                ? '100%'
                                : '${sayDoRatio.toStringAsFixed(0)}%',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: scoreColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tierDescription,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Two-Way Accountability (Promises Made vs Received)
          Text(
            'Two-Way Accountability',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Promises I Made',
                  subtitle: 'What you owe others',
                  primaryValue: '$promisesMadeCompleted / $promisesMadeTotal',
                  score: '${promisesMadeSayDo.toStringAsFixed(0)}% kept',
                  icon: Icons.outbox_outlined,
                  iconColor: Colors.indigo,
                  accentColor: Colors.indigo.shade50,
                  overdueCount: promisesMadeOverdue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CommitmentsScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  title: 'Promises Owed to Me',
                  subtitle: 'Waiting on others',
                  primaryValue: '$promisesReceivedCompleted / $promisesReceivedTotal',
                  score: '$promisesReceivedOverdue overdue',
                  icon: Icons.move_to_inbox_outlined,
                  iconColor: Colors.teal,
                  accentColor: Colors.teal.shade50,
                  overdueCount: promisesReceivedOverdue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CommitmentsScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Execution Velocity & Breakdown
          Text(
            'Execution Velocity',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _VelocityRow(
                    icon: Icons.timer_outlined,
                    label: 'Average Turnaround',
                    value: avgTurnaround > 0
                        ? '${avgTurnaround.toStringAsFixed(1)} days'
                        : '< 1 day',
                    color: Colors.blue,
                  ),
                  const Divider(height: 24),
                  _VelocityRow(
                    icon: Icons.check_circle_outline,
                    label: 'Completed On-Time',
                    value: '$completedOnTime of $completedCount completed',
                    color: Colors.green,
                  ),
                  const Divider(height: 24),
                  _VelocityRow(
                    icon: Icons.warning_amber_rounded,
                    label: 'Currently Overdue',
                    value: '$overdueCount commitments',
                    color: overdueCount > 0 ? Colors.red : Colors.grey,
                  ),
                  const Divider(height: 24),
                  _VelocityRow(
                    icon: Icons.pending_actions_outlined,
                    label: 'Active & In-Progress',
                    value: '$pendingCount commitments',
                    color: Colors.purple,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Executive Strategy Recommendations
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Executive Action Tips',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (overdueCount > 0)
                  Text(
                    '• You have $overdueCount overdue promise(s). Use Relationship Health Radar to send polite renegotiation or follow-up notes.',
                    style: theme.textTheme.bodySmall,
                  )
                else
                  Text(
                    '• Clean pipeline! All active commitments are on track. Continue logging verbal promises to keep your Say-Do ratio pristine.',
                    style: theme.textTheme.bodySmall,
                  ),
                const SizedBox(height: 6),
                Text(
                  '• Check on $promisesReceivedTotal promises owed to you by partners and clients to prevent external bottlenecks.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RelationshipHealthScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.radar, size: 18),
                    label: const Text('Open Health Radar'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String primaryValue;
  final String score;
  final IconData icon;
  final Color iconColor;
  final Color accentColor;
  final int overdueCount;
  final VoidCallback onTap;

  const _MetricCard({
    required this.title,
    required this.subtitle,
    required this.primaryValue,
    required this.score,
    required this.icon,
    required this.iconColor,
    required this.accentColor,
    required this.overdueCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: iconColor.withValues(alpha: 0.15),
                    child: Icon(icon, color: iconColor, size: 18),
                  ),
                  if (overdueCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$overdueCount late',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                primaryValue,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                score,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VelocityRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _VelocityRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
