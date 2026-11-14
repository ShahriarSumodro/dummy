import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import '../models/commitment.dart';

enum TtsState { playing, stopped, paused }

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  final ValueNotifier<TtsState> ttsState = ValueNotifier(TtsState.stopped);
  final ValueNotifier<String?> currentSpeakingText = ValueNotifier(null);

  bool _isInitialized = false;
  double _speechRate = 0.5;
  double _pitch = 1.0;
  double _volume = 1.0;
  String _language = 'en-US';

  bool get isSpeaking => ttsState.value == TtsState.playing;

  Future<void> initialize({String language = 'en-US'}) async {
    if (_isInitialized) return;

    try {
      _language = language;
      await _flutterTts.setLanguage(_language);
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setVolume(_volume);
      await _flutterTts.setPitch(_pitch);

      _flutterTts.setStartHandler(() {
        ttsState.value = TtsState.playing;
      });

      _flutterTts.setCompletionHandler(() {
        ttsState.value = TtsState.stopped;
        currentSpeakingText.value = null;
      });

      _flutterTts.setCancelHandler(() {
        ttsState.value = TtsState.stopped;
        currentSpeakingText.value = null;
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint('TTS Error: $msg');
        ttsState.value = TtsState.stopped;
        currentSpeakingText.value = null;
      });

      _isInitialized = true;
      debugPrint('VoiceService initialized successfully with language: $_language');
    } catch (e) {
      debugPrint('Error initializing VoiceService: $e');
    }
  }

  /// Update language based on user's preferred settings (English, Bangla, etc.)
  Future<void> setLanguage(String langCode) async {
    String ttsLang = 'en-US';
    final lower = langCode.toLowerCase();
    if (lower.contains('bangla') || lower.contains('bengali') || lower == 'bn') {
      ttsLang = 'bn-BD';
    } else if (lower.contains('banglish')) {
      ttsLang = 'en-IN'; // South Asian English accent best handles Banglish phonetics
    } else {
      ttsLang = 'en-US';
    }

    _language = ttsLang;
    try {
      await _flutterTts.setLanguage(ttsLang);
    } catch (e) {
      debugPrint('Failed to set TTS language: $e');
    }
  }

  /// Formats any commitment or meeting from an executive assistant perspective (second-person "You").
  /// Transforms awkward first-person titles and eliminates duplicate dates and repeated contact names.
  static String formatCommitmentSpeech({
    required String title,
    required CommitmentType type,
    String? contactName,
    DateTime? dueDate,
  }) {
    var cleanTitle = title.trim();

    // 1. Strip greetings & pleasantries ("Hi,", "Hello,", "Hey,")
    cleanTitle = cleanTitle.replaceAll(
      RegExp(r'^(hi|hello|hey|good morning|good afternoon|good evening|dear|so|okay)\s*[,!:]*\s*', caseSensitive: false),
      '',
    );

    // 2. Strip redundant contact name if title starts with it
    if (contactName != null && contactName.trim().isNotEmpty) {
      final nameClean = contactName.trim();
      cleanTitle = cleanTitle.replaceAll(
        RegExp('^${RegExp.escape(nameClean)}[,:\\s]+', caseSensitive: false),
        '',
      );
    }

    // 3. Strip leading first-person / third-person phrasing
    cleanTitle = cleanTitle.replaceAll(
      RegExp(r"^(i have got|i have|i've|i got)\s+(a\s+)?", caseSensitive: false),
      '',
    );
    cleanTitle = cleanTitle.replaceAll(
      RegExp(r"^(i will|i'll|i promise to|i promised to|i promised|i need to|i have to|i want to|i am going to)\s+", caseSensitive: false),
      '',
    );
    cleanTitle = cleanTitle.replaceAll(
      RegExp(r"^(he said he would|they promised to|he promised to|she promised to|he will|she will|they will)\s+", caseSensitive: false),
      '',
    );

    // 4. Convert first-person possessives ("my office" -> "your office")
    cleanTitle = cleanTitle.replaceAll(RegExp(r'\bmy office\b', caseSensitive: false), 'your office');
    cleanTitle = cleanTitle.replaceAll(RegExp(r'\bmy team\b', caseSensitive: false), 'your team');
    cleanTitle = cleanTitle.replaceAll(RegExp(r'\bmy client\b', caseSensitive: false), 'your client');

    // 5. Strip redundant relative dates from the action phrase if dueDate is already set
    if (dueDate != null) {
      cleanTitle = cleanTitle.replaceAll(
        RegExp(r'\b(by|at|for|on)?\s*tomorrow\s*(at|by)?\s*(\d{1,2}(:\d{2})?\s*(am|pm)?)?\b', caseSensitive: false),
        '',
      );
      cleanTitle = cleanTitle.replaceAll(
        RegExp(r'\b(at|by)\s+\d{1,2}(:\d{2})?\s*(am|pm)?\b', caseSensitive: false),
        '',
      );
      cleanTitle = cleanTitle.replaceAll(
        RegExp(r'\bat\s+[A-Za-z]+\s+\d{1,2}(th|st|nd|rd)?\s*(at\s+\d{1,2}(:\d{2})?)?\b', caseSensitive: false),
        '',
      );
      cleanTitle = cleanTitle.replaceAll(
        RegExp(r'\b(next week|next monday|next tuesday|next wednesday|next thursday|next friday|on monday|on friday)\b', caseSensitive: false),
        '',
      );
    }

    // 6. Strip trailing prepositions
    cleanTitle = cleanTitle.replaceAll(RegExp(r'\s+(to|with|for|at|by)$', caseSensitive: false), '').trim();
    cleanTitle = cleanTitle.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleanTitle.isEmpty) {
      cleanTitle = type == CommitmentType.task ? 'task' : 'deliverable';
    }

    final lower = cleanTitle.toLowerCase();
    final timeStr = dueDate != null
        ? ' at ${DateFormat('h:mm a').format(dueDate)}'
        : '';
    final dateStr = dueDate != null
        ? ' on ${DateFormat('EEEE, MMM d').format(dueDate)}'
        : '';

    // Meeting phrasing
    if (lower.startsWith('meeting') || lower.contains('meeting with') || lower.contains('meeting at')) {
      // Ensure contact is linked if not already inside title
      if (contactName != null &&
          contactName.isNotEmpty &&
          !lower.contains(contactName.toLowerCase())) {
        cleanTitle = '$cleanTitle with $contactName';
      }
      // Ensure starts with lowercase "meeting" for "You have a meeting..."
      cleanTitle = cleanTitle.replaceFirst(RegExp(r'^meeting\s*', caseSensitive: false), '').trim();
      final meetingSubject = cleanTitle.isNotEmpty ? ' $cleanTitle' : '';
      return 'You have a meeting$meetingSubject$dateStr$timeStr.';
    }

    // Convert verb to lowercase for natural flow after "to" (e.g. "to send")
    var verbPhrase = cleanTitle.isNotEmpty
        ? cleanTitle[0].toLowerCase() + cleanTitle.substring(1)
        : cleanTitle;

    // Eliminate duplicate contact name inside verbPhrase if already passed as contactName
    if (contactName != null && contactName.trim().isNotEmpty) {
      verbPhrase = verbPhrase.replaceAll(
        RegExp('^${RegExp.escape(contactName.trim())}[,:\\s]+', caseSensitive: false),
        '',
      );
      verbPhrase = verbPhrase.replaceAll(
        RegExp('to\\s+${RegExp.escape(contactName.trim())}\\s+', caseSensitive: false),
        '',
      );
    }

    if (type == CommitmentType.promiseMade) {
      if (contactName != null && contactName.isNotEmpty) {
        return 'You promised $contactName to $verbPhrase$dateStr$timeStr.';
      }
      return 'You promised to $verbPhrase$dateStr$timeStr.';
    }

    if (type == CommitmentType.promiseReceived) {
      if (contactName != null && contactName.isNotEmpty) {
        return '$contactName promised you to $verbPhrase$dateStr$timeStr.';
      }
      return 'You are expecting: $verbPhrase$dateStr$timeStr.';
    }

    if (type == CommitmentType.followUp) {
      if (contactName != null && contactName.isNotEmpty) {
        return 'You have a follow-up with $contactName to $verbPhrase$dateStr$timeStr.';
      }
      return 'You have a follow-up to $verbPhrase$dateStr$timeStr.';
    }

    // Default task
    final capitalized = cleanTitle[0].toUpperCase() + cleanTitle.substring(1);
    return 'You have a commitment: $capitalized$dateStr$timeStr.';
  }

  /// Clean markdown, links, bullets, and emojis so speech flows naturally
  static String cleanTextForSpeech(String input) {
    var text = input;

    // Remove markdown code blocks ```...```
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), '');

    // Remove inline code `...`
    text = text.replaceAll(RegExp(r'`([^`]+)`'), r'$1');

    // Remove markdown links [text](url) -> text
    text = text.replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1');

    // Remove markdown headers #, ##, ###
    text = text.replaceAll(RegExp(r'^[#]+\s*', multiLine: true), '');

    // Remove bold and italic markers **text** or *text*
    text = text.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
    text = text.replaceAll(RegExp(r'\*([^*]+)\*'), r'$1');
    text = text.replaceAll(RegExp(r'_([^_]+)_'), r'$1');

    // Clean bullet symbols (-, *, •) at line beginnings
    text = text.replaceAll(RegExp(r'^\s*[-*•]\s+', multiLine: true), '');

    // Remove extra whitespace & multiple newlines
    text = text.replaceAll(RegExp(r'\n+'), '. ');
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    return text.trim();
  }

  /// Speak text out loud. If already speaking this text, it will stop.
  Future<void> speak(String text) async {
    if (!_isInitialized) await initialize();

    final cleanText = cleanTextForSpeech(text);
    if (cleanText.isEmpty) return;

    // If already speaking this same text, stop it (toggle behavior)
    if (isSpeaking && currentSpeakingText.value == text) {
      await stop();
      return;
    }

    // Stop whatever was speaking before starting new
    await stop();

    currentSpeakingText.value = text;
    try {
      await _flutterTts.speak(cleanText);
    } catch (e) {
      debugPrint('Error during TTS speak: $e');
      ttsState.value = TtsState.stopped;
      currentSpeakingText.value = null;
    }
  }

  /// Stop current playback
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('Error stopping TTS: $e');
    }
    ttsState.value = TtsState.stopped;
    currentSpeakingText.value = null;
  }

  /// Set speaking rate (0.0 to 1.0)
  Future<void> setRate(double rate) async {
    _speechRate = rate.clamp(0.1, 1.0);
    try {
      await _flutterTts.setSpeechRate(_speechRate);
    } catch (e) {
      debugPrint('Error setting rate: $e');
    }
  }
}
