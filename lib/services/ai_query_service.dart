import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_service.dart';
import 'ai_service.dart';
import '../models/assistant_settings.dart';

/// The answer returned by the Assistant Query Engine.
class AssistantQueryResponse {
  final String answer;
  final List<String> sourceReferences;
  final List<String> suggestedNextActions;

  AssistantQueryResponse({
    required this.answer,
    this.sourceReferences = const [],
    this.suggestedNextActions = const [],
  });
}

/// Service that answers questions about the user's personal business memory
/// using local database grounding (RAG).
class AiQueryService {
  final _db = DatabaseService();

  Future<AssistantQueryResponse> queryMemory(
    String userQuestion, {
    List<Map<String, String>> conversationHistory = const [],
  }) async {
    final ragContext = await _db.buildRagContextSummary();
    final isMock = await AiServiceFactory.isMockMode();
    final apiKey = await AiServiceFactory.getApiKey();
    final settings = await _db.getAssistantSettings();

    if (isMock || apiKey == null || apiKey.isEmpty) {
      return _queryOfflineRuleEngine(
        userQuestion,
        ragContext,
        settings,
        conversationHistory: conversationHistory,
      );
    }

    final provider = await AiServiceFactory.getProvider();
    final effectiveProvider = (apiKey.startsWith('gsk_') || provider == AiProvider.groq)
        ? AiProvider.groq
        : AiProvider.gemini;

    if (effectiveProvider == AiProvider.groq) {
      try {
        return await _queryGroqRAG(
          userQuestion,
          ragContext,
          apiKey,
          settings,
          conversationHistory: conversationHistory,
        );
      } catch (_) {
        return _queryOfflineRuleEngine(
          userQuestion,
          ragContext,
          settings,
          conversationHistory: conversationHistory,
        );
      }
    }

    try {
      return await _queryGeminiRAG(
        userQuestion,
        ragContext,
        apiKey,
        settings,
        conversationHistory: conversationHistory,
      );
    } catch (_) {
      // Fallback to offline rule engine if API call fails
      return _queryOfflineRuleEngine(
        userQuestion,
        ragContext,
        settings,
        conversationHistory: conversationHistory,
      );
    }
  }

  Future<AssistantQueryResponse> _queryGeminiRAG(
    String question,
    String context,
    String apiKey,
    AssistantSettings settings, {
    List<Map<String, String>> conversationHistory = const [],
  }) async {
    const model = 'gemini-2.0-flash';
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );

    final systemPrompt = '''
You are RemembrAI, the user's executive personal business memory assistant.
Answer the user's question accurately using ONLY the verified memory context provided below.

GROUNDED BUSINESS MEMORY CONTEXT:
$context

${settings.toSystemPromptAddition()}

RULES:
1. EXECUTIVE ASSISTANT VOICE: Address the user respectfully as their executive client (e.g. "You have a meeting with Raju at 10:30 AM", "You promised Karim..."). Never parrot raw first-person quotes like "You have a commitment 'I have a meeting'".
2. Answer factually based on the context and conversation history. Never invent promises or meetings.
3. If information is not in memory, honestly state: "I don't have a record of that in your memory yet."
4. Highlight pending deadlines and commitments clearly.
4. Support multi-turn questions (e.g. "What about him?", "Draft a follow up to her").
5. Return strictly JSON in this format:
{
  "answer": "Direct, professional, bulleted or summarized answer",
  "sourceReferences": ["Referenced contact, commitment, or meeting names"],
  "suggestedNextActions": ["Suggested action 1 (e.g. Prepare email to X)", "Suggested action 2"]
}
''';

    final contents = <Map<String, dynamic>>[];

    contents.add({
      'role': 'user',
      'parts': [{'text': systemPrompt}],
    });
    contents.add({
      'role': 'model',
      'parts': [{'text': '{"answer": "Understood. I will answer strictly based on your verified business memory context.", "sourceReferences": [], "suggestedNextActions": []}'}],
    });

    // Add previous conversation turns (last 6 messages)
    for (final msg in conversationHistory.take(6)) {
      final role = msg['role'] == 'user' ? 'user' : 'model';
      final text = msg['content'] ?? msg['text'] ?? '';
      if (text.isNotEmpty) {
        contents.add({
          'role': role,
          'parts': [{'text': text}],
        });
      }
    }

    // Add current user question
    contents.add({
      'role': 'user',
      'parts': [{'text': 'USER QUESTION:\n$question'}],
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': contents,
        'generationConfig': {
          'responseMimeType': 'application/json',
          'temperature': 0.1,
        }
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
    final json = jsonDecode(text) as Map<String, dynamic>;

    return AssistantQueryResponse(
      answer: json['answer'] as String? ?? 'No response generated.',
      sourceReferences: List<String>.from(json['sourceReferences'] ?? []),
      suggestedNextActions:
          List<String>.from(json['suggestedNextActions'] ?? []),
    );
  }

  Future<AssistantQueryResponse> _queryGroqRAG(
    String question,
    String context,
    String apiKey,
    AssistantSettings settings, {
    List<Map<String, String>> conversationHistory = const [],
  }) async {
    const candidateModels = [
      'llama-3.3-70b-versatile',
      'llama-3.1-8b-instant',
      'llama-3.1-70b-versatile',
      'llama3-70b-8192',
      'llama3-8b-8192',
      'mixtral-8x7b-32768',
      'qwen-2.5-32b',
    ];
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    final systemPrompt = '''
You are RemembrAI, the user's executive personal business memory assistant.
Answer the user's question accurately using ONLY the verified memory context provided below.

GROUNDED BUSINESS MEMORY CONTEXT:
$context

${settings.toSystemPromptAddition()}

RULES:
1. EXECUTIVE ASSISTANT VOICE: Address the user respectfully as their executive client (e.g. "You have a meeting with Raju at 10:30 AM", "You promised Karim..."). Never parrot raw first-person quotes like "You have a commitment 'I have a meeting'".
2. Answer factually based on the context and conversation history. Never invent promises or meetings.
3. If information is not in memory, honestly state: "I don't have a record of that in your memory yet."
4. Highlight pending deadlines and commitments clearly.
4. Support multi-turn questions (e.g. "What about him?", "Draft a follow up to her").
5. Return strictly JSON in this format:
{
  "answer": "Direct, professional, bulleted or summarized answer",
  "sourceReferences": ["Referenced contact, commitment, or meeting names"],
  "suggestedNextActions": ["Suggested action 1 (e.g. Prepare email to X)", "Suggested action 2"]
}
''';

    final messages = <Map<String, String>>[];
    messages.add({'role': 'system', 'content': systemPrompt});

    for (final msg in conversationHistory.take(6)) {
      final role = msg['role'] == 'user' ? 'user' : 'assistant';
      final text = msg['content'] ?? msg['text'] ?? '';
      if (text.isNotEmpty) {
        messages.add({'role': role, 'content': text});
      }
    }

    messages.add({'role': 'user', 'content': 'USER QUESTION:\n$question'});

    for (final model in candidateModels) {
      try {
        final response = await http.post(
          url,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'messages': messages,
            'response_format': {'type': 'json_object'},
            'temperature': 0.1,
          }),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final choices = data['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final text = choices[0]['message']['content'] as String;
            final json = jsonDecode(text) as Map<String, dynamic>;

            return AssistantQueryResponse(
              answer: json['answer'] as String? ?? 'No response generated.',
              sourceReferences: List<String>.from(json['sourceReferences'] ?? []),
              suggestedNextActions:
                  List<String>.from(json['suggestedNextActions'] ?? []),
            );
          }
        }
      } catch (_) {
        continue;
      }
    }

    return _queryOfflineRuleEngine(question, context);
  }

  Future<AssistantQueryResponse> _queryOfflineRuleEngine(
    String question,
    String context,
    AssistantSettings settings, {
    List<Map<String, String>> conversationHistory = const [],
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final q = question.toLowerCase();
    final isBangla = settings.language == AssistantLanguage.bangla;
    final isBanglish = settings.language == AssistantLanguage.banglish;

    final commitments = await _db.getAllCommitments();
    final contacts = await _db.getAllContacts();
    final meetings = await _db.getAllMeetings();

    // Context resolution from multi-turn history
    String targetQuery = q;
    if (q.contains('him') || q.contains('her') || q.contains('them') || q.contains('draft') || q.contains('follow up')) {
      for (final msg in conversationHistory.reversed) {
        final content = (msg['content'] ?? msg['text'] ?? '').toLowerCase();
        for (final c in contacts) {
          if (content.contains(c.name.toLowerCase()) || content.contains(c.name.split(' ').first.toLowerCase())) {
            targetQuery = '$q ${c.name.toLowerCase()}';
            break;
          }
        }
        if (targetQuery != q) break;
      }
    }

    // Check: "What did I promise [Person]?"
    for (final c in contacts) {
      if (targetQuery.contains(c.name.toLowerCase()) ||
          targetQuery.contains(c.name.split(' ').first.toLowerCase())) {
        final personCommitments =
            commitments.where((cm) => cm.contactId == c.id).toList();

        if (personCommitments.isEmpty) {
          final emptyMsg = isBangla
              ? '${c.name}-এর সাথে আপনার কোনো রেকর্ডকৃত প্রতিশ্রুতি বা ফলো-আপ নেই।'
              : (isBanglish
                  ? '${c.name}-er shathe kono record kora promise nei.'
                  : 'You have no recorded commitments with ${c.name}.');
          return AssistantQueryResponse(
            answer: emptyMsg,
            sourceReferences: [c.name],
          );
        }

        final promises = personCommitments
            .map((cm) => '• [${cm.type.label}] "${cm.title}" (${cm.status.label}, Due: ${cm.dueDate?.toIso8601String().substring(0, 10) ?? 'No date'})')
            .join('\n');

        final header = isBangla
            ? '${c.name}-এর সাথে আপনার রেকর্ডকৃত প্রতিশ্রুতিসমূহ:\n\n$promises'
            : (isBanglish
                ? '${c.name}-er shathe apnar commitment gulo holo:\n\n$promises'
                : 'Here is what you have on record for ${c.name}:\n\n$promises');

        return AssistantQueryResponse(
          answer: header,
          sourceReferences: [c.name],
          suggestedNextActions: [
            isBangla ? '${c.name}-কে ফলো-আপ মেসেজ খসড়া করুন' : 'Prepare a follow-up message to ${c.name}',
            isBangla ? '${c.name}-এর জন্য নতুন প্রতিশ্রুতি যোগ করুন' : 'Add a new commitment for ${c.name}',
          ],
        );
      }
    }

    // Check: "overdue" or "pending" commitments
    if (q.contains('overdue') || q.contains('pending') || q.contains('commitments')) {
      final pending = commitments.where((c) => c.status.name == 'pending').toList();
      if (pending.isEmpty) {
        return AssistantQueryResponse(
          answer: 'Great news! You have zero pending or overdue commitments right now.',
        );
      }
      final items = pending
          .take(5)
          .map((c) => '• "${c.title}" (${c.type.label}${c.contactName != null ? ' with ${c.contactName}' : ''})')
          .join('\n');

      return AssistantQueryResponse(
        answer: 'You currently have ${pending.length} pending commitments:\n\n$items',
        sourceReferences: pending.map((c) => c.title).take(3).toList(),
      );
    }

    // Check: "meetings"
    if (q.contains('meeting') || q.contains('call')) {
      if (meetings.isEmpty) {
        return AssistantQueryResponse(
          answer: 'You have no meetings recorded in memory yet.',
        );
      }
      final lastMeeting = meetings.first;
      return AssistantQueryResponse(
        answer: 'Your latest meeting was "${lastMeeting.title}" on ${lastMeeting.meetingDate.toIso8601String().substring(0, 10)}.\n\nSummary: ${lastMeeting.summary ?? lastMeeting.rawNotes ?? 'No notes recorded.'}',
        sourceReferences: [lastMeeting.title],
      );
    }

    // Default synthesis
    return AssistantQueryResponse(
      answer: 'I searched your memory database for "$question". You have ${contacts.length} contacts, ${commitments.length} commitments, and ${meetings.length} meetings on record.\n\nAsk me questions like "What did I promise [Contact]?", "What commitments are pending?", or "Show my recent meetings".',
      suggestedNextActions: [
        'What commitments are pending?',
        'Who is in my contacts?',
      ],
    );
  }
}
