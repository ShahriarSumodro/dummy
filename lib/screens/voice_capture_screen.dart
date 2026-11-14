import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/database_service.dart';
import '../services/ai_service.dart';
import '../services/voice_service.dart';
import '../models/ai_extraction_result.dart';
import '../models/commitment.dart';
import '../models/reminder.dart';
import '../theme/app_haptics.dart';
import '../theme/design_tokens.dart';
import '../widgets/widgets.dart';
import 'ai_review_screen.dart';
import 'multi_participant_resolution_screen.dart';

/// Deliberate Voice Capture & Real-time AI Voice Decoder Screen.
/// Users speak naturally, RemembrAI transcribes, decodes commitments/tasks/follow-ups,
/// and automatically sets them up into SQLite with scheduled push notifications and voice feedback.
class VoiceCaptureScreen extends StatefulWidget {
  const VoiceCaptureScreen({super.key});

  @override
  State<VoiceCaptureScreen> createState() => _VoiceCaptureScreenState();
}

class _VoiceCaptureScreenState extends State<VoiceCaptureScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseService();
  final _transcriptController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _speechEnabled = false;
  bool _isRecording = false;
  bool _isProcessing = false;
  int _recordingSeconds = 0;
  Timer? _timer;

  String _selectedLanguage = 'English'; // English, বাংলা, Banglish

  static const _sampleVoiceTranscripts = {
    'Single Meeting':
        'I have a meeting at 10:30 with Raju, and I promised him to deliver the proposal by tomorrow.',
    'Casual Convo Filter':
        "What's up? Yeah, man, it's all good. Hello, do you have a class tomorrow? Yeah, maybe, I'm not sure. Okay, so let's see, call our teacher to get ready of our class. Okay, it's all good.",
    '5-Person Meeting':
        'Had a discussion with 5 people. Person D said he will send the revised design by tomorrow. Person B will do nothing, and the other one said nothing. and I promised to do the work for person D, and no one else.',
    'English Promise':
        'I had a phone conversation with Rahim Ahmed from Apex Corp. I promised him that I will deliver the revised commercial proposal by tomorrow at 4 PM.',
    'বাংলা':
        'রহিম আহমেদের সাথে কথা হলো। আমি কথা দিয়েছি আগামী পরশু দুপুর ৩টায় প্রজেক্টের কোটেশন পাঠাবো।',
    'Banglish':
        'Karim bhai er shathe kotha hoise. He said he would send the contract document by Friday morning.',
  };

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onError: (err) {
          debugPrint('STT Error: ${err.errorMsg}');
          if (mounted && _isRecording) {
            _stopRecording();
          }
        },
        onStatus: (status) {
          debugPrint('STT Status: $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isRecording) {
              _stopRecording();
            }
          }
        },
      );
      if (mounted) {
        setState(() => _speechEnabled = available);
      }
    } catch (e) {
      debugPrint('Speech-to-text initialization exception: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _speech.stop();
    _transcriptController.dispose();
    super.dispose();
  }

  void _toggleRecording() {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  Future<void> _startRecording() async {
    AppHaptics.mediumImpact();
    if (!_speechEnabled) {
      await _initSpeech();
    }

    String locale = 'en_US';
    if (_selectedLanguage == 'বাংলা') {
      locale = 'bn_BD';
    } else if (_selectedLanguage == 'Banglish') {
      locale = 'en_IN';
    }

    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
      _transcriptController.clear();
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        // Active watchdog: if speech engine stopped, cleanly turn off recording button immediately
        if (!_speech.isListening && _recordingSeconds >= 2) {
          _stopRecording();
          return;
        }
        setState(() => _recordingSeconds++);
      }
    });

    try {
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _transcriptController.text = result.recognizedWords;
            });
          }
        },
        localeId: locale,
        listenMode: stt.ListenMode.dictation,
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 4),
        cancelOnError: false,
        partialResults: true,
      );
    } catch (e) {
      debugPrint('Error starting speech listening: $e');
      _stopRecording();
    }
  }

  Future<void> _stopRecording() async {
    AppHaptics.lightImpact();
    _timer?.cancel();
    try {
      await _speech.stop();
    } catch (_) {}
    if (mounted) {
      setState(() => _isRecording = false);
    }
  }

  /// Decode voice transcript with AI and proceed to review or auto-setup
  Future<void> _decodeAndSetup({bool autoSetup = false}) async {
    final text = _transcriptController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please speak or type a note first.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      );
      return;
    }

    AppHaptics.mediumImpact();
    setState(() => _isProcessing = true);

    try {
      final existingContacts = await _db.getAllContacts();
      final aiService = await AiServiceFactory.getService();

      AiExtractionResult result;
      try {
        result = await aiService.extract(
          text: text,
          existingContacts: existingContacts,
        );
      } catch (_) {
        // Resilient fallback to local rule engine
        final offlineService = MockAiService();
        result = await offlineService.extract(
          text: text,
          existingContacts: existingContacts,
        );
      }

      if (!mounted) return;

      // If multiple unresolved participants are detected
      if (result.hasUnresolvedParticipants) {
        final resolved = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => MultiParticipantResolutionScreen(
              extractionResult: result,
              onResolved: () {
                if (mounted) setState(() {});
              },
            ),
          ),
        );
        if (resolved != true && !mounted) return;
      }

      if (autoSetup) {
        await _autoSetupItems(result);
      } else {
        final saved = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => AiReviewScreen(extraction: result)),
        );

        if (saved == true && mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Decoding failed: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// 1-Tap Instant Setup: directly commits decoded items to SQLite and speaks confirmation
  Future<void> _autoSetupItems(AiExtractionResult result) async {
    try {
      final contactIdMap = <String, int>{};
      for (final ec in result.contacts) {
        if (ec.matchedExistingContactId != null) {
          contactIdMap[ec.name.toLowerCase()] = ec.matchedExistingContactId!;
        } else {
          final newContact = ec.toContact();
          final id = await _db.insertContact(newContact);
          contactIdMap[ec.name.toLowerCase()] = id;
        }
      }

      final savedCommitments = <Commitment>[];
      for (final ec in result.commitments) {
        int? linkedContactId = ec.matchedContactId;
        if (linkedContactId == null && ec.contactName != null) {
          linkedContactId = contactIdMap[ec.contactName!.toLowerCase()];
        }

        final commitment = Commitment(
          title: ec.title,
          description: ec.description,
          type: ec.type,
          dueDate: ec.dueDate,
          contactId: linkedContactId,
          status: CommitmentStatus.pending,
        );

        final id = await _db.insertCommitment(commitment);
        savedCommitments.add(commitment.copyWith(id: id));
      }

      for (final er in result.reminders) {
        final reminder = Reminder(
          title: er.title,
          remindAt: er.remindAt,
          isRecurring: er.isRecurring,
          recurringRule: er.recurringRule,
          commitmentId: savedCommitments.isNotEmpty ? savedCommitments.first.id : null,
          status: ReminderStatus.pending,
        );
        await _db.insertReminder(reminder);
      }

      // Voice speech confirmation back to user using assistant executive phrasing
      final speechBuffer = StringBuffer();
      if (savedCommitments.isNotEmpty) {
        final first = savedCommitments.first;
        final naturalPhrasing = VoiceService.formatCommitmentSpeech(
          title: first.title,
          type: first.type,
          contactName: first.contactName,
          dueDate: first.dueDate,
        );
        speechBuffer.write(naturalPhrasing);

        if (savedCommitments.length > 1) {
          speechBuffer.write(
            ' I also scheduled ${savedCommitments.length - 1} additional commitment${savedCommitments.length > 2 ? 's' : ''} from this conversation.',
          );
        }
        speechBuffer.write(' Notification reminders are set.');
      } else {
        speechBuffer.write('Done! I have decoded and saved your notes.');
      }

      await VoiceService().speak(speechBuffer.toString());

      if (mounted) {
        AppHaptics.success();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully set up ${savedCommitments.length} promise(s) & ${result.contacts.length} contact(s)!',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppHaptics.warning();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Auto-setup error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordingSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text('Voice AI Decoder & Setup', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Privacy Banner
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.mic_none_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Speak naturally about your calls, follow-ups, promises, or meetings. RemembrAI will decode what you owe and what others owe you.',
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

          // Language Selector
          Text(
            'SPOKEN LANGUAGE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.muted(context),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: ['English', 'বাংলা', 'Banglish'].map((lang) {
              final isSel = _selectedLanguage == lang;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: ChoiceChip(
                  label: Text(lang),
                  selected: isSel,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                    color: isSel ? Colors.white : AppColors.foreground(context),
                  ),
                  onSelected: (_) {
                    AppHaptics.lightImpact();
                    setState(() => _selectedLanguage = lang);
                  },
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Microphone Center
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _toggleRecording,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isRecording ? AppColors.error : AppColors.primary,
                      boxShadow: _isRecording
                          ? [
                              BoxShadow(
                                color: AppColors.error.withValues(alpha: 0.45),
                                blurRadius: 28,
                                spreadRadius: 8,
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                      size: 42,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _isRecording
                      ? '● Listening ($minutes:$seconds)... Speak now'
                      : 'Tap microphone to speak with RemembrAI',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _isRecording ? AppColors.error : AppColors.foreground(context),
                  ),
                ),
                if (_isRecording)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Tap stop when you are done speaking',
                      style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Quick Preset Prompts
          Text(
            'TEST WITH SAMPLE CONVERSATION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.muted(context),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: _sampleVoiceTranscripts.entries.map((e) {
              return ActionChip(
                label: Text(e.key, style: const TextStyle(fontSize: 11)),
                onPressed: () {
                  AppHaptics.lightImpact();
                  setState(() {
                    _transcriptController.text = e.value;
                    _selectedLanguage = e.key;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.md),

          // Live Transcript Box
          AppTextField(
            controller: _transcriptController,
            label: 'Live Voice Transcript',
            hintText: 'Your spoken words will appear here in real-time as you speak...',
            maxLines: 4,
            suffixIcon: _transcriptController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () => setState(() => _transcriptController.clear()),
                  )
                : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Action 1: Instant Setup for Me (1-Tap)
          AppButton(
            label: _isProcessing ? 'Analyzing & Setting Up...' : 'Decode & Setup for Me (1-Tap)',
            icon: Icons.bolt_rounded,
            fullWidth: true,
            size: AppButtonSize.lg,
            loading: _isProcessing,
            onPressed: (_isRecording || _isProcessing || _transcriptController.text.isEmpty)
                ? null
                : () => _decodeAndSetup(autoSetup: true),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Action 2: Review & Edit Details
          AppButton(
            label: 'Review & Fine-Tune Details First',
            icon: Icons.tune_rounded,
            variant: AppButtonVariant.secondary,
            fullWidth: true,
            size: AppButtonSize.md,
            onPressed: (_isRecording || _isProcessing || _transcriptController.text.isEmpty)
                ? null
                : () => _decodeAndSetup(autoSetup: false),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
