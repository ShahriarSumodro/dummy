import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/ai_service.dart';
import '../models/ai_extraction_result.dart';
import 'ai_review_screen.dart';
import 'voice_capture_screen.dart';
import 'multi_participant_resolution_screen.dart';

/// Capture modal allowing users to enter unstructured notes or meeting transcripts
/// to extract contacts, commitments, and reminders.
class AiCaptureSheet extends StatefulWidget {
  const AiCaptureSheet({super.key});

  @override
  State<AiCaptureSheet> createState() => _AiCaptureSheetState();
}

class _AiCaptureSheetState extends State<AiCaptureSheet> {
  final _textController = TextEditingController();
  final _db = DatabaseService();

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
            const SnackBar(
              content: Text(
                'Cloud AI unavailable. Processed via local offline memory rules.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
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
        if (resolved != true && !mounted) return;
      }

      // Navigate to Review & Confirm screen
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => AiReviewScreen(extraction: result),
        ),
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
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'AI Memory Capture',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.mic),
                tooltip: 'Speak with Voice AI',
                onPressed: () async {
                  final saved = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const VoiceCaptureScreen()),
                  );
                  if (saved == true && mounted) {
                    Navigator.pop(context, true);
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Type a conversation note, promise, or meeting follow-up. The assistant will extract who, what, and when.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _textController,
            maxLines: 4,
            autofocus: true,
            decoration: InputDecoration(
              hintText:
                  'e.g. Met with Rahim today. Promised to email the revised quotation by tomorrow 3 PM...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Quick Prompt Chips
          Text(
            'Example prompts to try:',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickPrompts.map((p) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(
                      p.length > 35 ? '${p.substring(0, 32)}...' : p,
                      style: const TextStyle(fontSize: 11),
                    ),
                    onPressed: () {
                      _textController.text = p;
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  color: theme.colorScheme.onErrorContainer,
                  fontSize: 12,
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          FilledButton.icon(
            onPressed: _isProcessing ? null : _processMemory,
            icon: _isProcessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(_isProcessing ? 'Analyzing Context...' : 'Extract Memory'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }
}
