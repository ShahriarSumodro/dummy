import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_service.dart';

class AnalysisParticipant {
  final String label; // e.g. "Person B"
  final String? name; // only if actually spoken in the transcript
  final String? role; // only if actually spoken in the transcript
  final String contribution;

  const AnalysisParticipant({
    required this.label,
    this.name,
    this.role,
    required this.contribution,
  });
}

class AnalysisCommitment {
  final String owner; // "Me" or a speaker label / stated name
  final String task;
  final String? due; // only a deadline that was actually said
  final String evidence;

  const AnalysisCommitment({
    required this.owner,
    required this.task,
    this.due,
    required this.evidence,
  });
}

class MeetingAnalysis {
  final String title;
  final String summary;
  final List<String> keyPoints;
  final List<String> decisions;
  final List<AnalysisParticipant> participants;
  final List<AnalysisCommitment> userCommitments;
  final List<AnalysisCommitment> othersCommitments;

  const MeetingAnalysis({
    required this.title,
    required this.summary,
    required this.keyPoints,
    required this.decisions,
    required this.participants,
    required this.userCommitments,
    required this.othersCommitments,
  });

  bool get hasCommitments =>
      userCommitments.isNotEmpty || othersCommitments.isNotEmpty;
}

/// Understands a speaker-labeled transcript: summary, key points, who said what,
/// and ONLY commitments that were explicitly spoken.
///
/// Unlike the quick-capture extractor, this never falls back to the offline
/// rule engine and never invents meetings, names, dates or reminders. Every
/// commitment must be backed by evidence that is checked against the transcript.
class MeetingAnalysisService {
  static const List<String> _groqModels = [
    'llama-3.3-70b-versatile',
    'llama-3.1-8b-instant',
  ];

  static Future<MeetingAnalysis> analyze({required String transcript}) async {
    final key = (await AiServiceFactory.getApiKey())?.trim() ?? '';
    if (key.isEmpty) {
      throw Exception('Add a Groq or Gemini API key in Settings first.');
    }

    String raw;
    if (key.startsWith('gsk_')) {
      raw = await _callGroq(key, transcript);
    } else if (key.startsWith('AIza')) {
      raw = await _callGemini(key, transcript);
    } else {
      throw Exception('Unrecognized API key format in Settings.');
    }

    final cleaned = raw.replaceAll(RegExp(r'```json|```'), '').trim();
    final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
    return _validate(parsed, transcript);
  }

  static const String _systemPrompt = '''
You analyze a transcript of a real spoken conversation (meeting, podcast, interview, casual discussion).
Lines start with a speaker label produced by voice separation. "Me (the user)" is the owner of this assistant.
"Person A", "Person B", ... are other voices whose names are unknown unless someone says them aloud.

STRICT RULES:
1. Use ONLY what is actually said in the transcript. NEVER invent or guess names, companies, roles, dates,
   meetings, tasks or deadlines. If a speaker's name or role is not spoken, set it to null. Do not guess a
   name from the topic or from famous people.
2. A COMMITMENT exists only when a speaker explicitly says they will do something, or explicitly agrees to
   do something. Opinions, advice, stories, explanations, hypotheticals and statements made to an audience
   are NOT commitments. For a podcast or a plain discussion, empty commitment lists are the correct answer.
3. Only fill "due" if a deadline or time was literally said. Never mention reminders, calendars or meeting
   times unless the speakers actually schedule one.
4. Each commitment needs "evidence": a short, near-verbatim quote (6-25 words) copied from the transcript.
5. "summary": 3-6 sentences describing what was actually discussed (topics, arguments, outcomes).
6. Write title, summary, key points and decisions in the same language the transcript is mostly spoken in.
7. "user_commitments" = things "Me (the user)" promised to do. "others_commitments" = things other speakers
   promised to do (set "owner" to their label or spoken name). If nobody labeled as "Me" exists, leave
   "user_commitments" empty.

Return ONLY valid JSON in exactly this shape:
{
  "title": "3-7 word title",
  "summary": "...",
  "key_points": ["..."],
  "decisions": ["..."],
  "participants": [{"label": "Person B", "name": null, "role": null, "contribution": "one sentence"}],
  "user_commitments": [{"task": "...", "due": null, "evidence": "..."}],
  "others_commitments": [{"owner": "Person B", "task": "...", "due": null, "evidence": "..."}]
}
''';

  /// Asks Groq which chat models this key can use right now, best first.
  /// Hard-coded names break whenever Groq retires a model.
  static Future<List<String>> _groqModelsFor(String key) async {
    try {
      final res = await http
          .get(
            Uri.parse('https://api.groq.com/openai/v1/models'),
            headers: {'Authorization': 'Bearer $key'},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = (jsonDecode(res.body)['data'] as List?) ?? [];
        const skip = [
          'whisper',
          'guard',
          'tts',
          'playai',
          'orpheus',
          'embed',
          'compound',
          'safeguard',
        ];
        const priority = [
          'llama-3.3-70b',
          'gpt-oss-120b',
          'llama-4-maverick',
          'llama-4-scout',
          'qwen',
          'gpt-oss-20b',
          'llama-3.1-8b',
        ];
        final ids = <String>[];
        for (final m in data) {
          final map = m as Map<String, dynamic>;
          if (map['active'] == false) continue;
          final id = (map['id'] as String? ?? '');
          if (id.isEmpty || skip.any(id.toLowerCase().contains)) continue;
          ids.add(id);
        }
        int rank(String id) {
          final i = priority.indexWhere(id.toLowerCase().contains);
          return i < 0 ? priority.length : i;
        }

        ids.sort((a, b) => rank(a).compareTo(rank(b)));
        if (ids.isNotEmpty) return ids.take(4).toList();
      }
    } catch (_) {}
    return _groqModels;
  }

  static Future<String> _callGroq(String key, String transcript) async {
    final errors = <String>[];
    for (final model in await _groqModelsFor(key)) {
      try {
        final res = await http
            .post(
              Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
              headers: {
                'Authorization': 'Bearer $key',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'model': model,
                'messages': [
                  {'role': 'system', 'content': _systemPrompt},
                  {'role': 'user', 'content': transcript},
                ],
                'response_format': {'type': 'json_object'},
                'temperature': 0.1,
              }),
            )
            .timeout(const Duration(seconds: 90));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final choices = data['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final content = choices[0]['message']['content'] as String?;
            if (content != null && content.trim().isNotEmpty) return content;
          }
          errors.add('$model: empty reply');
          continue;
        }
        errors.add('$model: HTTP ${res.statusCode}');
        // Auth problems will not be fixed by another model.
        if (res.statusCode == 401 || res.statusCode == 403) {
          throw Exception(
            'Groq rejected the API key (${res.statusCode}). Check it in Settings.',
          );
        }
      } on Exception catch (e) {
        if (e.toString().contains('rejected the API key')) rethrow;
        errors.add('$model: $e');
      }
    }
    throw Exception(
      'Groq could not analyze the meeting. Tried: ${errors.join('; ')}',
    );
  }

  static Future<String> _callGemini(String key, String transcript) async {
    final res = await http
        .post(
          Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent',
          ),
          headers: {'x-goog-api-key': key, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'system_instruction': {
              'parts': [
                {'text': _systemPrompt},
              ],
            },
            'contents': [
              {
                'parts': [
                  {'text': transcript},
                ],
              },
            ],
            'generationConfig': {
              'temperature': 0.1,
              'responseMimeType': 'application/json',
            },
          }),
        )
        .timeout(const Duration(seconds: 90));
    if (res.statusCode != 200) {
      throw Exception('Gemini error (${res.statusCode}): ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final parts =
        (data['candidates'] as List?)?.first['content']?['parts'] as List? ??
        [];
    return parts.map((p) => (p as Map<String, dynamic>)['text'] ?? '').join();
  }

  // ─────────────────────────────────────────────
  // Anti-hallucination validation
  // ─────────────────────────────────────────────

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Share of this text's words that really occur in the transcript.
  static double _grounding(String text, Set<String> transcriptWords) {
    final words = _norm(text).split(' ').where((w) => w.length > 1).toList();
    if (words.isEmpty) return 0;
    return words.where(transcriptWords.contains).length / words.length;
  }

  static List<String> _strings(dynamic v) => (v as List? ?? [])
      .map((e) => e.toString().trim())
      .where((e) => e.isNotEmpty)
      .toList();

  static MeetingAnalysis _validate(
    Map<String, dynamic> json,
    String transcript,
  ) {
    final words = _norm(transcript).split(' ').toSet();

    // Names and roles must actually appear in what was said.
    final participants = <AnalysisParticipant>[];
    for (final p in (json['participants'] as List? ?? [])) {
      final m = p as Map<String, dynamic>;
      final label = (m['label'] as String? ?? '').trim();
      if (label.isEmpty) continue;
      String? name = (m['name'] as String?)?.trim();
      if (name != null &&
          (name.isEmpty ||
              name.toLowerCase() == 'null' ||
              _grounding(name, words) < 1)) {
        name = null;
      }
      String? role = (m['role'] as String?)?.trim();
      if (role != null &&
          (role.isEmpty ||
              role.toLowerCase() == 'null' ||
              _grounding(role, words) < 0.6)) {
        role = null;
      }
      participants.add(
        AnalysisParticipant(
          label: label,
          name: name,
          role: role,
          contribution: (m['contribution'] as String? ?? '').trim(),
        ),
      );
    }

    // Commitments must be backed by evidence found in the transcript.
    List<AnalysisCommitment> commitments(dynamic raw, {required bool isUser}) {
      final out = <AnalysisCommitment>[];
      for (final c in (raw as List? ?? [])) {
        final m = c as Map<String, dynamic>;
        final task = (m['task'] as String? ?? '').trim();
        final evidence = (m['evidence'] as String? ?? '').trim();
        if (task.isEmpty || evidence.split(' ').length < 3) continue;
        if (_grounding(evidence, words) < 0.7) continue;
        var due = (m['due'] as String?)?.trim();
        if (due != null && (due.isEmpty || due.toLowerCase() == 'null'))
          due = null;
        out.add(
          AnalysisCommitment(
            owner: isUser ? 'Me' : (m['owner'] as String? ?? 'Someone').trim(),
            task: task,
            due: due,
            evidence: evidence,
          ),
        );
      }
      return out;
    }

    final summary = (json['summary'] as String? ?? '').trim();
    return MeetingAnalysis(
      title: ((json['title'] as String?) ?? '').trim().isEmpty
          ? 'Conversation'
          : (json['title'] as String).trim(),
      summary: summary.isEmpty ? 'No summary could be generated.' : summary,
      keyPoints: _strings(json['key_points']),
      decisions: _strings(json['decisions']),
      participants: participants,
      userCommitments: commitments(json['user_commitments'], isUser: true),
      othersCommitments: commitments(json['others_commitments'], isUser: false),
    );
  }
}
