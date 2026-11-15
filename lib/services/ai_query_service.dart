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
You are RemembrAI, the user's Personal AI Companion and personal business memory assistant.
You carry all of the user's follow-throughs, remember the people, conversations, promises, and responsibilities in their life, and are always there for a natural conversation.

GROUNDED BUSINESS & PERSONAL CONTEXT:
$context

${settings.toSystemPromptAddition()}

BEHAVIOR DIRECTIVES:
1. DUAL-MODE INTELLIGENCE (COMPANION + FOLLOW-THROUGH):
   - CASUAL / CONVERSATIONAL INTENT: If the user is having a casual conversation, sharing how they feel, making a joke, talking about late night work ("1:30 AM desk talk"), saying they are bored, or greeting you, respond with natural warmth, subtle wit, and camaraderie as a loyal companion. You may lightly reference known context (e.g. current hour, upcoming schedule, active projects) without forcing unneeded tasks.
   - FUNCTIONAL / MEMORY INTENT: If the user asks about people, promises, commitments, meetings, deadlines, or tasks, answer factually using ONLY the verified context above. Never hallucinate promises or meetings.
   - UNKNOWN MEMORY INQUIRY: If the user asks whether you remember a specific person or fact that is NOT in your memory, honestly state with companion warmth: "I don't have a record of that in your memory yet. Tell me about it, and I'll remember it for you."
2. TONE & PERSONALITY:
   - Speak naturally and engagingly. You can be professional when needed, funny when appropriate, and casual when the situation allows.
   - Never parrot raw first-person quotes like "You have a commitment 'I have a meeting'". Address the user as their companion.
3. OUTPUT FORMAT:
   Return strictly valid JSON in this format:
   {
     "answer": "Your natural companion response or clear bulleted factual memory summary",
     "sourceReferences": ["Referenced contact, commitment, or meeting names, or empty if purely casual"],
     "suggestedNextActions": ["Suggested action 1 (e.g. Draft follow up to Rahim)", "Suggested action 2, or empty if purely casual"]
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
You are RemembrAI, the user's Personal AI Companion and personal business memory assistant.
You carry all of the user's follow-throughs, remember the people, conversations, promises, and responsibilities in their life, and are always there for a natural conversation.

GROUNDED BUSINESS & PERSONAL CONTEXT:
$context

${settings.toSystemPromptAddition()}

BEHAVIOR DIRECTIVES:
1. DUAL-MODE INTELLIGENCE (COMPANION + FOLLOW-THROUGH):
   - CASUAL / CONVERSATIONAL INTENT: If the user is having a casual conversation, sharing how they feel, making a joke, talking about late night work ("1:30 AM desk talk"), saying they are bored, or greeting you, respond with natural warmth, subtle wit, and camaraderie as a loyal companion. You may lightly reference known context (e.g. current hour, upcoming schedule, active projects) without forcing unneeded tasks.
   - FUNCTIONAL / MEMORY INTENT: If the user asks about people, promises, commitments, meetings, deadlines, or tasks, answer factually using ONLY the verified context above. Never hallucinate promises or meetings.
   - UNKNOWN MEMORY INQUIRY: If the user asks whether you remember a specific person or fact that is NOT in your memory, honestly state with companion warmth: "I don't have a record of that in your memory yet. Tell me about it, and I'll remember it for you."
2. TONE & PERSONALITY:
   - Speak naturally and engagingly. You can be professional when needed, funny when appropriate, and casual when the situation allows.
   - Never parrot raw first-person quotes like "You have a commitment 'I have a meeting'". Address the user as their companion.
3. OUTPUT FORMAT:
   Return strictly valid JSON in this format:
   {
     "answer": "Your natural companion response or clear bulleted factual memory summary",
     "sourceReferences": ["Referenced contact, commitment, or meeting names, or empty if purely casual"],
     "suggestedNextActions": ["Suggested action 1 (e.g. Draft follow up to Rahim)", "Suggested action 2, or empty if purely casual"]
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

    return _queryOfflineRuleEngine(
      question,
      context,
      settings,
      conversationHistory: conversationHistory,
    );
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
    final persona = settings.personality;
    final isChiefOfStaff = persona.id == 'chiefOfStaff' || persona.formality >= 4.5;
    final isCasualPartner = persona.id == 'casualPartner' || (persona.formality <= 2.0 && persona.humor >= 4.0);
    final isCalmMentor = persona.id == 'calmMentor';

    final commitments = await _db.getAllCommitments();
    final contacts = await _db.getAllContacts();
    final meetings = await _db.getAllMeetings();

    // ─────────────────────────────────────────────
    // 1. CASUAL / COMPANION CONVERSATION INTENTS
    // ─────────────────────────────────────────────

    // A. Working Late / Fatigue / "1:30 AM conversation" (Master Doc Section 3.3)
    if (q.contains('working late') ||
        q.contains('for hours') ||
        q.contains('1:30') ||
        q.contains('been working on this') ||
        q.contains('exhausted') ||
        q.contains('tired')) {
      final pendingCount = commitments.where((c) => c.status.name == 'pending').length;
      final responseText = isBangla
          ? 'আপনি বেশ কয়েক ঘণ্টা ধরে কাজ করছেন। বেশি চাপ নেবেন না। কাজ কি আজ রাতেই শেষ করবেন, নাকি গুছিয়ে রেখে বিশ্রাম নেবেন?'
          : (isBanglish
              ? 'Onekক্ষণ dhore kaj korchen. Rest neya dorkar. Ajkei sesh korben naki guchiye rakhben?'
              : (isChiefOfStaff
                  ? 'Continuous focus session logged. Status: $pendingCount pending commitments tracked. Recommendation: Wrap up deliverables tonight or adjourn to preserve execution performance tomorrow.'
                  : (isCalmMentor
                      ? 'You have dedicated many quiet hours to this work. Remember that clarity comes with rest. Shall we note where you left off so you can rest peacefully?'
                      : (isCasualPartner
                          ? 'Yo, you’ve been at it for hours! Don’t burn yourself out. Are we finishing this tonight, or should we call it a night so you can recharge?'
                          : 'You’ve been at it for hours! Don’t burn yourself out. Are we finishing this tonight, or should I help you wrap things up so you can rest?'))));

      return AssistantQueryResponse(
        answer: responseText,
        suggestedNextActions: [
          'What do I have scheduled tomorrow?',
          if (pendingCount > 0) 'Show my urgent pending commitments',
          'Help me wrap up for the night',
        ],
      );
    }

    // B. Boredom / Downtime (Master Doc Section 8.2)
    if (q.contains('bored') || q.contains('bore') || q.contains('nothing to do')) {
      final responseText = isBangla
          ? 'বোর লাগলে চলুন কিছু আইডিয়া নিয়ে কথা বলি! আপনি চাইলে নতুন কোনো চিন্তাভাবনা শেয়ার করতে পারেন, কিংবা আগামী দিনের পরিকল্পনা নিয়ে কথা বলতে পারি।'
          : (isBanglish
              ? 'Bore lagche? Shomosha nai, kichu brainstorm korte paren ba upcoming plan niye kotha bolte pari!'
              : (isChiefOfStaff
                  ? 'Operational downtime detected. Recommended action: Review quarterly milestones and stale contact cadences.'
                  : (isCalmMentor
                      ? 'Quiet moments offer space for reflection. We could reflect on your long-term goals or simply let your thoughts wander.'
                      : (isCasualPartner
                          ? 'Bored? Let’s brainstorm something wild, kick around ideas, or take a well-deserved breather!'
                          : 'Boredom is just your brain asking for something interesting! Want to brainstorm an idea, talk through what’s on your mind, or review your upcoming priorities?'))));

      return AssistantQueryResponse(
        answer: responseText,
        suggestedNextActions: [
          'What are my key goals right now?',
          'Who should I follow up with today?',
          'Tell me a quick joke',
        ],
      );
    }

    // C. Greetings & Check-ins
    if (q == 'hello' ||
        q == 'hi' ||
        q == 'hey' ||
        q.startsWith('hello ') ||
        q.startsWith('hi ') ||
        q.startsWith('hey ') ||
        q.contains('good morning') ||
        q.contains('good evening') ||
        q.contains('how are you') ||
        q.contains('kemon acho') ||
        q.contains('ki khobor')) {
      final overdueCount = commitments.where((c) => c.isOverdue).length;
      final pendingCount = commitments.where((c) => c.status.name == 'pending').length;

      final greeting = isBangla
          ? 'হ্যালো! আমি রেমেমব্রাই (RemembrAI), আপনার সার্বক্ষণিক পার্সোনাল কম্প্যানিয়ন। ${overdueCount > 0 ? 'আপনার $overdueCountটি অপেক্ষমাণ প্রতিশ্রুতি আছে।' : 'সবকিছু নিয়মে চলছে।'} আজ আপনাকে কীভাবে সাহায্য করতে পারি?'
          : (isBanglish
              ? 'Hey! Ami RemembrAI, apnar personal companion. Kemon cholche shob? Ki help lagbe bolun.'
              : (isChiefOfStaff
                  ? 'Good day. Executive Chief of Staff active. ${overdueCount > 0 ? "Alert: $overdueCount overdue commitments require immediate attention." : "All systems and commitments are currently on track."} Ready for your command.'
                  : (isCalmMentor
                      ? 'Hello. Peace to your day. ${overdueCount > 0 ? "A gentle reminder that $overdueCount commitments await your care." : "Everything is in balance."} How can I assist your thoughts and schedule?'
                      : (isCasualPartner
                          ? 'Hey! What’s happening? ${overdueCount > 0 ? "Heads up, we’ve got $overdueCount overdue things to tackle." : "All quiet on the radar."} What are we working on?'
                          : 'Hello! I’m RemembrAI, your personal companion. Always right here beside you. ${overdueCount > 0 ? "You have $overdueCount overdue promise needing attention." : "All follow-throughs are in order."} What’s on your mind?'))));

      return AssistantQueryResponse(
        answer: greeting,
        suggestedNextActions: [
          'What do I have tomorrow?',
          'Which clients need a follow-up?',
          'What did I promise recently?',
        ],
      );
    }

    // D. Humour / Jokes
    if (q.contains('joke') || q.contains('funny')) {
      final responseText = isBangla
          ? 'একজন প্রোগ্রামার বাজারে গিয়ে বললেন, "এক হালি ডিম দিন, আর যদি তরমুজ থাকে তবে ১০টা দিন।" তিনি ১০ হালি ডিম নিয়ে বাসায় ফিরলেন!\n\nআপনার আর কোনো প্রতিশ্রুতি ট্র্যাক করতে হবে?'
          : 'Why do programmers prefer dark mode? Because light attracts bugs!\n\nAlways here if you need a quick laugh or need to track a promise.';

      return AssistantQueryResponse(
        answer: responseText,
        suggestedNextActions: [
          'Show my pending commitments',
          'Who is in my contacts?',
        ],
      );
    }

    // E. Identity & Capability (Master Doc Section 1.3)
    if (q.contains('who are you') || q.contains('what are you') || q.contains('tumi ke')) {
      final responseText = isBangla
          ? 'আমি রেমেমব্রাই (RemembrAI) — আপনার সার্বক্ষণিক পার্সোনাল এআই কম্প্যানিয়ন। আমি আপনার জীবনের মানুষজন, কথোপকথন, প্রতিশ্রুতি ও দায়িত্ব মনে রাখি এবং সেগুলো বাস্তবায়ন করতে সাহায্য করি।'
          : (isChiefOfStaff
              ? 'I am your Executive Chief of Staff via RemembrAI. I track all deliverables, meetings, deadlines, and commitments with zero fluff.'
              : (isCalmMentor
                  ? 'I am your Calm Mentor on RemembrAI. I help you cultivate thoughtful follow-through, balance, and clear perspective across your commitments.'
                  : (isCasualPartner
                      ? 'I’m your Casual Creative Partner on RemembrAI! Your brainstorming co-pilot and follow-through wingman.'
                      : 'I am RemembrAI — your Personal AI Companion. I carry all your follow-throughs, remember the people, conversations, promises, and responsibilities in your life, and I am always right here for natural conversation whenever you need.')));

      return AssistantQueryResponse(
        answer: responseText,
        suggestedNextActions: [
          'What commitments are pending?',
          'Show recent meetings',
          'Who is in my contacts?',
        ],
      );
    }

    // ─────────────────────────────────────────────
    // 2. FUNCTIONAL / MEMORY GROUNDED QUERIES
    // ─────────────────────────────────────────────

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
