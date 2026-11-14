import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../theme/app_haptics.dart';
import '../theme/design_tokens.dart';
import '../widgets/widgets.dart';
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
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(title: const Text('Dependability Analytics')),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: const [
            AppSkeleton(height: 160),
            SizedBox(height: AppSpacing.md),
            AppSkeleton(height: 120),
            SizedBox(height: AppSpacing.md),
            AppSkeleton(height: 120),
          ],
        ),
      );
    }

    final data = _analytics ?? {};
    final double sayDoRatio = (data['sayDoRatio'] as num?)?.toDouble() ?? 100.0;
    final double promisesMadeSayDo = (data['promisesMadeSayDo'] as num?)?.toDouble() ?? 100.0;

    final int totalTracked = (data['totalTracked'] as num?)?.toInt() ?? 0;
    final int completedCount = (data['completedCount'] as num?)?.toInt() ?? 0;
    final int completedOnTime = (data['completedOnTimeCount'] as num?)?.toInt() ?? 0;
    final int overdueCount = (data['overdueCount'] as num?)?.toInt() ?? 0;
    final int pendingCount = (data['pendingCount'] as num?)?.toInt() ?? 0;

    final int promisesMadeTotal = (data['promisesMadeTotal'] as num?)?.toInt() ?? 0;
    final int promisesMadeCompleted = (data['promisesMadeCompleted'] as num?)?.toInt() ?? 0;
    final int promisesMadeOverdue = (data['promisesMadeOverdue'] as num?)?.toInt() ?? 0;

    final int promisesReceivedTotal = (data['promisesReceivedTotal'] as num?)?.toInt() ?? 0;
    final int promisesReceivedCompleted = (data['promisesReceivedCompleted'] as num?)?.toInt() ?? 0;
    final int promisesReceivedOverdue = (data['promisesReceivedOverdue'] as num?)?.toInt() ?? 0;

    final double avgTurnaround = (data['avgTurnaroundDays'] as num?)?.toDouble() ?? 0.0;

    // Rating tier
    final Color scoreColor;
    final String tierLabel;
    final String tierDescription;

    if (sayDoRatio >= 90) {
      scoreColor = AppColors.success;
      tierLabel = 'Elite Dependability';
      tierDescription = 'You consistently honor commitments on time. High trust capital.';
    } else if (sayDoRatio >= 75) {
      scoreColor = AppColors.primary;
      tierLabel = 'Strong Follow-Through';
      tierDescription = 'Solid track record with minor delivery delays on some commitments.';
    } else if (sayDoRatio >= 50) {
      scoreColor = AppColors.warning;
      tierLabel = 'Needs Attention';
      tierDescription = 'A notable portion of your commitments slipped past due dates.';
    } else {
      scoreColor = AppColors.error;
      tierLabel = 'Critical Risk';
      tierDescription = 'Multiple overdue obligations risk eroding professional credibility.';
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text('Dependability Analytics', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxl),
        children: [
          // ── Main Say-Do Ratio Hero Card ──
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Text(
                  'OVERALL "SAY-DO" RATIO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.muted(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${sayDoRatio.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                    color: scoreColor,
                  ),
                ),
                const SizedBox(height: 4),
                AppBadge(
                  label: tierLabel,
                  variant: sayDoRatio >= 75 ? AppBadgeVariant.success : AppBadgeVariant.warning,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  tierDescription,
                  style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── 4-Metric Grid ──
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'TRACKED',
                  value: '$totalTracked',
                  subtitle: '$completedCount done',
                  icon: Icons.assignment_outlined,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _buildMetricTile(
                  title: 'ON TIME',
                  value: '$completedOnTime',
                  subtitle: 'Kept on schedule',
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _buildMetricTile(
                  title: 'OVERDUE',
                  value: '$overdueCount',
                  subtitle: '$pendingCount pending',
                  icon: Icons.warning_amber_rounded,
                  color: overdueCount > 0 ? AppColors.error : AppColors.muted(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Promises Made vs Received Breakdown ──
          AppSectionHeader(title: 'Commitment Directions'),
          const SizedBox(height: AppSpacing.xs),

          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                _buildDirectionRow(
                  label: 'Promises Made by Me',
                  score: '${promisesMadeSayDo.toStringAsFixed(0)}%',
                  details: '$promisesMadeCompleted completed of $promisesMadeTotal ($promisesMadeOverdue overdue)',
                  icon: Icons.outgoing_mail,
                ),
                const Divider(height: AppSpacing.lg),
                _buildDirectionRow(
                  label: 'Promises Expected from Others',
                  score: '$promisesReceivedCompleted / $promisesReceivedTotal',
                  details: '$promisesReceivedOverdue overdue deliverables from contacts',
                  icon: Icons.mark_email_read_outlined,
                ),
                const Divider(height: AppSpacing.lg),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 18, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.xs),
                    const Text('Average Turnaround:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(
                      '${avgTurnaround.toStringAsFixed(1)} days',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Quick Action Navigation
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'View Overdue Items',
                  icon: Icons.warning_amber_rounded,
                  variant: AppButtonVariant.tonal,
                  onPressed: () {
                    AppHaptics.lightImpact();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CommitmentsScreen()));
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: 'Health Radar',
                  icon: Icons.radar_rounded,
                  variant: AppButtonVariant.secondary,
                  onPressed: () {
                    AppHaptics.lightImpact();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RelationshipHealthScreen()));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    Color? color,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color ?? AppColors.muted(context)),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.muted(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color ?? AppColors.foreground(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: AppColors.muted(context)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionRow({
    required String label,
    required String score,
    required String details,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 2),
              Text(details, style: TextStyle(fontSize: 11, color: AppColors.muted(context))),
            ],
          ),
        ),
        Text(
          score,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ],
    );
  }
}
