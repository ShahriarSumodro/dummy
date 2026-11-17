import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'database_service.dart';

/// One continuous stretch of speech by a single voice.
class SpeakerUtterance {
  final int speaker;
  final String text;
  final double start;
  final double end;
  final String? tone;

  const SpeakerUtterance({
    required this.speaker,
    required this.text,
    this.start = 0,
    this.end = 0,
    this.tone,
  });
}

/// A full meeting transcript separated by voice.
/// Speakers are named Person A, Person B, ... in order of first appearance.
class DiarizedTranscript {
  final List<SpeakerUtterance> utterances;
  final List<int> _order;
  final Map<int, Map<String, int>> toneCounts; // speaker -> tone -> turns

  DiarizedTranscript(this.utterances, {this.toneCounts = const {}})
    : _order = _firstAppearanceOrder(utterances);

  /// "Person A" -> dominant non-neutral tone, only when it covers >= 25% of
  /// that person's turns. An estimate from voice, never a fact.
  Map<String, String> get moodByLabel {
    final out = <String, String>{};
    for (final entry in toneCounts.entries) {
      final total = entry.value.values.fold<int>(0, (a, b) => a + b);
      if (total == 0) continue;
      String? best;
      var bestN = 0;
      entry.value.forEach((tone, n) {
        if (tone != 'neutral' && n > bestN) {
          best = tone;
          bestN = n;
        }
      });
      if (best != null && bestN / total >= 0.25) {
        out[labelFor(entry.key)] = best!;
      }
    }
    return out;
  }

  static List<int> _firstAppearanceOrder(List<SpeakerUtterance> list) {
    final seen = <int>[];
    for (final u in list) {
      if (!seen.contains(u.speaker)) seen.add(u.speaker);
    }
    return seen;
  }

  int get speakerCount => _order.length;

  String labelFor(int speaker) {
    final i = _order.indexOf(speaker);
    if (i < 0) return 'Person ?';
    return i < 26 ? 'Person ${String.fromCharCode(65 + i)}' : 'Person ${i + 1}';
  }

  List<String> get labels => _order.map(labelFor).toList();

  /// "Person A: ...\nPerson B: ..." — one line per speaker turn.
  String toLabeledText() =>
      utterances.map((u) => '${labelFor(u.speaker)}: ${u.text}').join('\n');
}

/// Speaker separation using Gemini's audio understanding (free tier on
/// Google AI Studio). Groq cannot tell voices apart, so Gemini produces the
/// "who said what" transcript and Groq keeps doing summary / task extraction.
class DiarizationService {
  static const String _prefKey = 'diarization_api_key';
  static const String _base =
      'https://generativelanguage.googleapis.com/v1beta';
  static final _db = DatabaseService();

  // Inline audio limit is 20 MB per request, and base64 adds ~33%.
  static const int _maxAudioBytes = 14 * 1024 * 1024;

  static Future<String?> getApiKey() => _db.getSetting(_prefKey);

  static Future<void> setApiKey(String key) =>
      _db.setSetting(_prefKey, key.trim());

  /// [languageCode]: 'en' for English, 'bn' for Bengali.
  static Future<DiarizedTranscript> transcribe({
    required File file,
    required String apiKey,
    String languageCode = 'en',
  }) async {
    final key = apiKey.trim();
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw Exception('Recording is empty.');
    if (bytes.length > _maxAudioBytes) {
      throw Exception(
        'Recording is too long for one upload (about 55 minutes max). Split the meeting into parts.',
      );
    }

    final mime = file.path.toLowerCase().endsWith('.wav')
        ? 'audio/wav'
        : 'audio/mp4';
    final langName = languageCode == 'bn'
        ? 'Bengali (write Bengali in Bengali script)'
        : 'English';
    final prompt =
        '''
Transcribe this meeting recording and separate it by speaker.
- The main spoken language is $langName. Keep other languages as spoken; never translate.
- Identify each distinct voice. Label them "Person A", "Person B", "Person C", ... in order of first appearance.
- The SAME voice must keep the SAME label for the entire recording.
- Each item is one speaker turn. Merge consecutive sentences from the same voice into one item.
- Transcribe what was said as accurately as possible. Skip silence, music and background noise.
- If a speaker clearly states their own name, still use the Person label.
- For each turn add "tone": one of calm, happy, excited, stressed, frustrated, sad, uncertain, neutral. Judge it from how the voice sounds (pace, pitch, energy), not only the words. If unsure use "neutral".
Return only JSON: an array of objects {"speaker": "Person A", "text": "...", "tone": "calm"}.
''';

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'inline_data': {'mime_type': mime, 'data': base64Encode(bytes)},
            },
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.1,
        'maxOutputTokens': 32768,
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'ARRAY',
          'items': {
            'type': 'OBJECT',
            'properties': {
              'speaker': {'type': 'STRING'},
              'text': {'type': 'STRING'},
              'tone': {'type': 'STRING'},
            },
            'required': ['speaker', 'text'],
          },
        },
      },
    });

    final models = await _candidateModels(key);
    String lastError = 'No Gemini model is available for this key.';

    for (final model in models) {
      final res = await _postWithRetry(
        Uri.parse('$_base/models/$model:generateContent'),
        {'x-goog-api-key': key, 'Content-Type': 'application/json'},
        body,
      );

      if (res.statusCode == 200) {
        return _parse(res.body);
      }
      if (res.statusCode == 400 && res.body.contains('API key not valid')) {
        throw Exception(
          'Gemini rejected the API key. Check that you copied it fully.',
        );
      }
      if (res.statusCode == 429) {
        throw Exception(
          'Gemini free-tier limit reached. Wait a minute and tap Retry.',
        );
      }
      lastError = 'Gemini error (${res.statusCode}) on $model: ${res.body}';
      if (res.statusCode == 404 || res.statusCode == 400)
        continue; // try next model
      throw Exception(lastError);
    }
    throw Exception(lastError);
  }

  /// Large audio uploads can drop on mobile networks. Retry before giving up.
  static Future<http.Response> _postWithRetry(
    Uri uri,
    Map<String, String> headers,
    String body,
  ) async {
    const waits = [
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 10),
    ];
    for (var attempt = 0; ; attempt++) {
      try {
        return await http
            .post(uri, headers: headers, body: body)
            .timeout(const Duration(minutes: 6));
      } catch (e) {
        final retryable =
            e is SocketException ||
            e is http.ClientException ||
            e is TimeoutException;
        if (!retryable) rethrow;
        if (attempt >= waits.length) {
          throw Exception(
            'The connection dropped while uploading the recording. Check your internet and tap Retry (your audio is kept).',
          );
        }
      }
      await Future.delayed(waits[attempt]);
    }
  }

  /// "gemini-flash-latest" first, then the newest stable Flash models this key can use.
  static Future<List<String>> _candidateModels(String key) async {
    final models = <String>['gemini-flash-latest'];
    try {
      final res = await http
          .get(
            Uri.parse('$_base/models?pageSize=200'),
            headers: {'x-goog-api-key': key},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body)['models'] as List?) ?? [];
        final found = <MapEntry<double, String>>[];
        final re = RegExp(r'^models/(gemini-(\d+(?:\.\d+)?)-flash)$');
        for (final m in list) {
          final map = m as Map<String, dynamic>;
          final methods = (map['supportedGenerationMethods'] as List?) ?? [];
          if (!methods.contains('generateContent')) continue;
          final match = re.firstMatch(map['name'] as String? ?? '');
          if (match != null) {
            found.add(MapEntry(double.parse(match.group(2)!), match.group(1)!));
          }
        }
        found.sort((a, b) => b.key.compareTo(a.key));
        for (final f in found.take(2)) {
          if (!models.contains(f.value)) models.add(f.value);
        }
      } else if (res.statusCode == 400 || res.statusCode == 403) {
        throw Exception(
          'Gemini rejected the API key (${res.statusCode}). Check the key.',
        );
      }
    } on Exception catch (e) {
      if (e.toString().contains('rejected')) rethrow;
    }
    return models;
  }

  static DiarizedTranscript _parse(String responseBody) {
    final data = jsonDecode(responseBody) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception(
        'Gemini returned no result (the audio may have been blocked).',
      );
    }
    final parts = (candidates.first['content']?['parts'] as List?) ?? [];
    var text = parts
        .map((p) => (p as Map<String, dynamic>)['text'] ?? '')
        .join();
    text = text.replaceAll(RegExp(r'```json|```'), '').trim();

    final decoded = jsonDecode(text);
    final items = decoded is List
        ? decoded
        : (decoded['segments'] as List? ?? const []);

    final indexByLabel = <String, int>{};
    final raw = <SpeakerUtterance>[];
    final tones = <int, Map<String, int>>{};
    for (final item in items) {
      final m = item as Map<String, dynamic>;
      final label = (m['speaker'] as String? ?? 'Person A').trim();
      final t = (m['text'] as String? ?? '').trim();
      if (t.isEmpty) continue;
      final idx = indexByLabel.putIfAbsent(
        label.toLowerCase(),
        () => indexByLabel.length,
      );
      final tone = (m['tone'] as String? ?? '').trim().toLowerCase();
      if (tone.isNotEmpty) {
        final byTone = tones.putIfAbsent(idx, () => <String, int>{});
        byTone[tone] = (byTone[tone] ?? 0) + 1;
      }
      raw.add(SpeakerUtterance(speaker: idx, text: t, tone: tone));
    }

    if (raw.isEmpty) throw Exception('No speech detected in the recording.');

    final merged = <SpeakerUtterance>[];
    for (final u in raw) {
      if (merged.isNotEmpty && merged.last.speaker == u.speaker) {
        final last = merged.removeLast();
        merged.add(
          SpeakerUtterance(
            speaker: last.speaker,
            text: '${last.text} ${u.text}',
            tone: last.tone,
          ),
        );
      } else {
        merged.add(u);
      }
    }
    return DiarizedTranscript(merged, toneCounts: tones);
  }
}
