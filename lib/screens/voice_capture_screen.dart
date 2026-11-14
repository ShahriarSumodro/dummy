import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/database_service.dart';
import '../services/ai_service.dart';
import '../services/voice_service.dart';
import '../services/notification_service.dart';
import '../models/ai_extraction_result.dart';
import '../models/commitment.dart';
import '../models/reminder.dart';
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
        // Active watchdog: if Android OS speech recognizer stopped on silence timeout, sync recording UI immediately
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
        const SnackBar(content: Text('Please speak or type a note first.')),
      );
      return;
    }

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

      // If multiple unresolved participants are detected (e.g. Person A, Person B in a 3-4 person discussion)
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
          SnackBar(content: Text('Decoding failed: $e')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully set up ${savedCommitments.length} commitment(s) & ${result.contacts.length} contact(s)!',
            ),
            backgroundColor: Colors.green.shade800,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Auto-setup error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minutes = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordingSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(title: const Text('Voice AI Decoder & Setup')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Privacy banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.mic_none, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Speak naturally about your calls, follow-ups, promises, or meetings. RemembrAI will decode what you owe and what others owe you.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Language Selector
          Text('Spoken Language:', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'English', label: Text('English')),
              ButtonSegment(value: 'বাংলা', label: Text('বাংলা')),
              ButtonSegment(value: 'Banglish', label: Text('Banglish')),
            ],
            selected: {_selectedLanguage},
            onSelectionChanged: (val) {
              setState(() => _selectedLanguage = val.first);
            },
          ),
          const SizedBox(height: 28),

          // Microphone Center
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _toggleRecording,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isRecording
                          ? Colors.red
                          : theme.colorScheme.primaryContainer,
                      boxShadow: _isRecording
                          ? [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.5),
                                blurRadius: 28,
                                spreadRadius: 10,
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      size: 44,
                      color: _isRecording
                          ? Colors.white
                          : theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isRecording
                      ? '● Listening ($minutes:$seconds)... Speak now'
                      : 'Tap microphone to speak with RemembrAI',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: _isRecording ? Colors.red : null,
                  ),
                ),
                if (_isRecording)
                  Text(
                    'Tap stop when you are done speaking',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.red.shade400),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Quick Preset Prompts
          Text('Or test with sample note:', style: theme.textTheme.labelSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _sampleVoiceTranscripts.entries.map((e) {
              return ActionChip(
                visualDensity: VisualDensity.compact,
                label: Text(e.key, style: const TextStyle(fontSize: 11)),
                onPressed: () {
                  setState(() {
                    _transcriptController.text = e.value;
                    _selectedLanguage = e.key;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Live Transcript Box
          TextField(
            controller: _transcriptController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Live Voice Transcript',
              hintText: 'Your spoken words will appear here in real-time as you talk...',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: _transcriptController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _transcriptController.clear()),
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),

          // Action 1: Instant Setup for Me (1-Tap)
          FilledButton.icon(
            onPressed: (_isRecording || _isProcessing || _transcriptController.text.isEmpty)
                ? null
                : () => _decodeAndSetup(autoSetup: true),
            icon: _isProcessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.bolt),
            label: Text(
              _isProcessing
                  ? 'Analyzing & Setting Up...'
                  : 'Decode & Setup for Me (1-Tap)',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),

          // Action 2: Review & Edit Details
          OutlinedButton.icon(
            onPressed: (_isRecording || _isProcessing || _transcriptController.text.isEmpty)
                ? null
                : () => _decodeAndSetup(autoSetup: false),
            icon: const Icon(Icons.tune),
            label: const Text('Review & Fine-Tune Details First'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
