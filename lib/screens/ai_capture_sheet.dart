import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/ai_service.dart';
import '../models/ai_extraction_result.dart';
import '../theme/app_haptics.dart';
import '../theme/design_tokens.dart';
import '../widgets/widgets.dart';
import 'ai_review_screen.dart';
import 'voice_capture_screen.dart';
import 'multi_participant_resolution_screen.dart';

/// Capture modal allowing users to enter unstructured notes or meeting transcripts
/// to extract contacts, commitments, and reminders.
class AiCaptureSheet extends StatefulWidget {
  final String? initialText;
  const AiCaptureSheet({super.key, this.initialText});

  @override
  State<AiCaptureSheet> createState() => _AiCaptureSheetState();
}

class _AiCaptureSheetState extends State<AiCaptureSheet> {
  final _textController = TextEditingController();
  final _db = DatabaseService();

  @override
  void initState() {
    super.initState();
    final t = widget.initialText;
    if (t != null && t.trim().isNotEmpty) {
      _textController.text = t;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _processMemory();
      });
    }
  }

  bool _isProcessing = false;
  String? _errorMessage;

  static const _quickPrompts = [
    'I promised Rahim I will send the quotation tomorrow by 3 PM.',
    'Met Apex Corp. They promised to send the revised draft by Friday.',
    'Follow up with Karim next Monday about the pending invoice payment.',
    'Prepare marketing presentation for ABC Ltd meeting on Thursday at 10 AM.',
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _processMemory() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _errorMessage = 'Please type or paste a note.');
      return;
    }

    AppHaptics.mediumImpact();
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final existingContacts = await _db.getAllContacts();
      final aiService = await AiServiceFactory.getService();

      AiExtractionResult result;
      try {
        result = await aiService.extract(
          text: text,
          existingContacts: existingContacts,
        );
      } catch (cloudError) {
        // Resilient fallback to local rule engine if cloud API fails
        final offlineService = MockAiService();
        result = await offlineService.extract(
          text: text,
          existingContacts: existingContacts,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Cloud AI offline. Processed via local offline memory rules.',
              ),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }

      if (!mounted) return;

      if (result.isEmpty) {
        setState(() {
          _isProcessing = false;
          _errorMessage =
              'No commitments or contacts found in this text. Try adding more specific details or dates.';
        });
        return;
      }

      // If multiple unresolved participants are detected
      if (result.hasUnresolvedParticipants) {
        final resolved = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => MultiParticipantResolutionScreen(
              extractionResult: result,
              onResolved: () {},
            ),
          ),
        );
        if (resolved != true || !mounted) return;
      }

      // Navigate to Review & Confirm screen
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => AiReviewScreen(extraction: result)),
      );

      if (saved == true && mounted) {
        Navigator.pop(context, true); // Close sheet and indicate saved
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Extraction error: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Text(
                'AI Memory Capture',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.mic_rounded, color: AppColors.primary),
                tooltip: 'Speak with Voice AI',
                onPressed: () async {
                  AppHaptics.lightImpact();
                  final saved = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VoiceCaptureScreen(),
                    ),
                  );
                  if (saved == true && mounted) {
                    Navigator.pop(context, true);
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Type a conversation note, promise, or meeting follow-up. The assistant will extract who, what, and when.',
            style: TextStyle(fontSize: 13, color: AppColors.muted(context)),
          ),
          const SizedBox(height: AppSpacing.md),

          AppTextField(
            controller: _textController,
            hintText:
                'e.g. Met with Rahim today. Promised to email the revised quotation by tomorrow 3 PM...',
            maxLines: 4,
            autofocus: true,
          ),
          const SizedBox(height: AppSpacing.sm),

          // Quick Prompt Chips
          Text(
            'EXAMPLE PROMPTS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.muted(context),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickPrompts.map((p) {
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: InkWell(
                    onTap: () {
                      AppHaptics.lightImpact();
                      _textController.text = p;
                    },
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.subtle(context),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: AppColors.border(context),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        p.length > 35 ? '${p.substring(0, 32)}...' : p,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.foreground(context),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),

          AppButton(
            label: _isProcessing ? 'Analyzing Context...' : 'Extract Memory',
            icon: Icons.auto_awesome_rounded,
            fullWidth: true,
            size: AppButtonSize.lg,
            loading: _isProcessing,
            onPressed: _isProcessing ? null : _processMemory,
          ),
        ],
      ),
    );
  }
}
