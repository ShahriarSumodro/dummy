import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:remembrai/services/database_service.dart';
import 'package:remembrai/services/ai_query_service.dart';
import 'package:remembrai/models/contact.dart';
import 'package:remembrai/models/commitment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseService db;
  late AiQueryService queryService;

  setUp(() async {
    db = DatabaseService();
    await db.initInMemoryForTesting();
    await db.clearAllData();
    queryService = AiQueryService();
  });

  group('Cycle 1: Companion Chat Persistence in SQLite', () {
    test('Persists and retrieves chat messages in chronological order', () async {
      final initial = await db.getChatMessages();
      expect(initial, isEmpty);

      // Insert User message
      await db.insertChatMessage(
        text: 'Man, I have been working on this for hours.',
        isUser: true,
      );

      // Insert Companion message
      await db.insertChatMessage(
        text: 'You have been at it for a while! Are we wrapping up or pushing through?',
        isUser: false,
        sourceReferences: ['Work Project'],
        suggestedNextActions: ['Check tomorrow schedule'],
      );

      final retrieved = await db.getChatMessages();
      expect(retrieved.length, equals(2));

      expect(retrieved[0]['text'], equals('Man, I have been working on this for hours.'));
      expect(retrieved[0]['is_user'], isTrue);

      expect(retrieved[1]['is_user'], isFalse);
      expect(retrieved[1]['text'], contains('You have been at it for a while!'));
      expect(retrieved[1]['source_references'], contains('Work Project'));
      expect(retrieved[1]['suggested_next_actions'], contains('Check tomorrow schedule'));
    });

    test('clearChatMessages wipes messages without affecting contacts or commitments', () async {
      await db.insertContact(Contact(name: 'Rahim Ahmed', email: 'rahim@example.com'));
      await db.insertChatMessage(text: 'Hello RemembrAI', isUser: true);

      expect((await db.getChatMessages()).length, equals(1));
      expect((await db.getAllContacts()).length, equals(1));

      await db.clearChatMessages();

      expect(await db.getChatMessages(), isEmpty);
      // Contact is still preserved!
      expect((await db.getAllContacts()).length, equals(1));
    });

    test('clearAllData wipes chat messages along with all entities', () async {
      await db.insertChatMessage(text: 'Test message', isUser: true);
      expect((await db.getChatMessages()).length, equals(1));

      await db.clearAllData();
      expect(await db.getChatMessages(), isEmpty);
    });
  });

  group('Cycle 1: Dual-Mode Companion Intelligence (Casual vs Functional)', () {
    test('Casual Intent: 1:30 AM desk talk triggers companion camaraderie response', () async {
      final response = await queryService.queryMemory("Man, I've been working on this project for hours.");

      expect(response.answer, isNotEmpty);
      expect(response.answer.toLowerCase(), anyOf(
        contains('hours'),
        contains('burn yourself out'),
        contains('finishing this tonight'),
        contains('wrap things up'),
      ));
      expect(response.suggestedNextActions, isNotEmpty);
    });

    test('Casual Intent: Boredom triggers conversational brainstorming', () async {
      final response = await queryService.queryMemory("I'm bored.");

      expect(response.answer, isNotEmpty);
      expect(response.answer.toLowerCase(), anyOf(
        contains('boredom'),
        contains('brainstorm'),
        contains('mind'),
      ));
    });

    test('Casual Intent: Greeting recognizes RemembrAI identity and companion warmth', () async {
      final response = await queryService.queryMemory("Hello");

      expect(response.answer, contains('RemembrAI'));
      expect(response.answer.toLowerCase(), contains('companion'));
    });

    test('Casual Intent: Identity inquiry states Master Product identity', () async {
      final response = await queryService.queryMemory("Who are you?");

      expect(response.answer, contains('RemembrAI'));
      expect(response.answer, contains('Personal AI Companion'));
      expect(response.answer, contains('follow-throughs'));
    });

    test('Functional Intent: Queries about contact commitments remain grounded', () async {
      final cId = await db.insertContact(Contact(name: 'Rahim Ahmed', email: 'rahim@example.com'));
      await db.insertCommitment(Commitment(
        title: 'Send commercial proposal',
        contactId: cId,
        contactName: 'Rahim Ahmed',
        dueDate: DateTime.now().add(const Duration(days: 2)),
      ));

      final response = await queryService.queryMemory("What did I promise Rahim?");

      expect(response.answer, contains('Send commercial proposal'));
      expect(response.sourceReferences, contains('Rahim Ahmed'));
    });
  });
}
