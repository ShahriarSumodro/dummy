import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_service.dart';
import '../models/action_draft.dart';
import '../models/commitment.dart';
import '../models/contact.dart';

/// Service that generates follow-up communication drafts with strict user approval gates.
class ActionDraftService {
  Future<ActionDraft> generateDraftForCommitment({
    required Commitment commitment,
    Contact? contact,
    DraftType type = DraftType.email,
    bool forceOffline = false,
  }) async {
    if (!forceOffline) {
      try {
        final isMock = await AiServiceFactory.isMockMode();
        final apiKey = await AiServiceFactory.getApiKey();
        final provider = await AiServiceFactory.getProvider();

        if (!isMock && apiKey != null && apiKey.isNotEmpty) {
          if (apiKey.startsWith('gsk_') || provider == AiProvider.groq) {
            return await _generateWithGroq(
              commitment: commitment,
              contact: contact,
              type: type,
              apiKey: apiKey,
            );
          } else {
            return await _generateWithGemini(
              commitment: commitment,
              contact: contact,
              type: type,
              apiKey: apiKey,
            );
          }
        }
      } catch (_) {}
    }

    return _generateOfflineTemplate(
      commitment: commitment,
      contact: contact,
      type: type,
    );
  }

  Future<ActionDraft> _generateWithGemini({
    required Commitment commitment,
    Contact? contact,
    required DraftType type,
    required String apiKey,
  }) async {
    const model = 'gemini-2.0-flash';
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );

    final prompt = '''
Draft a professional ${type.label} for this business commitment:
Commitment Title: "${commitment.title}"
Type: "${commitment.type.label}"
Recipient Name: "${contact?.name ?? commitment.contactName ?? 'Colleague'}"
Recipient Company: "${contact?.company ?? 'Partner'}"
Due Date: "${commitment.dueDate?.toIso8601String() ?? 'Upcoming'}"

Return JSON:
{
  "subject": "Clear, professional email or message subject",
  "body": "Courteous, concise message ready for review"
}
''';

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
          'temperature': 0.2,
        }
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
    final json = jsonDecode(text) as Map<String, dynamic>;

    return ActionDraft(
      type: type,
      title: 'Follow-up on ${commitment.title}',
      recipientName: contact?.name ?? commitment.contactName,
      recipientContact: contact?.email ?? contact?.phone,
      subject: json['subject'] as String?,
      body: json['body'] as String? ?? 'Following up regarding: ${commitment.title}',
      commitmentId: commitment.id,
      contactId: contact?.id ?? commitment.contactId,
    );
  }

  Future<ActionDraft> _generateWithGroq({
    required Commitment commitment,
    Contact? contact,
    required DraftType type,
    required String apiKey,
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

    final prompt = '''
Draft a professional ${type.label} for this business commitment:
Commitment Title: "${commitment.title}"
Type: "${commitment.type.label}"
Recipient Name: "${contact?.name ?? commitment.contactName ?? 'Colleague'}"
Recipient Company: "${contact?.company ?? 'Partner'}"
Due Date: "${commitment.dueDate?.toIso8601String() ?? 'Upcoming'}"

Return strictly JSON:
{
  "subject": "Clear, professional email or message subject",
  "body": "Courteous, crisp draft body ready to be sent"
}
''';

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
            'messages': [
              {'role': 'user', 'content': prompt}
            ],
            'response_format': {'type': 'json_object'},
            'temperature': 0.2,
          }),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final choices = data['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final rawJson = choices[0]['message']['content'] as String;
            final json = jsonDecode(rawJson) as Map<String, dynamic>;

            return ActionDraft(
              type: type,
              title: 'Follow-up on ${commitment.title}',
              recipientName: contact?.name ?? commitment.contactName,
              recipientContact: contact?.email ?? contact?.phone,
              subject: json['subject'] as String?,
              body: json['body'] as String? ?? 'Following up regarding: ${commitment.title}',
              commitmentId: commitment.id,
              contactId: contact?.id ?? commitment.contactId,
            );
          }
        }
      } catch (_) {
        continue;
      }
    }

    return _generateOfflineTemplate(
      commitment: commitment,
      contact: contact,
      type: type,
    );
  }

  ActionDraft _generateOfflineTemplate({
    required Commitment commitment,
    Contact? contact,
    required DraftType type,
  }) {
    final recipient = contact?.name ?? commitment.contactName ?? 'there';
    final subject = 'Follow-up regarding ${commitment.title}';
    String body;

    if (type == DraftType.whatsapp || type == DraftType.sms) {
      body =
          'Hi $recipient, just checking in regarding "${commitment.title}". Let me know if you need any further information or updates from my side. Thanks!';
    } else {
      body = '''Dear $recipient,

I hope this note finds you well.

I am writing to follow up on our discussion regarding "${commitment.title}". Please let me know if there are any questions or if you would like me to prepare additional materials before we proceed.

Looking forward to connecting with you soon.

Best regards,
''';
    }

    return ActionDraft(
      type: type,
      title: 'Follow-up for ${commitment.title}',
      recipientName: contact?.name ?? commitment.contactName,
      recipientContact: contact?.email ?? contact?.phone,
      subject: subject,
      body: body,
      commitmentId: commitment.id,
      contactId: contact?.id ?? commitment.contactId,
    );
  }
}
