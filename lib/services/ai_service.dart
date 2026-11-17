import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_service.dart';
import '../models/ai_extraction_result.dart';
import '../models/contact.dart';
import '../models/commitment.dart';

/// Converts Bangla numerals to ASCII numerals.
String _bnDigitsToAscii(String input) {
  const banglaDigits = '০১২৩৪৫৬৭৮৯';
  const englishDigits = '0123456789';

  return input.split('').map((char) {
    final index = banglaDigits.indexOf(char);
    return index == -1 ? char : englishDigits[index];
  }).join();
}

/// Checks whether a word or phrase exists as a separate word.
bool _hasWord(String text, String word) {
  final escaped = RegExp.escape(word.toLowerCase());
  return RegExp(
    r'(?<![\p{L}\p{N}])' + escaped + r'(?![\p{L}\p{N}])',
    caseSensitive: false,
    unicode: true,
  ).hasMatch(text.toLowerCase());
}

/// Converts a Bangla/Banglish hour expression into 24-hour time.
int _bnHour(int hour, String period) {
  final p = period.toLowerCase();

  if (p.contains('রাত') ||
      p.contains('রাতে') ||
      p.contains('night') ||
      p.contains('pm')) {
    if (hour < 12) return hour + 12;
    return hour;
  }

  if (p.contains('বিকাল') ||
      p.contains('বিকেলে') ||
      p.contains('সন্ধ্যা') ||
      p.contains('evening') ||
      p.contains('afternoon')) {
    if (hour < 12) return hour + 12;
    return hour;
  }

  if (p.contains('সকাল') ||
      p.contains('সকালে') ||
      p.contains('morning') ||
      p.contains('am')) {
    if (hour == 12) return 0;
    return hour;
  }

  if (p.contains('দুপুর') || p.contains('দুপুরে')) {
    if (hour < 12) return hour + 12;
    return hour;
  }

  return hour;
}

/// Supported AI Providers with generous or 100% free tiers.
enum AiProvider {
  gemini('Google Gemini', 'gemini-2.0-flash', 'Free tier via Google AI Studio'),
  groq(
    'Groq Cloud',
    'llama-3.3-70b-versatile',
    'Free tier via console.groq.com',
  );

  final String label;
  final String defaultModel;
  final String description;

  const AiProvider(this.label, this.defaultModel, this.description);
}

/// Abstract AI interface for memory extraction.
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

    if (key.isEmpty) {
      throw Exception('API key cannot be empty');
    }

    if (provider == AiProvider.groq || key.startsWith('gsk_')) {
      if (!key.startsWith('gsk_')) {
        if (key.startsWith('AIza')) {
          throw Exception(
            'This looks like a Google Gemini key, not a Groq key. '
            'Switch provider or get a Groq key from https://console.groq.com/keys',
          );
        }

        throw Exception(
          'Invalid Groq key format. Groq API keys must begin with gsk_.',
        );
      }

      final modelsUrl = Uri.parse('https://api.groq.com/openai/v1/models');

      final modelsRes = await http
          .get(
            modelsUrl,
            headers: {
              'Authorization': 'Bearer $key',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (modelsRes.statusCode == 200) {
        try {
          final data = jsonDecode(modelsRes.body) as Map<String, dynamic>;

          final list =
              (data['data'] as List?)
                  ?.map((m) => m['id'] as String)
                  .where(
                    (id) => !id.contains('whisper') && !id.contains('guard'),
                  )
                  .toList() ??
              [];

          final activeModel = list.isNotEmpty ? list.first : 'LPU';

          return 'Groq Cloud connected successfully! '
              '(Active Model: $activeModel)';
        } catch (_) {
          return 'Groq Cloud connected successfully!';
        }
      }

      throw Exception(
        'Groq error (${modelsRes.statusCode}): ${modelsRes.body}',
      );
    }

    if (!key.startsWith('AIza')) {
      throw Exception(
        'This does not look like a Gemini API key. '
        'Get a key from https://aistudio.google.com',
      );
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/'
      'models/gemini-2.0-flash:generateContent',
    );

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json', 'x-goog-api-key': key},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': 'ping'},
            ],
          },
        ],
      }),
    );

    if (res.statusCode == 200) {
      return 'Google Gemini 2.0 Flash connected successfully!';
    }

    throw Exception('Gemini error (${res.statusCode}): ${res.body}');
  }
}

/// Groq Cloud API implementation.
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
        .map(
          (c) =>
              '{"id": ${c.id}, "name": "${c.name}", '
              '"company": "${c.company ?? ''}"}',
        )
        .join(',\n');

    final systemInstruction = _buildExtractionPrompt(
      now: now,
      knownContactsList: knownContactsList,
    );

    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    for (final model in _candidateModels) {
      try {
        final response = await http
            .post(
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
            )
            .timeout(const Duration(seconds: 45));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;

          final choices = data['choices'] as List?;

          if (choices != null && choices.isNotEmpty) {
            final rawJsonText = choices[0]['message']['content'] as String;

            final parsed = jsonDecode(rawJsonText) as Map<String, dynamic>;

            return _parseExtractionJson(text, parsed, existingContacts);
          }
        } else if (response.statusCode == 404) {
          continue;
        } else {
          continue;
        }
      } catch (_) {
        continue;
      }
    }

    return MockAiService().extract(
      text: text,
      existingContacts: existingContacts,
    );
  }
}

/// Google Gemini API implementation.
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
        .map(
          (c) =>
              '{"id": ${c.id}, "name": "${c.name}", '
              '"company": "${c.company ?? ''}"}',
        )
        .join(',\n');

    final systemInstruction = _buildExtractionPrompt(
      now: now,
      knownContactsList: knownContactsList,
    );

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/'
      'models/$_model:generateContent',
    );

    try {
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': '$systemInstruction\n\nUSER INPUT:\n$text'},
                  ],
                },
              ],
              'generationConfig': {
                'responseMimeType': 'application/json',
                'temperature': 0.1,
              },
            }),
          )
          .timeout(const Duration(seconds: 10));

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

    return MockAiService().extract(
      text: text,
      existingContacts: existingContacts,
    );
  }
}

/// Shared extraction prompt for Groq and Gemini.
String _buildExtractionPrompt({
  required DateTime now,
  required String knownContactsList,
}) {
  return '''
You are Dummy., the user's personal AI companion and executive memory assistant.

Analyze user notes or conversation transcripts to extract commitments, promises, contacts, reminders, and durable memories.

1. CURRENT TIME:
Current timestamp: ${now.toIso8601String()}.
Use this as the reference for all relative dates.

2. EXISTING CONTACTS:
[$knownContactsList]
If a mentioned person closely matches an existing contact, reference that contact.

3. EXECUTIVE ASSISTANT PERSPECTIVE:
You work FOR the user.
Never use first-person pronouns such as "I", "I will", "I have", "I've", or "we" in commitment titles.

Examples:
- "I've a meeting at 10:30 with Raju" -> "Meeting with Raju at 10:30 AM"
- "I promised to send the quotation to Karim" -> "Send quotation to Karim"
- "Rahim promised he will deliver the draft by Friday" -> "Receive draft from Rahim"
- "I need to follow up with Apex Corp next week" -> "Follow up with Apex Corp"

4. SPEECH SELF-CORRECTIONS:
Users may correct themselves while speaking.
- "Meeting tomorrow, not tomorrow, maybe 16th November" means November 16.
- "Meeting with Rahim, sorry Raju" means Raju.
- Ignore retracted phrases.
- Never interpret "maybe" as the month "May".
- Remove greetings and filler.

5. MULTI-PARTY CONVERSATIONS:
Identify distinct participants in contacts.
If a real name is unavailable, preserve the exact participant tag, such as "Person D" or "Speaker 2".
Set is_unresolved to true for unknown participants.
Include detected_context describing what they said or their role.
Link commitments to the correct participant through contact_name.

6. CONVERSATIONAL NOISE:
Discard greetings, small talk, rhetorical questions, and filler.
Do not turn casual conversation into commitments.
If no actionable commitment exists, return an empty commitments array.

7. COMMITMENT TYPES:
- promiseMade: Something the USER promised to do.
- promiseReceived: Something someone else promised to do for the user.
- followUp: Something the user needs to follow up on.
- task: A general actionable task.

8. PERSONAL AND BUSINESS MEMORIES:
Extract durable facts, preferences, project context, decisions, and working habits.
Examples:
- "Karim prefers dark roast coffee without sugar" -> preference.
- "Our mobile app MVP target is the end of next month" -> project.
- "We decided to use SQLite" -> decision.

Valid categories:
fact, preference, project, experience, goal, decision, workingHabit, relationship.

9. DATE AND TIME INTERPRETATION:
Interpret English, Bangla, and Banglish dates and times.

Examples:
- tomorrow / আগামীকাল / kal -> next calendar day
- day after tomorrow / পরশু -> two calendar days later
- today / আজ -> current calendar day
- next Monday / আগামী সোমবার -> next Monday
- next week / আগামী সপ্তাহে -> seven days later unless context specifies otherwise
- সকাল ১০টা / shokal 10ta -> 10:00 AM
- দুপুর ২টা / dupur 2ta -> 2:00 PM
- বিকাল ৩টা / bikal 3ta -> 3:00 PM
- সন্ধ্যা ৭টা / shondha 7ta -> 7:00 PM
- রাত ৮টা / rat 8ta -> 8:00 PM
- ১৬ নভেম্বর / 16 November -> November 16

Bangla numerals must be interpreted correctly.
Return exact ISO-8601 dates and times.
If the date or time is uncertain, do not invent precision. Use null where appropriate.

10. OUTPUT:
Return strictly valid JSON with this structure:

{
  "summary": "Brief one-sentence recap",
  "contacts": [
    {
      "name": "Full Name or Person A",
      "placeholder_tag": "Person A or null",
      "is_unresolved": false,
      "detected_context": "Context about this person",
      "company": "Company or null",
      "role": "Role or null",
      "notes": "Additional context or null"
    }
  ],
  "commitments": [
    {
      "title": "Normalized actionable title",
      "description": "Additional details or null",
      "type": "promiseMade | promiseReceived | followUp | task",
      "due_date": "YYYY-MM-DDTHH:mm:ss or null",
      "contact_name": "Related person or null",
      "confidence": 0.95,
      "source_excerpt": "Verbatim text span"
    }
  ],
  "reminders": [
    {
      "title": "Reminder title",
      "remind_at": "YYYY-MM-DDTHH:mm:ss",
      "is_recurring": false,
      "recurring_rule": null,
      "confidence": 0.95,
      "source_excerpt": "Verbatim text span"
    }
  ],
  "memories": [
    {
      "content": "Normalized memory",
      "category": "fact | preference | project | experience | goal | decision | workingHabit | relationship",
      "contact_name": "Related person or null",
      "confidence": 0.95
    }
  ]
}
''';
}

/// Offline rule-based fallback.
class MockAiService implements AiService {
  @override
  Future<AiExtractionResult> extract({
    required String text,
    List<Contact> existingContacts = const [],
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    var cleanedText = text.trim().replaceFirst(
      RegExp(
        r'^(hi|hello|hey|good morning|good afternoon|good evening)\s*[,!:]*\s*',
        caseSensitive: false,
      ),
      '',
    );

    cleanedText = _bnDigitsToAscii(cleanedText);

    final lower = cleanedText.toLowerCase();

    final contacts = <ExtractedContact>[];
    final commitments = <ExtractedCommitment>[];
    final reminders = <ExtractedReminder>[];

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

    CommitmentType type = CommitmentType.task;

    if (lower.contains('i promised') ||
        lower.contains("i'll") ||
        lower.contains('i will') ||
        lower.contains('i commit') ||
        lower.contains('আমি কথা দিয়েছি') ||
        lower.contains('আমি পাঠাব')) {
      type = CommitmentType.promiseMade;
    } else if (lower.contains('they promised') ||
        lower.contains('he said he would') ||
        lower.contains('she said she would') ||
        lower.contains('promised to send')) {
      type = CommitmentType.promiseReceived;
    } else if (lower.contains('follow up') || lower.contains('follow-up')) {
      type = CommitmentType.followUp;
    }

    // -------------------------------------------------
    // DATE AND TIME EXTRACTION
    // -------------------------------------------------

    DateTime? dueDate;
    final now = DateTime.now();

    int targetHour = 15;
    int targetMinute = 0;

    // English time: 3 PM, 10:30 AM, 3 p.m.
    final englishTimeMatch = RegExp(
      r'\b(\d{1,2})(?::(\d{2}))?\s*(a\.m\.|p\.m\.|am|pm)(?![a-z])',
      caseSensitive: false,
    ).firstMatch(lower);

    if (englishTimeMatch != null) {
      var hour = int.parse(englishTimeMatch.group(1)!);
      final minute = int.tryParse(englishTimeMatch.group(2) ?? '0') ?? 0;

      final period = englishTimeMatch
          .group(3)!
          .toLowerCase()
          .replaceAll('.', '');

      if (period == 'pm' && hour < 12) hour += 12;
      if (period == 'am' && hour == 12) hour = 0;

      if (hour >= 0 && hour <= 23 && minute <= 59) {
        targetHour = hour;
        targetMinute = minute;
      }
    } else {
      // Bangla/Banglish time expressions.
      final banglaTimeMatch = RegExp(
        r'(সকাল|সকালে|দুপুর|দুপুরে|বিকাল|বিকালে|সন্ধ্যা|সন্ধ্যায়|রাত|রাতে|shokal|sokal|dupur|bikal|bikেলে|shondha|rat)\s*(\d{1,2})(?::(\d{2}))?\s*(টা|টায়|টার|ta|tay)?',
        caseSensitive: false,
      ).firstMatch(lower);

      if (banglaTimeMatch != null) {
        final period = banglaTimeMatch.group(1)!;
        final hour = int.parse(banglaTimeMatch.group(2)!);
        final minute = int.tryParse(banglaTimeMatch.group(3) ?? '0') ?? 0;

        final convertedHour = _bnHour(hour, period);

        if (convertedHour >= 0 && convertedHour <= 23 && minute <= 59) {
          targetHour = convertedHour;
          targetMinute = minute;
        }
      } else {
        // Bangla/Banglish time written as "3টায়", "5tay".
        final simpleBanglaTime = RegExp(
          r'\b(\d{1,2})(?::(\d{2}))?\s*(টা|টায়|টার|ta|tay)\b',
          caseSensitive: false,
        ).firstMatch(lower);

        if (simpleBanglaTime != null) {
          final hour = int.parse(simpleBanglaTime.group(1)!);
          final minute = int.tryParse(simpleBanglaTime.group(2) ?? '0') ?? 0;

          if (hour >= 0 && hour <= 23 && minute <= 59) {
            targetHour = hour;
            targetMinute = minute;
          }
        }
      }
    }

    final monthMap = <String, int>{
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,

      // Bangla month names.
      'জানুয়ারি': 1,
      'জানুয়ারি': 1,
      'ফেব্রুয়ারি': 2,
      'ফেব্রুয়ারি': 2,
      'মার্চ': 3,
      'এপ্রিল': 4,
      'মে': 5,
      'জুন': 6,
      'জুলাই': 7,
      'আগস্ট': 8,
      'সেপ্টেম্বর': 9,
      'অক্টোবর': 10,
      'নভেম্বর': 11,
      'ডিসেম্বর': 12,
    };

    final monthPattern = monthMap.keys.map(RegExp.escape).join('|');

    final dmRegex = RegExp(
      r'\b(\d{1,2})(?:st|nd|rd|th)?\s*(?:of\s+)?(' + monthPattern + r')\b',
      caseSensitive: false,
      unicode: true,
    );

    final mdRegex = RegExp(
      r'(' + monthPattern + r')\s*(\d{1,2})(?:st|nd|rd|th)?\b',
      caseSensitive: false,
      unicode: true,
    );

    final dmMatch = dmRegex.firstMatch(lower);
    final mdMatch = mdRegex.firstMatch(lower);

    DateTime? makeValidDate(int year, int month, int day) {
      final candidate = DateTime(year, month, day, targetHour, targetMinute);

      if (candidate.year != year ||
          candidate.month != month ||
          candidate.day != day) {
        return null;
      }

      return candidate;
    }

    if (dmMatch != null) {
      final day = int.parse(dmMatch.group(1)!);
      final month = monthMap[dmMatch.group(2)!];

      if (month != null && day >= 1 && day <= 31) {
        var year = now.year;
        var candidate = makeValidDate(year, month, day);

        if (candidate != null &&
            candidate.isBefore(DateTime(now.year, now.month, now.day))) {
          year++;
          candidate = makeValidDate(year, month, day);
        }

        dueDate = candidate;
      }
    } else if (mdMatch != null) {
      final month = monthMap[mdMatch.group(1)!];
      final day = int.parse(mdMatch.group(2)!);

      if (month != null && day >= 1 && day <= 31) {
        var year = now.year;
        var candidate = makeValidDate(year, month, day);

        if (candidate != null &&
            candidate.isBefore(DateTime(now.year, now.month, now.day))) {
          year++;
          candidate = makeValidDate(year, month, day);
        }

        dueDate = candidate;
      }
    }

    // Relative dates: detect negation before positive expressions.
    final isTomorrowNegated =
        lower.contains('not tomorrow') ||
        lower.contains('no tomorrow') ||
        lower.contains('cancel tomorrow') ||
        lower.contains('tomorrow না') ||
        lower.contains('কাল না');

    final isDayAfterTomorrowNegated =
        lower.contains('not day after tomorrow') || lower.contains('পরশু না');

    if (dueDate == null) {
      if ((lower.contains('day after tomorrow') ||
              lower.contains('পরশু') ||
              lower.contains('porshu')) &&
          !isDayAfterTomorrowNegated) {
        dueDate = DateTime(
          now.year,
          now.month,
          now.day + 2,
          targetHour,
          targetMinute,
        );
      } else if ((lower.contains('tomorrow') ||
              lower.contains('আগামীকাল') ||
              lower.contains('কাল') ||
              _hasWord(lower, 'kal')) &&
          !isTomorrowNegated) {
        dueDate = DateTime(
          now.year,
          now.month,
          now.day + 1,
          targetHour,
          targetMinute,
        );
      } else if (lower.contains('today') ||
          lower.contains('আজ') ||
          _hasWord(lower, 'aj')) {
        dueDate = DateTime(
          now.year,
          now.month,
          now.day,
          targetHour,
          targetMinute,
        );
      } else if (lower.contains('next week') ||
          lower.contains('আগামী সপ্তাহ') ||
          lower.contains('agami shoptaho')) {
        dueDate = DateTime(
          now.year,
          now.month,
          now.day + 7,
          targetHour,
          targetMinute,
        );
      } else if (lower.contains('friday') ||
          lower.contains('শুক্রবার') ||
          lower.contains('shukrobar')) {
        final daysUntilFriday = (DateTime.friday - now.weekday) % 7;

        dueDate = DateTime(
          now.year,
          now.month,
          now.day + (daysUntilFriday == 0 ? 7 : daysUntilFriday),
          targetHour,
          targetMinute,
        );
      } else if (lower.contains('monday') ||
          lower.contains('সোমবার') ||
          lower.contains('shombar')) {
        final daysUntilMonday = (DateTime.monday - now.weekday) % 7;

        dueDate = DateTime(
          now.year,
          now.month,
          now.day + (daysUntilMonday == 0 ? 7 : daysUntilMonday),
          targetHour,
          targetMinute,
        );
      } else {
        final inDaysMatch = RegExp(r'in\s+(\d+)\s+days?').firstMatch(lower);

        final banglaDaysMatch = RegExp(
          r'(\d+)\s*(দিন|diner|din)\s*(পরে|por)',
          caseSensitive: false,
        ).firstMatch(lower);

        final days = inDaysMatch != null
            ? int.tryParse(inDaysMatch.group(1)!)
            : banglaDaysMatch != null
            ? int.tryParse(banglaDaysMatch.group(1)!)
            : null;

        if (days != null && days >= 0 && days <= 365) {
          dueDate = DateTime(
            now.year,
            now.month,
            now.day + days,
            targetHour,
            targetMinute,
          );
        }
      }
    }

    // -------------------------------------------------
    // CONTACT EXTRACTION
    // -------------------------------------------------

    final participantRegex = RegExp(
      r'\b(Person\s+[A-Za-z0-9]|Speaker\s+[A-Za-z0-9])\b',
      caseSensitive: false,
    );

    final participantMatches = participantRegex.allMatches(cleanedText);

    final seenTags = <String>{};

    for (final m in participantMatches) {
      final normalizedTag = m.group(0)!.trim();

      if (seenTags.contains(normalizedTag.toLowerCase())) {
        continue;
      }

      seenTags.add(normalizedTag.toLowerCase());

      String? contextSnippet;
      final sentences = cleanedText.split(RegExp(r'[.!?\n]+'));

      for (final sentence in sentences) {
        if (sentence.toLowerCase().contains(normalizedTag.toLowerCase())) {
          contextSnippet = sentence.trim();
          break;
        }
      }

      contacts.add(
        ExtractedContact(
          name: normalizedTag,
          placeholderTag: normalizedTag,
          isUnresolved: true,
          detectedContext: contextSnippet ?? 'Mentioned in group discussion',
          role: 'Discussion Participant',
        ),
      );
    }

    if (contacts.isEmpty) {
      final nameMatch = RegExp(
        r'\b(?:call with|meeting with|spoke with|talked with|promised|with)\s+([A-Z][a-zA-Z]+)(?:\s+(?:from|at)\s+([A-Z][a-zA-Z\s]+))?',
        caseSensitive: false,
      ).firstMatch(cleanedText);

      if (nameMatch != null) {
        final extractedName = nameMatch.group(1)!.trim();
        final extractedCompany = nameMatch.group(2)?.trim();

        if (![
          'person',
          'speaker',
          'someone',
          'him',
          'her',
          'them',
          'the',
        ].contains(extractedName.toLowerCase())) {
          matchedContactName ??= extractedName;

          contacts.add(
            ExtractedContact(
              name: extractedName,
              company: extractedCompany,
              isUnresolved: false,
              detectedContext:
                  'Mentioned in note: ${cleanedText.length > 50 ? '${cleanedText.substring(0, 50)}...' : cleanedText}',
            ),
          );
        }
      }
    }

    // -------------------------------------------------
    // LOCATION EXTRACTION
    // -------------------------------------------------

    String? locationSnippet;

    final locMatch = RegExp(
      r'\bat\s+(my\s+office|the\s+office|office|[A-Z][a-zA-Z\s]+(?:Office|Center|Hub|Room|Cafe|HQ))\b',
      caseSensitive: false,
    ).firstMatch(cleanedText);

    if (locMatch != null) {
      locationSnippet = locMatch
          .group(1)!
          .trim()
          .replaceAll(RegExp(r'^my\s+', caseSensitive: false), '');
    }

    // -------------------------------------------------
    // COMMITMENT TITLE NORMALIZATION
    // -------------------------------------------------

    String normalizedTitle;

    if (lower.contains('meeting') ||
        lower.contains('appointment') ||
        lower.contains('মিটিং') ||
        lower.contains('সাক্ষাৎ')) {
      if (matchedContactName != null) {
        normalizedTitle = 'Meeting with $matchedContactName';
      } else if (locationSnippet != null) {
        normalizedTitle = 'Meeting at $locationSnippet';
      } else {
        normalizedTitle = 'Meeting';
      }
    } else {
      final clauses = cleanedText
          .split(RegExp(r'[.!?\n]+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      String candidateText = cleanedText;

      for (final clause in clauses) {
        final cLower = clause.toLowerCase();

        if (cLower.startsWith("what's up") ||
            cLower.startsWith('hey man') ||
            cLower.startsWith('hello') ||
            cLower.startsWith('hi ') ||
            cLower.startsWith('yeah man') ||
            cLower.startsWith("it's all good") ||
            cLower.startsWith("it's okay") ||
            cLower.startsWith('not sure') ||
            cLower.startsWith('maybe') ||
            cLower == 'okay' ||
            cLower == 'cool') {
          continue;
        }

        if ([
          'call',
          'send',
          'deliver',
          'email',
          'prepare',
          'review',
          'finish',
          'schedule',
          'promise',
          'revised',
          'quotation',
          'invoice',
          'contract',
          'follow up',
          'submit',
        ].any(cLower.contains)) {
          candidateText = clause;
          break;
        }
      }

      var cleanTitle = candidateText.trim();

      cleanTitle = cleanTitle.replaceAll(
        RegExp(
          r"^(okay, so let's see|okay so let's see|let's see|okay|so)\s*,?\s*",
          caseSensitive: false,
        ),
        '',
      );

      cleanTitle = cleanTitle.replaceAll(
        RegExp(
          r"^(i have got|i have|i've|i got)\s+(a\s+)?",
          caseSensitive: false,
        ),
        '',
      );

      cleanTitle = cleanTitle.replaceAll(
        RegExp(
          r"^(i will|i'll|i promise to|i promised to|i promised|i need to|i have to)\s+",
          caseSensitive: false,
        ),
        '',
      );

      cleanTitle = cleanTitle.replaceAll(
        RegExp(
          r"^(he said he would|they promised to|he promised to|she promised to)\s+",
          caseSensitive: false,
        ),
        '',
      );

      if (cleanTitle.isNotEmpty) {
        cleanTitle = cleanTitle[0].toUpperCase() + cleanTitle.substring(1);
      }

      normalizedTitle = cleanTitle.length > 60
          ? '${cleanTitle.substring(0, 57)}...'
          : cleanTitle;
    }

    // -------------------------------------------------
    // MEMORY EXTRACTION
    // -------------------------------------------------

    final memories = <ExtractedMemory>[];

    final sentences = cleanedText
        .split(RegExp(r'[.!?;]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    for (final sentence in sentences) {
      final sLower = sentence.toLowerCase();

      if (sLower.contains('prefers ') ||
          sLower.contains('likes ') ||
          sLower.contains('dislikes ') ||
          sLower.contains('favorite ') ||
          sLower.contains('favourite ') ||
          sLower.contains('fond of ') ||
          sLower.contains('loves ') ||
          sLower.contains('hates ') ||
          sLower.contains('enjoys ')) {
        memories.add(
          ExtractedMemory(
            content: sentence,
            category: 'preference',
            contactName: matchedContactName,
            matchedContactId: matchedContactId,
            confidence: 0.95,
            sourceExcerpt: sentence,
          ),
        );
      } else if (sLower.contains('project ') ||
          sLower.contains('launch ') ||
          sLower.contains('milestone ') ||
          sLower.contains('sprint ') ||
          sLower.contains('target ') ||
          sLower.contains('release ') ||
          sLower.contains('budget ') ||
          sLower.contains('roadmap ')) {
        memories.add(
          ExtractedMemory(
            content: sentence,
            category: 'project',
            contactName: matchedContactName,
            matchedContactId: matchedContactId,
            confidence: 0.95,
            sourceExcerpt: sentence,
          ),
        );
      } else if (sLower.contains('decided to ') ||
          sLower.contains('agreed to ') ||
          sLower.contains('decision:') ||
          sLower.contains('agreed on ') ||
          sLower.contains('we decided')) {
        memories.add(
          ExtractedMemory(
            content: sentence,
            category: 'decision',
            contactName: matchedContactName,
            matchedContactId: matchedContactId,
            confidence: 0.95,
            sourceExcerpt: sentence,
          ),
        );
      } else if (sLower.contains('working hours') ||
          sLower.contains('works late') ||
          sLower.contains('routine') ||
          sLower.contains('usually works') ||
          sLower.contains('daily habit') ||
          sLower.contains('night owl') ||
          sLower.contains('early bird')) {
        memories.add(
          ExtractedMemory(
            content: sentence,
            category: 'workingHabit',
            contactName: matchedContactName,
            matchedContactId: matchedContactId,
            confidence: 0.95,
            sourceExcerpt: sentence,
          ),
        );
      } else if (sLower.contains('lives in ') ||
          sLower.contains('based in ') ||
          sLower.contains('born in ') ||
          sLower.contains('graduated from ') ||
          sLower.contains('wife ') ||
          sLower.contains('husband ') ||
          sLower.contains('brother ') ||
          sLower.contains('sister ') ||
          sLower.contains('works as ') ||
          sLower.contains('speaks ')) {
        memories.add(
          ExtractedMemory(
            content: sentence,
            category: 'fact',
            contactName: matchedContactName,
            matchedContactId: matchedContactId,
            confidence: 0.95,
            sourceExcerpt: sentence,
          ),
        );
      }
    }

    // -------------------------------------------------
    // ACTIONABLE COMMITMENT DETECTION
    // -------------------------------------------------

    final hasActionVerb =
        lower.contains('call') ||
        lower.contains('send') ||
        lower.contains('deliver') ||
        lower.contains('email') ||
        lower.contains('prepare') ||
        lower.contains('review') ||
        lower.contains('finish') ||
        lower.contains('schedule') ||
        lower.contains('meeting') ||
        lower.contains('appointment') ||
        lower.contains('promise') ||
        lower.contains('revised') ||
        lower.contains('quotation') ||
        lower.contains('invoice') ||
        lower.contains('contract') ||
        lower.contains('follow up') ||
        lower.contains('follow-up') ||
        lower.contains('submit') ||
        lower.contains('মিটিং') ||
        lower.contains('পাঠাব') ||
        lower.contains('জমা') ||
        lower.contains('দেব') ||
        lower.contains('করব') ||
        lower.contains('করতে হবে') ||
        dueDate != null;

    // IMPORTANT:
    // Do not create a commitment merely because no memory was detected.
    // Casual conversation must not become a fake task.
    if (hasActionVerb) {
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
    }

    final summaryText = memories.isNotEmpty && commitments.isEmpty
        ? 'Captured personal memory and contextual facts.'
        : commitments.isNotEmpty
        ? 'Extracted commitments and follow-ups from your input.'
        : 'No actionable commitments detected.';

    return AiExtractionResult(
      rawInput: text,
      summary: summaryText,
      contacts: contacts,
      commitments: commitments,
      reminders: reminders,
      memories: memories,
    );
  }
}

/// Parses the JSON returned by Gemini or Groq.
AiExtractionResult _parseExtractionJson(
  String rawInput,
  Map<String, dynamic> json,
  List<Contact> existingContacts,
) {
  final summary = json['summary'] as String? ?? 'Memory processed';

  final rawContacts = json['contacts'] as List? ?? [];
  final rawCommitments = json['commitments'] as List? ?? [];
  final rawReminders = json['reminders'] as List? ?? [];
  final rawMemories = json['memories'] as List? ?? [];

  final contacts = rawContacts
      .map((c) => ExtractedContact.fromJson(c as Map<String, dynamic>))
      .toList();

  for (final extractedContact in contacts) {
    for (final existing in existingContacts) {
      if (existing.name.toLowerCase().trim() ==
          extractedContact.name.toLowerCase().trim()) {
        extractedContact.matchedExistingContactId = existing.id;
        break;
      }
    }
  }

  final commitments = rawCommitments.map((c) {
    final item = ExtractedCommitment.fromJson(c as Map<String, dynamic>);

    if (item.contactName != null) {
      for (final existing in existingContacts) {
        if (existing.name.toLowerCase().contains(
          item.contactName!.toLowerCase(),
        )) {
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

  final memories = rawMemories.map((m) {
    final item = ExtractedMemory.fromJson(m as Map<String, dynamic>);

    if (item.contactName != null) {
      for (final existing in existingContacts) {
        if (existing.name.toLowerCase().contains(
          item.contactName!.toLowerCase(),
        )) {
          item.matchedContactId = existing.id;
          break;
        }
      }
    }

    return item;
  }).toList();

  return AiExtractionResult(
    rawInput: rawInput,
    summary: summary,
    contacts: contacts,
    commitments: commitments,
    reminders: reminders,
    memories: memories,
  );
}
