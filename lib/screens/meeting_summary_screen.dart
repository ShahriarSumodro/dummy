import 'package:flutter/material.dart';
import '../models/ai_extraction_result.dart';
import '../models/commitment.dart';
import '../models/meeting.dart';
import '../services/database_service.dart';
import '../services/meeting_analysis_service.dart';
import '../theme/app_haptics.dart';
import '../theme/design_tokens.dart';
import '../widgets/widgets.dart';
import 'ai_review_screen.dart';

/// Shows what was actually said: summary, key points, who talked about what,
/// and only explicitly spoken commitments. Nothing is saved until the user taps.
class MeetingSummaryScreen extends StatefulWidget {
  final MeetingAnalysis analysis;
  final String rawTranscript;

  const MeetingSummaryScreen({
    super.key,
    required this.analysis,
    required this.rawTranscript,
  });

  @override
  State<MeetingSummaryScreen> createState() => _MeetingSummaryScreenState();
}

class _MeetingSummaryScreenState extends State<MeetingSummaryScreen> {
  final _db = DatabaseService();
  bool _saving = false;
  bool _meetingSaved = false;
  bool _commitmentsSaved = false;

  String _commitmentLine(AnalysisCommitment c) =>
      '${c.owner}: ${c.task}${c.due != null ? ' (${c.due})' : ''}';

  Future<void> _saveMeeting() async {
    AppHaptics.mediumImpact();
    setState(() => _saving = true);
    try {
      final a = widget.analysis;
      await _db.insertMeeting(
        Meeting(
          title: a.title,
          meetingDate: DateTime.now(),
          rawNotes: widget.rawTranscript,
          summary: a.summary,
          decisions: a.decisions,
          actionItems: [
            ...a.userCommitments.map(_commitmentLine),
            ...a.othersCommitments.map(_commitmentLine),
          ],
          isProcessed: true,
        ),
      );
      if (!mounted) return;
      AppHaptics.success();
      setState(() => _meetingSaved = true);
      _snack('Saved to Meetings.');
    } catch (e) {
      _snack('Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reviewCommitments() async {
    final a = widget.analysis;
    final items = <ExtractedCommitment>[
      for (final c in a.userCommitments)
        ExtractedCommitment(
          title: c.task,
          description: [
            if (c.due != null) 'Said deadline: ${c.due}',
            'Said: "${c.evidence}"',
          ].join('\n'),
          type: CommitmentType.promiseMade,
          confidence: 0.85,
          sourceExcerpt: c.evidence,
        ),
      for (final c in a.othersCommitments)
        ExtractedCommitment(
          title: c.task,
          description: [
            if (c.due != null) 'Said deadline: ${c.due}',
            'Said: "${c.evidence}"',
          ].join('\n'),
          type: CommitmentType.promiseReceived,
          contactName: c.owner,
          confidence: 0.85,
          sourceExcerpt: c.evidence,
        ),
    ];

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AiReviewScreen(
          extraction: AiExtractionResult(
            rawInput: widget.rawTranscript,
            summary: a.summary,
            contacts: [],
            commitments: items,
            reminders: [],
          ),
        ),
      ),
    );
    if (saved == true && mounted) setState(() => _commitmentsSaved = true);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xs),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.muted(context),
      ),
    ),
  );

  Widget _bullets(List<String> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final s in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            '•  $s',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.foreground(context),
            ),
          ),
        ),
    ],
  );

  Widget _commitmentCard(AnalysisCommitment c) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${c.owner} — ${c.task}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground(context),
            ),
          ),
          if (c.due != null) ...[
            const SizedBox(height: 2),
            Text(
              'Deadline said: ${c.due}',
              style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '"${c.evidence}"',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppColors.muted(context),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final a = widget.analysis;
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text(
          'Meeting Summary',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            a.title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground(context),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Text(
              a.summary,
              style: TextStyle(
                fontSize: 14,
                height: 1.55,
                color: AppColors.foreground(context),
              ),
            ),
          ),
          if (a.keyPoints.isNotEmpty) ...[
            _label('KEY POINTS'),
            _bullets(a.keyPoints),
          ],
          if (a.decisions.isNotEmpty) ...[
            _label('DECISIONS'),
            _bullets(a.decisions),
          ],
          if (a.participants.isNotEmpty) ...[
            _label('WHO SAID WHAT'),
            for (final p in a.participants)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name != null
                            ? '${p.label} — ${p.name}'
                            : '${p.label} (name not mentioned)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground(context),
                        ),
                      ),
                      if (p.role != null)
                        Text(
                          p.role!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted(context),
                          ),
                        ),
                      if (p.contribution.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          p.contribution,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.foreground(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
          _label('YOUR COMMITMENTS'),
          if (a.userCommitments.isEmpty)
            Text(
              'Nothing you promised to do was said.',
              style: TextStyle(fontSize: 13, color: AppColors.muted(context)),
            )
          else
            for (final c in a.userCommitments) _commitmentCard(c),
          _label("OTHERS' COMMITMENTS"),
          if (a.othersCommitments.isEmpty)
            Text(
              'Nobody else promised anything.',
              style: TextStyle(fontSize: 13, color: AppColors.muted(context)),
            )
          else
            for (final c in a.othersCommitments) _commitmentCard(c),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: _meetingSaved ? 'Saved to Meetings' : 'Save to Meetings',
            icon: _meetingSaved
                ? Icons.check_rounded
                : Icons.bookmark_add_rounded,
            fullWidth: true,
            size: AppButtonSize.lg,
            loading: _saving,
            onPressed: (_meetingSaved || _saving) ? null : _saveMeeting,
          ),
          if (a.hasCommitments) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: _commitmentsSaved
                  ? 'Commitments saved'
                  : 'Review & save commitments',
              icon: Icons.fact_check_rounded,
              variant: AppButtonVariant.secondary,
              fullWidth: true,
              size: AppButtonSize.md,
              onPressed: _commitmentsSaved ? null : _reviewCommitments,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Done',
            variant: AppButtonVariant.subtle,
            fullWidth: true,
            size: AppButtonSize.md,
            onPressed: () =>
                Navigator.pop(context, _meetingSaved || _commitmentsSaved),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
