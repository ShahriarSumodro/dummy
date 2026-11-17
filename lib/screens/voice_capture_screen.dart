import 'dart:async';
import 'dart:io';

import '../services/capture_save_service.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/ai_extraction_result.dart';
import '../services/ai_service.dart';
import '../services/database_service.dart';
import '../services/diarization_service.dart';
import '../services/meeting_analysis_service.dart';
import '../services/voice_service.dart';
import '../theme/app_haptics.dart';
import '../theme/design_tokens.dart';
import '../widgets/widgets.dart';
import 'ai_review_screen.dart';
import 'meeting_summary_screen.dart';
import 'multi_participant_resolution_screen.dart';

enum _CaptureMode { meeting, dictation }

/// Deliberate Voice Capture & Real-time AI Voice Decoder Screen.
/// Users speak naturally, Dummy. transcribes, decodes commitments/tasks/follow-ups,
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

  // Meeting (multi-speaker) mode
  final AudioRecorder _recorder = AudioRecorder();
  final _keyController = TextEditingController();
  _CaptureMode _mode = _CaptureMode.meeting;
  bool _isTranscribing = false;
  String? _diarizationKey;
  String? _pendingAudioPath;
  DiarizedTranscript? _diarized;
  String? _selfLabel;

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
    _loadDiarizationKey();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onError: (err) {
          debugPrint('STT Error: ${err.errorMsg}');
          if (mounted && _isRecording && _mode == _CaptureMode.dictation) {
            _stopRecording();
          }
        },
        onStatus: (status) {
          debugPrint('STT Status: $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isRecording && _mode == _CaptureMode.dictation) {
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
    unawaited(WakelockPlus.disable());
    _timer?.cancel();
    _speech.stop();
    _recorder.dispose();
    _keyController.dispose();
    _transcriptController.dispose();
    super.dispose();
  }

  void _toggleRecording() {
    if (_isTranscribing) return;

    if (_isRecording) {
      if (_mode == _CaptureMode.meeting) {
        _stopMeetingRecording();
      } else {
        _stopRecording();
      }
    } else {
      if (_mode == _CaptureMode.meeting) {
        _startMeetingRecording();
      } else {
        _startRecording();
      }
    }
  }

  // ───────────────────────────────────────────────
  // MEETING MODE: record real audio -> speaker diarization
  // ───────────────────────────────────────────────

  Future<void> _loadDiarizationKey() async {
    final key = await DiarizationService.getApiKey();
    if (mounted) setState(() => _diarizationKey = key);
  }

  Future<void> _saveDiarizationKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;

    await DiarizationService.setApiKey(key);

    if (mounted) {
      AppHaptics.success();
      setState(() => _diarizationKey = key);
    }
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }

  Future<void> _startMeetingRecording() async {
    AppHaptics.mediumImpact();

    if (_diarizationKey == null || _diarizationKey!.isEmpty) {
      _showSnack(
        'Add your Gemini key first to separate speakers.',
        error: true,
      );
      return;
    }

    try {
      if (!await _recorder.hasPermission()) {
        _showSnack('Microphone permission is required.', error: true);
        return;
      }

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/meeting_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          bitRate: 32000,
          numChannels: 1,
        ),
        path: path,
      );

      if (!mounted) {
        await _recorder.stop();
        return;
      }

      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
        _diarized = null;
        _selfLabel = null;
        _pendingAudioPath = null;
        _transcriptController.clear();
      });

      try {
        await WakelockPlus.enable();
      } catch (e) {
        debugPrint('Could not enable wakelock: $e');
      }

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _recordingSeconds++);
        }
      });
    } catch (e) {
      debugPrint('Meeting recording start error: $e');
      _showSnack('Could not start recording: $e', error: true);
    }
  }

  Future<void> _stopMeetingRecording() async {
    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('Could not disable wakelock: $e');
    }

    AppHaptics.lightImpact();
    _timer?.cancel();

    String? path;

    try {
      path = await _recorder.stop();
    } catch (e) {
      debugPrint('Meeting recording stop error: $e');
    }

    if (mounted) {
      setState(() => _isRecording = false);
    }

    if (path == null) {
      _showSnack('Recording failed. Please try again.', error: true);
      return;
    }

    await _transcribeMeeting(path);
  }

  String get _languageCode => _selectedLanguage == 'English' ? 'en' : 'bn';

  Future<void> _transcribeMeeting(String path) async {
    final key = _diarizationKey;
    if (key == null || key.isEmpty) return;

    if (mounted) {
      setState(() => _isTranscribing = true);
    }

    try {
      final result = await DiarizationService.transcribe(
        file: File(path),
        apiKey: key,
        languageCode: _languageCode,
      );

      if (!mounted) return;

      setState(() {
        _diarized = result;
        _selfLabel = null;
        _pendingAudioPath = null;
        _transcriptController.text = result.toLabeledText();
      });

      AppHaptics.success();

      try {
        await File(path).delete();
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        setState(() => _pendingAudioPath = path);
        _showSnack('Speaker separation failed: $e', error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isTranscribing = false);
      }
    }
  }

  /// Transcript with the user's own speaker line renamed to "Me (the user)".
  String _selfLabeledTranscript(String text) {
    final me = _selfLabel;
    if (me == null) return text;

    return text.replaceAll(
      RegExp('^${RegExp.escape(me)}:', multiLine: true),
      'Me (the user):',
    );
  }

  /// Summarize what was actually said and find only explicitly spoken commitments.
  Future<void> _analyzeMeeting() async {
    final text = _transcriptController.text.trim();
    if (text.isEmpty) return;

    AppHaptics.mediumImpact();
    setState(() => _isProcessing = true);

    try {
      final transcript = _selfLabeledTranscript(text);
      final analysis = await MeetingAnalysisService.analyze(
        transcript: transcript,
      );

      if (!mounted) return;

      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => MeetingSummaryScreen(
            analysis: analysis,
            rawTranscript: transcript,
          ),
        ),
      );

      if (saved == true && mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showSnack('Meeting analysis failed: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Text sent to the AI: speaker-labeled transcript plus instructions.
  String _buildExtractionInput(String text) {
    final d = _diarized;
    if (d == null) return text;

    var body = text;
    final me = _selfLabel;

    if (me != null) {
      body = body.replaceAll(
        RegExp('^${RegExp.escape(me)}:', multiLine: true),
        'Me (the user):',
      );
    }

    return '''
[MEETING TRANSCRIPT — ${d.speakerCount} distinct voices were separated by speaker diarization.
Each line starts with the speaker label. "Me (the user)" is the person who owns this assistant.
"Person A", "Person B", ... are other real participants whose names are not yet known.
In "summary" write a 3-5 sentence meeting summary. Create one commitment per task and set
"contact_name" to the speaker label of whoever owns that task. Tasks the user must do are "promiseMade"
or "task"; tasks others must do are "promiseReceived". If a speaker states their real name, use it.]

$body''';
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
        // Active watchdog: if speech engine stopped, cleanly turn off recording button immediately.
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

  /// Decode voice transcript with AI and proceed to review or auto-setup.
  Future<void> _decodeAndSetup({bool autoSetup = false}) async {
    final text = _transcriptController.text.trim();

    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please speak or type a note first.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      );
      return;
    }

    AppHaptics.mediumImpact();
    setState(() => _isProcessing = true);

    final extractionText = _buildExtractionInput(text);

    try {
      final existingContacts = await _db.getAllContacts();
      final aiService = await AiServiceFactory.getService();

      AiExtractionResult result;

      try {
        result = await aiService.extract(
          text: extractionText,
          existingContacts: existingContacts,
        );
      } catch (_) {
        // Resilient fallback to local rule engine.
        final offlineService = MockAiService();

        result = await offlineService.extract(
          text: extractionText,
          existingContacts: existingContacts,
        );
      }

      if (!mounted) return;

      // If multiple unresolved participants are detected.
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

        if (resolved != true || !mounted) return;
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// 1-Tap Instant Setup: saves everything in one transaction, with Undo.
  /// Memories are saved as unverified until the user confirms them.
  Future<void> _autoSetupItems(AiExtractionResult result) async {
    try {
      final outcome = await CaptureSaveService.save(
        result,
        memoriesVerified: false,
      );

      final saved = outcome.commitments;

      final speechBuffer = StringBuffer();

      if (saved.isNotEmpty) {
        final first = saved.first;

        speechBuffer.write(
          VoiceService.formatCommitmentSpeech(
            title: first.title,
            type: first.type,
            contactName: first.contactName,
            dueDate: first.dueDate,
          ),
        );

        if (saved.length > 1) {
          speechBuffer.write(
            ' I also saved ${saved.length - 1} more from this conversation.',
          );
        }

        if (outcome.reminders.isNotEmpty) {
          speechBuffer.write(' Reminders are set.');
        }
      } else {
        speechBuffer.write('Done! I have saved your notes.');
      }

      if (mounted) {
        AppHaptics.success();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saved ${saved.length} promise(s), '
              '${outcome.reminders.length} reminder(s), '
              '${outcome.memoryIds.length} memory note(s).',
            ),
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () async {
                await outcome.undo();
              },
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        );

        Navigator.pop(context, true);
      }

      VoiceService().speak(speechBuffer.toString());
    } catch (e) {
      if (mounted) {
        AppHaptics.warning();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nothing was saved: $e'),
            backgroundColor: AppColors.error,
          ),
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
        title: const Text(
          'Voice AI Decoder & Setup',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
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
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.mic_none_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Speak naturally about your calls, follow-ups, promises, or meetings. Dummy. will decode what you owe and what others owe you.',
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

          // Capture Mode
          Text(
            'CAPTURE MODE',
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
            children: [
              for (final m in _CaptureMode.values)
                ChoiceChip(
                  label: Text(
                    m == _CaptureMode.meeting
                        ? 'Meeting (multi-speaker)'
                        : 'Quick dictation',
                  ),
                  selected: _mode == m,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: _mode == m ? FontWeight.w600 : FontWeight.w500,
                    color: _mode == m
                        ? Colors.white
                        : AppColors.foreground(context),
                  ),
                  onSelected: (_isRecording || _isTranscribing)
                      ? null
                      : (_) {
                          AppHaptics.lightImpact();
                          setState(() => _mode = m);
                        },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          if (_mode == _CaptureMode.meeting &&
              (_diarizationKey == null || _diarizationKey!.isEmpty)) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'One-time setup: speaker separation key',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.foreground(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Groq transcribes text but cannot tell voices apart. Paste a free Gemini API key '
                    '(aistudio.google.com/apikey) to label Person A, B, C... Your Groq key keeps doing the '
                    'summary and task extraction.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.muted(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: _keyController,
                    label: 'Gemini API Key (for speaker separation)',
                    hintText: 'Paste key here',
                    obscureText: true,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Save key',
                    icon: Icons.key_rounded,
                    fullWidth: true,
                    size: AppButtonSize.md,
                    onPressed: _saveDiarizationKey,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

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
                                color: AppColors.primary.withValues(
                                  alpha: 0.35,
                                ),
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
                  _isTranscribing
                      ? 'Separating speakers & transcribing...'
                      : _isRecording
                      ? (_mode == _CaptureMode.meeting
                            ? '● Recording meeting ($minutes:$seconds)'
                            : '● Listening ($minutes:$seconds)... Speak now')
                      : (_mode == _CaptureMode.meeting
                            ? 'Tap microphone to record the meeting'
                            : 'Tap microphone to speak with Dummy.'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _isRecording
                        ? AppColors.error
                        : AppColors.foreground(context),
                  ),
                ),
                if (_isRecording)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _mode == _CaptureMode.meeting
                          ? 'Tap stop when the meeting ends — speakers are separated afterwards'
                          : 'Tap stop when you are done speaking',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.muted(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          if (_isTranscribing)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: LinearProgressIndicator(),
            ),

          if (_pendingAudioPath != null && !_isTranscribing) ...[
            AppButton(
              label: 'Retry speaker separation',
              icon: Icons.refresh_rounded,
              variant: AppButtonVariant.secondary,
              fullWidth: true,
              size: AppButtonSize.md,
              onPressed: () => _transcribeMeeting(_pendingAudioPath!),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          if (_diarized != null) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_diarized!.speakerCount} speaker${_diarized!.speakerCount == 1 ? '' : 's'} detected',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.foreground(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Which one is you?',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.muted(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: _diarized!.labels.map((label) {
                      final sel = _selfLabel == label;

                      return ChoiceChip(
                        label: Text(label),
                        selected: sel,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: sel
                              ? Colors.white
                              : AppColors.foreground(context),
                        ),
                        onSelected: (_) {
                          AppHaptics.lightImpact();
                          setState(() => _selfLabel = sel ? null : label);
                        },
                      );
                    }).toList(),
                  ),

                  // Estimated vocal tone. This is not a confirmed emotional state.
                  if (_diarized!.moodByLabel.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'ESTIMATED VOCAL TONE',
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
                      children: _diarized!.moodByLabel.entries.map((entry) {
                        return Chip(
                          avatar: const Icon(
                            Icons.graphic_eq_rounded,
                            size: 16,
                          ),
                          label: Text('${entry.key}: ${entry.value}'),
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                    Text(
                      'Voice-based estimates only. These are not confirmed emotions or diagnoses.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.muted(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

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
                    _diarized = null;
                    _selfLabel = null;

                    if (['English', 'বাংলা', 'Banglish'].contains(e.key)) {
                      _selectedLanguage = e.key;
                    }
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
            hintText:
                'Your spoken words will appear here in real-time as you speak...',
            maxLines: 10,
            suffixIcon: _transcriptController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      setState(() => _transcriptController.clear());
                    },
                  )
                : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.lg),

          if (_diarized != null) ...[
            AppButton(
              label: _isProcessing
                  ? 'Analyzing meeting...'
                  : 'Summarize Meeting',
              icon: Icons.summarize_rounded,
              fullWidth: true,
              size: AppButtonSize.lg,
              loading: _isProcessing,
              onPressed:
                  (_isRecording ||
                      _isProcessing ||
                      _isTranscribing ||
                      _transcriptController.text.isEmpty)
                  ? null
                  : _analyzeMeeting,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          if (_diarized == null) ...[
            // Action 1: Instant Setup for Me (1-Tap)
            AppButton(
              label: _isProcessing
                  ? 'Analyzing & Setting Up...'
                  : 'Decode & Setup for Me (1-Tap)',
              icon: Icons.bolt_rounded,
              fullWidth: true,
              size: AppButtonSize.lg,
              loading: _isProcessing,
              onPressed:
                  (_isRecording ||
                      _isProcessing ||
                      _isTranscribing ||
                      _transcriptController.text.isEmpty)
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
              onPressed:
                  (_isRecording ||
                      _isProcessing ||
                      _isTranscribing ||
                      _transcriptController.text.isEmpty)
                  ? null
                  : () => _decodeAndSetup(autoSetup: false),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
