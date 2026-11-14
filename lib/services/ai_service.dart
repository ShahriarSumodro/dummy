import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_service.dart';
import '../models/ai_extraction_result.dart';
import '../models/contact.dart';
import '../models/commitment.dart';

/// Supported AI Providers with generous or 100% free tiers.
enum AiProvider {
  gemini('Google Gemini', 'gemini-2.0-flash', 'Free tier via Google AI Studio (15 RPM, 1M context)'),
  groq('Groq Cloud', 'llama-3.3-70b-versatile', 'Free tier via console.groq.com (Ultra-fast LPU, Llama 3.3 70B)');

  final String label;
  final String defaultModel;
  final String description;
  const AiProvider(this.label, this.defaultModel, this.description);
}

/// Abstract AI interface for memory extraction.
/// Allows swapping providers (Gemini, Groq, local LLMs, etc.) without UI changes.
abstract class AiService {
  Future<AiExtractionResult> extract({
    required String text,
    List<Contact> existingContacts = const [],
  });
}

/// Service factory that selects the active AI provider.
class AiServiceFactory {
  static const String _prefApiKey = 'gemini_api_key';
  static const String _prefProvider = 'ai_provider';
  static const String _prefUseMock = 'use_mock_ai';

  static final _db = DatabaseService();

  static Future<String?> getApiKey() async {
    return await _db.getSetting(_prefApiKey);
  }

  static Future<void> setApiKey(String key) async {
    final trimmed = key.trim();
    await _db.setSetting(_prefApiKey, trimmed);
    if (trimmed.startsWith('gsk_')) {
      await setProvider(AiProvider.groq);
    } else if (trimmed.startsWith('AIza')) {
      await setProvider(AiProvider.gemini);
    }
  }

  static Future<AiProvider> getProvider() async {
    final val = await _db.getSetting(_prefProvider);
    if (val == 'groq') return AiProvider.groq;
    return AiProvider.gemini;
  }

  static Future<void> setProvider(AiProvider provider) async {
    await _db.setSetting(_prefProvider, provider.name);
  }

  static Future<bool> isMockMode() async {
    final val = await _db.getSetting(_prefUseMock);
    return val == 'true';
  }

  static Future<void> setMockMode(bool val) async {
    await _db.setSetting(_prefUseMock, val ? 'true' : 'false');
  }

  static Future<AiService> getService() async {
    final useMock = await isMockMode();
    final apiKey = await getApiKey();

    if (useMock || apiKey == null || apiKey.isEmpty) {
      return MockAiService();
    }

    final provider = await getProvider();
    if (provider == AiProvider.groq || apiKey.startsWith('gsk_')) {
      return GroqAiService(apiKey: apiKey);
    }
    return GeminiAiService(apiKey: apiKey);
  }

  /// Tests the API key with a fast ping request.
  static Future<String> testConnection({
    required AiProvider provider,
    required String apiKey,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) throw Exception('API key cannot be empty');

    if (provider == AiProvider.groq || key.startsWith('gsk_')) {
      if (!key.startsWith('gsk_')) {
        if (key.startsWith('AIza')) {
          throw Exception(
            'This looks like a Google Gemini key, not a Groq key. Switch provider to "Google Gemini" or get a Groq key starting with "gsk_" from https://console.groq.com/keys',
          );
        }
        throw Exception(
          'Invalid Groq key format. Groq API keys must begin with "gsk_". Generate a free key at https://console.groq.com/keys',
        );
      }

      // Check models endpoint to verify auth and active catalog
      final modelsUrl = Uri.parse('https://api.groq.com/openai/v1/models');
      final modelsRes = await http.get(
        modelsUrl,
        headers: {
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (modelsRes.statusCode == 200) {
        try {
          final data = jsonDecode(modelsRes.body) as Map<String, dynamic>;
          final list = (data['data'] as List?)
              ?.map((m) => m['id'] as String)
              .where((id) => !id.contains('whisper') && !id.contains('guard'))
              .toList() ?? [];
          final activeModel = list.isNotEmpty ? list.first : 'LPU';
          return 'Groq Cloud connected successfully! (Active Model: $activeModel)';
        } catch (_) {
          return 'Groq Cloud connected successfully! (LPU inference active)';
        }
      } else {
        throw Exception('Groq error (${modelsRes.statusCode}): ${modelsRes.body}');
      }
    } else {
      if (!key.startsWith('AIza') && key.startsWith('gsk_')) {
        throw Exception(
          'This looks like a Groq API key, not a Gemini key. Switch provider to "Groq Cloud" or get a Gemini key from https://aistudio.google.com',
        );
      }

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$key',
      );
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': 'ping'}
              ]
            }
          ]
        }),
      );
      if (res.statusCode == 200) {
        return 'Google Gemini 2.0 Flash connected successfully!';
      } else {
        throw Exception('Gemini error (${res.statusCode}): ${res.body}');
      }
    }
  }
}

/// Groq Cloud API implementation (Ultra-fast inference with automatic model fallback).
class GroqAiService implements AiService {
  final String apiKey;
  static const List<String> _candidateModels = [
    'llama-3.3-70b-versatile',
    'llama-3.1-8b-instant',
    'llama-3.1-70b-versatile',
    'llama3-70b-8192',
    'llama3-8b-8192',
    'mixtral-8x7b-32768',
    'qwen-2.5-32b',
    'deepseek-r1-distill-llama-70b',
  ];

  GroqAiService({required this.apiKey});

  @override
  Future<AiExtractionResult> extract({
    required String text,
    List<Contact> existingContacts = const [],
  }) async {
    final now = DateTime.now();
    final knownContactsList = existingContacts
        .map((c) => '{"id": ${c.id}, "name": "${c.name}", "company": "${c.company ?? ''}"}')
        .join(',\n');

    final systemInstruction = '''
You are RemembrAI, the user's executive personal business assistant.
Analyze user notes or conversation transcripts to extract commitments, promises, contacts, and reminders.

Rules:
1. Current timestamp: ${now.toIso8601String()}.
2. Known existing contacts in user database:
[$knownContactsList]
If a mentioned person closely matches a known contact, reference their name.

3. EXECUTIVE ASSISTANT PERSPECTIVE & TITLE NORMALIZATION (CRITICAL):
   - You work FOR the user. NEVER echo first-person pronouns ("I", "I will", "I have", "I've", "we") in titles!
   - Convert user statements into concise, second-person actionable imperative or objective phrasing:
     * User: "I've a meeting at 10:30 with Raju" -> title: "Meeting with Raju at 10:30 AM"
     * User: "I promised to send the quotation to Karim" -> title: "Send quotation to Karim"
     * User: "Rahim promised he will deliver the draft by Friday" -> title: "Receive draft from Rahim"
     * User: "I need to follow up with Apex Corp next week" -> title: "Follow up with Apex Corp"

4. SPEECH SELF-CORRECTIONS & DISFLUENCY (CRITICAL):
   - Users speaking naturally often change their mind or correct themselves mid-sentence:
     * User: "Hi, I have a meeting tomorrow, not tomorrow, maybe 16th of November at 3 p.m. at my office."
       -> "not tomorrow" retracts "tomorrow". The final date is November 16th at 3:00 PM.
       -> Strip greetings ("Hi", "Hello") and filler.
       -> Title: "Meeting at office"
       -> Location: "office"
     * User: "Meeting with Rahim, sorry Raju on Friday" -> Contact is Raju, not Rahim.
   - Ignore retracted phrases! Never parse the word "maybe" as the month of "May"!

5. MULTI-PARTY CONVERSATION DISENTANGLEMENT:
   - When a conversation involves multiple participants (e.g. Person A, Person B, Person C, Person D, or distinct speakers):
   - Identify every distinct participant in "contacts". If their real name is not stated, label them with their exact tag (e.g. "Person D", "Person B"), set "is_unresolved": true, and summarize what they discussed in "detected_context".
   - Link each commitment or task to the specific participant in "contact_name".

6. CONVERSATIONAL NOISE & CASUAL BANTER FILTERING (CRITICAL):
   - Real voice transcripts frequently contain casual banter, greetings, rhetorical questions, and filler ("What's up?", "Yeah man, it's all good", "Hello", "How are you?").
   - DISCARD ALL SMALL TALK AND GREETINGS! NEVER turn casual greetings into commitments!
   - Extract ONLY concrete actionable promises, meetings, or tasks.
   - If the transcript contains NO genuine commitments or tasks (pure small talk), return "commitments": [] and "summary": "Casual conversation; no actionable commitments detected."

7. Categorize each commitment as:
   - "promiseMade": Something the USER promised to do for someone.
   - "promiseReceived": Something SOMEONE ELSE promised to do for the user.
   - "followUp": An action the user needs to follow up on.
   - "task": A general to-do item.

8. Calculate exact ISO-8601 deadlines (due_date, remind_at) based on relative references like "tomorrow", "next Monday at 3pm", "in two days", or explicit dates like "16th of November at 3 PM".

9. Return strictly valid JSON conforming to this schema:
{
  "summary": "Brief 1-sentence recap of what was discussed",
  "contacts": [
    {
      "name": "Full Name or Person A / Person B",
      "placeholder_tag": "Person A or null",
      "is_unresolved": false,
      "detected_context": "What this person said or their role in the discussion",
      "company": "Company Name or null",
      "role": "Title or role (e.g. Designer, Legal Advisor)",
      "notes": "Contextual notes or null"
    }
  ],
  "commitments": [
    {
      "title": "Normalized action phrase (NEVER use 'I' or 'I will')",
      "description": "Additional details or null",
      "type": "promiseMade | promiseReceived | followUp | task",
      "due_date": "YYYY-MM-DDTHH:mm:ss or null",
      "contact_name": "Related person's name (or Person A / Person B)",
      "confidence": 0.95,
      "source_excerpt": "verbatim text span that triggered this promise"
    }
  ],
  "reminders": [
    {
      "title": "Reminder title (normalized)",
      "remind_at": "YYYY-MM-DDTHH:mm:ss",
      "is_recurring": false,
      "recurring_rule": null,
      "confidence": 0.95,
      "source_excerpt": "verbatim text span"
    }
  ]
}
''';

    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    // Try candidate models in cascade if one returns 404 or model_not_found
    for (final model in _candidateModels) {
      try {
        final response = await http.post(
          url,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'system', 'content': systemInstruction},
              {'role': 'user', 'content': text},
            ],
            'response_format': {'type': 'json_object'},
            'temperature': 0.1,
          }),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final choices = data['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final rawJsonText = choices[0]['message']['content'] as String;
            final parsed = jsonDecode(rawJsonText) as Map<String, dynamic>;
            return _parseExtractionJson(text, parsed, existingContacts);
          }
        } else if (response.statusCode == 404) {
          // Model deprecated or not enabled on account, try next candidate
          continue;
        } else {
          // Other status, try next or break
          continue;
        }
      } catch (_) {
        // Network timeout or socket exception, try next or fallback
        continue;
      }
    }

    // Fallback gracefully to offline intelligence if all cloud models failed
    return MockAiService().extract(text: text, existingContacts: existingContacts);
  }
}
  }
}

/// Google Gemini API implementation (cost-efficient, fast, generous free tier).
class GeminiAiService implements AiService {
  final String apiKey;
  static const String _model = 'gemini-2.0-flash';

  GeminiAiService({required this.apiKey});

  @override
  Future<AiExtractionResult> extract({
    required String text,
    List<Contact> existingContacts = const [],
  }) async {
    final now = DateTime.now();
    final knownContactsList = existingContacts
        .map((c) => '{"id": ${c.id}, "name": "${c.name}", "company": "${c.company ?? ''}"}')
        .join(',\n');

    final systemInstruction = '''
You are RemembrAI, the user's executive personal business assistant.
Analyze user notes or conversation transcripts to extract commitments, promises, contacts, and reminders.

Rules:
1. Current timestamp: ${now.toIso8601String()}.
2. Known existing contacts in user database:
[$knownContactsList]
If a mentioned person closely matches a known contact, reference their name.

3. EXECUTIVE ASSISTANT PERSPECTIVE & TITLE NORMALIZATION (CRITICAL):
   - You work FOR the user. NEVER echo first-person pronouns ("I", "I will", "I have", "I've", "we") in titles!
   - Convert user statements into concise, second-person actionable imperative or objective phrasing:
     * User: "I've a meeting at 10:30 with Raju" -> title: "Meeting with Raju at 10:30 AM"
     * User: "I promised to send the quotation to Karim" -> title: "Send quotation to Karim"
     * User: "Rahim promised he will deliver the draft by Friday" -> title: "Receive draft from Rahim"
     * User: "I need to follow up with Apex Corp next week" -> title: "Follow up with Apex Corp"

4. SPEECH SELF-CORRECTIONS & DISFLUENCY (CRITICAL):
   - Users speaking naturally often change their mind or correct themselves mid-sentence:
     * User: "Hi, I have a meeting tomorrow, not tomorrow, maybe 16th of November at 3 p.m. at my office."
       -> "not tomorrow" retracts "tomorrow". The final date is November 16th at 3:00 PM.
       -> Strip greetings ("Hi", "Hello") and filler.
       -> Title: "Meeting at office"
       -> Location: "office"
     * User: "Meeting with Rahim, sorry Raju on Friday" -> Contact is Raju, not Rahim.
   - Ignore retracted phrases! Never parse the word "maybe" as the month of "May"!

5. MULTI-PARTY CONVERSATION DISENTANGLEMENT:
   - When a conversation involves multiple participants (e.g. Person A, Person B, Person C, Person D, or distinct speakers):
   - Identify every distinct participant in "contacts". If their real name is not stated, label them with their exact tag (e.g. "Person D", "Person B"), set "is_unresolved": true, and summarize what they discussed in "detected_context".
   - Link each commitment or task to the specific participant in "contact_name".

6. CONVERSATIONAL NOISE & CASUAL BANTER FILTERING (CRITICAL):
   - Real voice transcripts frequently contain casual banter, greetings, rhetorical questions, and filler ("What's up?", "Yeah man, it's all good", "Hello", "How are you?").
   - DISCARD ALL SMALL TALK AND GREETINGS! NEVER turn casual greetings into commitments!
   - Extract ONLY concrete actionable promises, meetings, or tasks.
   - If the transcript contains NO genuine commitments or tasks (pure small talk), return "commitments": [] and "summary": "Casual conversation; no actionable commitments detected."

7. Categorize each commitment as:
   - "promiseMade": Something the USER promised to do for someone.
   - "promiseReceived": Something SOMEONE ELSE promised to do for the user.
   - "followUp": An action the user needs to follow up on.
   - "task": A general to-do item.

8. Calculate exact ISO-8601 deadlines (due_date, remind_at) based on relative references like "tomorrow", "next Monday at 3pm", "in two days", or explicit dates like "16th of November at 3 PM".

9. Return strictly valid JSON conforming to this schema:
{
  "summary": "Brief 1-sentence recap of what was discussed",
  "contacts": [
    {
      "name": "Full Name or Person A / Person B",
      "placeholder_tag": "Person A or null",
      "is_unresolved": false,
      "detected_context": "What this person said or their role in the discussion",
      "company": "Company Name or null",
      "role": "Title or role (e.g. Designer, Legal Advisor)",
      "notes": "Contextual notes or null"
    }
  ],
  "commitments": [
    {
      "title": "Normalized action phrase (NEVER use 'I' or 'I will')",
      "description": "Additional details or null",
      "type": "promiseMade | promiseReceived | followUp | task",
      "due_date": "YYYY-MM-DDTHH:mm:ss or null",
      "contact_name": "Related person's name (or Person A / Person B)",
      "confidence": 0.95,
      "source_excerpt": "verbatim text span that triggered this promise"
    }
  ],
  "reminders": [
    {
      "title": "Reminder title (normalized)",
      "remind_at": "YYYY-MM-DDTHH:mm:ss",
      "is_recurring": false,
      "recurring_rule": null,
      "confidence": 0.95,
      "source_excerpt": "verbatim text span"
    }
  ]
}
''';

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$apiKey',
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': '$systemInstruction\n\nUSER INPUT:\n$text'}
              ]
            }
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
            'temperature': 0.1,
          }
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final rawJsonText =
              candidates[0]['content']['parts'][0]['text'] as String;
          final parsed = jsonDecode(rawJsonText) as Map<String, dynamic>;
          return _parseExtractionJson(text, parsed, existingContacts);
        }
      }
    } catch (_) {}

    // Resilient fallback to offline mock engine
    return MockAiService().extract(text: text, existingContacts: existingContacts);
  }
}

/// Offline rule-based fallback when no API key is set or offline.
class MockAiService implements AiService {
  @override
  Future<AiExtractionResult> extract({
    required String text,
    List<Contact> existingContacts = const [],
  }) async {
    // Artificial small delay to simulate processing
    await Future.delayed(const Duration(milliseconds: 400));

    // Strip leading conversational greetings: "Hi,", "Hello,", "Hey,"
    var cleanedText = text.trim().replaceFirst(
      RegExp(r'^(hi|hello|hey|good morning|good afternoon|good evening)\s*[,!:]*\s*', caseSensitive: false),
      '',
    );

    final lower = cleanedText.toLowerCase();
    final contacts = <ExtractedContact>[];
    final commitments = <ExtractedCommitment>[];
    final reminders = <ExtractedReminder>[];

    // Check for matched existing contacts (full name or individual name parts)
    String? matchedContactName;
    int? matchedContactId;
    for (final c in existingContacts) {
      final nameLower = c.name.toLowerCase().trim();
      final nameParts = nameLower.split(RegExp(r'\s+'));
      if (lower.contains(nameLower) ||
          nameParts.any((part) => part.length >= 3 && lower.contains(part))) {
        matchedContactName = c.name;
        matchedContactId = c.id;
        break;
      }
    }

    // Heuristic detection of commitment type
    CommitmentType type = CommitmentType.task;
    if (lower.contains('meeting') || lower.contains('appointment')) {
      type = CommitmentType.task;
    } else if (lower.contains('i promised') ||
        lower.contains("i'll") ||
        lower.contains('i will') ||
        lower.contains('i commit')) {
      type = CommitmentType.promiseMade;
    } else if (lower.contains('they promised') ||
        lower.contains('he said he would') ||
        lower.contains('she said she would') ||
        lower.contains('promised to send')) {
      type = CommitmentType.promiseReceived;
    } else if (lower.contains('follow up') || lower.contains('follow-up')) {
      type = CommitmentType.followUp;
    }

    // ─────────────────────────────────────────────
    // INTELLIGENT DATE & TIME EXTRACTION (With Retraction Awareness)
    // ─────────────────────────────────────────────
    DateTime? dueDate;
    final now = DateTime.now();

    // Time pattern: e.g. "3 p.m.", "3pm", "10:30 am", "10:30"
    int targetHour = 15;
    int targetMinute = 0;
    final timeMatch = RegExp(
      r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)\b',
      caseSensitive: false,
    ).firstMatch(lower);

    if (timeMatch != null) {
      int h = int.parse(timeMatch.group(1)!);
      int m = timeMatch.group(2) != null ? int.parse(timeMatch.group(2)!) : 0;
      final ampm = timeMatch.group(3)!.toLowerCase().replaceAll('.', '');
      if (ampm == 'pm' && h < 12) h += 12;
      if (ampm == 'am' && h == 12) h = 0;
      targetHour = h;
      targetMinute = m;
    }

    // Month mappings (ensures "maybe" is never matched as "may")
    final monthMap = {
      'january': 1, 'february': 2, 'march': 3, 'april': 4,
      'may': 5, 'june': 6, 'july': 7, 'august': 8,
      'september': 9, 'october': 10, 'november': 11, 'december': 12,
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'jun': 6, 'jul': 7,
      'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };

    // Explicit date: "16th of November" or "16 November"
    final dmRegex = RegExp(
      r'\b(\d{1,2})(?:st|nd|rd|th)?\s+(?:of\s+)?(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|oct|nov|dec)\b',
      caseSensitive: false,
    );
    // Explicit date: "November 16th" or "November 16"
    final mdRegex = RegExp(
      r'\b(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|oct|nov|dec)\s+(\d{1,2})(?:st|nd|rd|th)?\b',
      caseSensitive: false,
    );

    final dmMatch = dmRegex.firstMatch(lower);
    final mdMatch = mdRegex.firstMatch(lower);

    if (dmMatch != null) {
      final day = int.parse(dmMatch.group(1)!);
      final month = monthMap[dmMatch.group(2)!.toLowerCase()];
      if (month != null && day >= 1 && day <= 31) {
        int year = now.year;
        if (DateTime(year, month, day).isBefore(DateTime(now.year, now.month, now.day))) {
          year++;
        }
        dueDate = DateTime(year, month, day, targetHour, targetMinute);
      }
    } else if (mdMatch != null) {
      final monthStr = mdMatch.group(1)!.toLowerCase();
      // Only match if not part of "maybe"
      final month = monthMap[monthStr];
      final day = int.parse(mdMatch.group(2)!);
      if (month != null && day >= 1 && day <= 31) {
        int year = now.year;
        if (DateTime(year, month, day).isBefore(DateTime(now.year, now.month, now.day))) {
          year++;
        }
        dueDate = DateTime(year, month, day, targetHour, targetMinute);
      }
    }

    // Relative dates with disfluency/retraction awareness:
    // e.g. "tomorrow, not tomorrow, maybe 16th of November" -> "not tomorrow" negates "tomorrow"
    final isTomorrowNegated = lower.contains('not tomorrow') ||
        lower.contains('no tomorrow') ||
        lower.contains('cancel tomorrow');

    if (dueDate == null) {
      if (lower.contains('tomorrow') && !isTomorrowNegated) {
        dueDate = DateTime(now.year, now.month, now.day + 1, targetHour, targetMinute);
      } else if (lower.contains('next week')) {
        dueDate = DateTime(now.year, now.month, now.day + 7, targetHour, targetMinute);
      } else if (lower.contains('friday')) {
        int daysUntilFriday = (DateTime.friday - now.weekday) % 7;
        if (daysUntilFriday <= 0) daysUntilFriday += 7;
        dueDate = DateTime(now.year, now.month, now.day + daysUntilFriday, targetHour, targetMinute);
      }
    }

    // Detect multi-person mentions (e.g. Person A, Person B, Person D)
    final participantRegex = RegExp(r'\b(Person\s+[A-Za-z0-9]|Speaker\s+[A-Za-z0-9])\b', caseSensitive: false);
    final participantMatches = participantRegex.allMatches(cleanedText);
    final seenTags = <String>{};
    for (final m in participantMatches) {
      final rawTag = m.group(0)!;
      final normalizedTag = rawTag.trim();
      if (!seenTags.contains(normalizedTag.toLowerCase())) {
        seenTags.add(normalizedTag.toLowerCase());

        String? contextSnippet;
        final sentences = cleanedText.split(RegExp(r'[.!?\n]+'));
        for (final s in sentences) {
          if (s.toLowerCase().contains(normalizedTag.toLowerCase())) {
            contextSnippet = s.trim();
            break;
          }
        }

        contacts.add(ExtractedContact(
          name: normalizedTag,
          placeholderTag: normalizedTag,
          isUnresolved: true,
          detectedContext: contextSnippet ?? 'Mentioned in group discussion',
          role: 'Discussion Participant',
        ));
      }
    }

    // Detect location if mentioned (e.g. "at my office", "at the office", "at Dhanmondi")
    String? locationSnippet;
    final locMatch = RegExp(r'\bat\s+(my\s+office|the\s+office|office|[A-Z][a-zA-Z\s]+(?:Office|Center|Hub|Room|Cafe|HQ))\b', caseSensitive: false).firstMatch(cleanedText);
    if (locMatch != null) {
      locationSnippet = locMatch.group(1)!.trim().replaceAll(RegExp(r'^my\s+', caseSensitive: false), '');
    }

    // ─────────────────────────────────────────────
    // NORMALIZE COMMITMENT TITLE (Executive Assistant Perspective)
    // ─────────────────────────────────────────────
    String normalizedTitle;
    if (lower.contains('meeting') || lower.contains('appointment')) {
      if (matchedContactName != null) {
        normalizedTitle = 'Meeting with $matchedContactName';
      } else if (locationSnippet != null) {
        normalizedTitle = 'Meeting at $locationSnippet';
      } else {
        normalizedTitle = 'Meeting';
      }
    } else {
      // Split clauses and isolate action
      final clauses = cleanedText.split(RegExp(r'[.!?\n]+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      String candidateText = cleanedText;
      for (final clause in clauses) {
        final cLower = clause.toLowerCase();
        if (cLower.startsWith("what's up") ||
            cLower.startsWith("hey man") ||
            cLower.startsWith("hello") ||
            cLower.startsWith("hi ") ||
            cLower.startsWith("yeah man") ||
            cLower.startsWith("it's all good") ||
            cLower.startsWith("it's okay") ||
            cLower.startsWith("not sure") ||
            cLower.startsWith("maybe") ||
            cLower == "okay" ||
            cLower == "cool") {
          continue;
        }
        if (cLower.contains('call') ||
            cLower.contains('send') ||
            cLower.contains('deliver') ||
            cLower.contains('email') ||
            cLower.contains('prepare') ||
            cLower.contains('review') ||
            cLower.contains('finish') ||
            cLower.contains('schedule') ||
            cLower.contains('promise') ||
            cLower.contains('revised') ||
            cLower.contains('quotation') ||
            cLower.contains('invoice') ||
            cLower.contains('contract')) {
          candidateText = clause;
          break;
        }
      }

      var cleanTitle = candidateText.trim();
      cleanTitle = cleanTitle.replaceAll(
        RegExp(r"^(okay, so let's see|okay so let's see|let's see|okay|so)\s*,?\s*", caseSensitive: false),
        '',
      );
      cleanTitle = cleanTitle.replaceAll(
        RegExp(r"^(i have got|i have|i've|i got)\s+(a\s+)?", caseSensitive: false),
        '',
      );
      cleanTitle = cleanTitle.replaceAll(
        RegExp(r"^(i will|i'll|i promise to|i promised to|i promised|i need to|i have to)\s+", caseSensitive: false),
        '',
      );
      cleanTitle = cleanTitle.replaceAll(
        RegExp(r"^(he said he would|they promised to|he promised to|she promised to)\s+", caseSensitive: false),
        '',
      );
      if (cleanTitle.isNotEmpty) {
        cleanTitle = cleanTitle[0].toUpperCase() + cleanTitle.substring(1);
      }
      normalizedTitle = cleanTitle.length > 60
          ? '${cleanTitle.substring(0, 57)}...'
          : cleanTitle;
    }

    // Extract commitments
    commitments.add(
      ExtractedCommitment(
        title: normalizedTitle,
        description: 'Auto-extracted from note: "$text"',
        type: type,
        dueDate: dueDate,
        contactName: matchedContactName,
        matchedContactId: matchedContactId,
        confidence: 0.95,
        sourceExcerpt: text,
      ),
    );

    // Auto-suggest reminder if deadline exists
    if (dueDate != null) {
      reminders.add(
        ExtractedReminder(
          title: 'Reminder: $normalizedTitle',
          remindAt: dueDate.subtract(const Duration(hours: 2)),
          confidence: 0.95,
          sourceExcerpt: text,
        ),
      );
    }

    return AiExtractionResult(
      rawInput: text,
      summary: 'Extracted commitments and follow-ups from your input.',
      contacts: contacts,
      commitments: commitments,
      reminders: reminders,
    );
  }
}

AiExtractionResult _parseExtractionJson(
  String rawInput,
  Map<String, dynamic> json,
  List<Contact> existingContacts,
) {
  final summary = json['summary'] as String? ?? 'Memory processed';
  final rawContacts = json['contacts'] as List? ?? [];
  final rawCommitments = json['commitments'] as List? ?? [];
  final rawReminders = json['reminders'] as List? ?? [];

  final contacts = rawContacts
      .map((c) => ExtractedContact.fromJson(c as Map<String, dynamic>))
      .toList();

  // Match contacts against database
  for (final ec in contacts) {
    for (final existing in existingContacts) {
      if (existing.name.toLowerCase().trim() == ec.name.toLowerCase().trim()) {
        ec.matchedExistingContactId = existing.id;
        break;
      }
    }
  }

  final commitments = rawCommitments.map((c) {
    final item = ExtractedCommitment.fromJson(c as Map<String, dynamic>);
    if (item.contactName != null) {
      for (final existing in existingContacts) {
        if (existing.name.toLowerCase().contains(item.contactName!.toLowerCase())) {
          item.matchedContactId = existing.id;
          break;
        }
      }
    }
    return item;
  }).toList();

  final reminders = rawReminders
      .map((r) => ExtractedReminder.fromJson(r as Map<String, dynamic>))
      .toList();

  return AiExtractionResult(
    rawInput: rawInput,
    summary: summary,
    contacts: contacts,
    commitments: commitments,
    reminders: reminders,
  );
}
