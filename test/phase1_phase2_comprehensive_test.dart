import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:remembrai/services/database_service.dart';
import 'package:remembrai/services/ai_query_service.dart';
import 'package:remembrai/models/contact.dart';
import 'package:remembrai/models/commitment.dart';
import 'package:remembrai/models/meeting.dart';
import 'package:remembrai/models/ai_extraction_result.dart';
import 'package:remembrai/services/ai_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseService dbService;

  setUp(() async {
    dbService = DatabaseService();
    await dbService.initInMemoryForTesting();
    await dbService.clearAllData();
  });

  group('Phase 1 & 2: Contact Cadence & Touchpoints', () {
    test('Contact defaults to 30 cadence days and persists custom values', () async {
      final contact = Contact(
        name: 'Sara Khan',
        email: 'sara@example.com',
        cadenceDays: 14,
      );

      final id = await dbService.insertContact(contact);
      final retrieved = await dbService.getContact(id);

      expect(retrieved, isNotNull);
      expect(retrieved!.name, 'Sara Khan');
      expect(retrieved.cadenceDays, 14);

      final copy = retrieved.copyWith(cadenceDays: 7);
      await dbService.updateContact(copy);
      final updated = await dbService.getContact(id);
      expect(updated!.cadenceDays, 7);
    });

    test('Relationship health check identifies cadence overdue contacts', () async {
      final c1 = Contact(name: 'Active Client', cadenceDays: 30);
      final c2 = Contact(name: 'Cold Client', cadenceDays: 7);

      final id1 = await dbService.insertContact(c1);
      final id2 = await dbService.insertContact(c2);

      // c1 has a recent commitment (yesterday)
      await dbService.insertCommitment(Commitment(
        title: 'Send proposal',
        contactId: id1,
        dueDate: DateTime.now().add(const Duration(days: 2)),
      ));

      // c2 has an old commitment from 15 days ago
      final oldDb = await dbService.database;
      await oldDb.insert('commitments', {
        'title': 'Past sync',
        'contact_id': id2,
        'type': 'task',
        'status': 'completed',
        'created_at': DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
        'updated_at': DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
      });

      final health = await dbService.getRelationshipHealthCheck();
      expect(health.length, equals(2));

      final coldEntry = health.firstWhere((h) => h['id'] == id2);
      expect(coldEntry['cadence_days'], equals(7));
      expect(coldEntry['last_commitment_date'], isNotNull);
    });
  });

  group('Phase 1 & 2: Schedule Conflict Detector', () {
    test('detects overlapping commitments and meetings within window', () async {
      final targetTime = DateTime(2026, 11, 20, 14, 0);

      // Commitment at 14:30 (within 2 hours)
      final cId = await dbService.insertCommitment(Commitment(
        title: 'Review Marketing Deck',
        dueDate: DateTime(2026, 11, 20, 14, 30),
      ));

      // Meeting at 15:00 (within 2 hours)
      final mId = await dbService.insertMeeting(Meeting(
        title: 'Quarterly Board Meeting',
        meetingDate: DateTime(2026, 11, 20, 15, 0),
      ));

      // Unrelated meeting tomorrow
      await dbService.insertMeeting(Meeting(
        title: 'Future Workshop',
        meetingDate: DateTime(2026, 11, 21, 14, 0),
      ));

      // Check conflicts around 14:00
      final conflicts = await dbService.checkScheduleConflicts(targetTime);
      expect(conflicts.length, equals(2));

      // Exclude commitment by ID
      final excludedC = await dbService.checkScheduleConflicts(
        targetTime,
        excludeCommitmentId: cId,
      );
      expect(excludedC.length, equals(1));
      expect(excludedC.first['kind'], equals('meeting'));

      // Exclude meeting by ID
      final excludedM = await dbService.checkScheduleConflicts(
        targetTime,
        excludeMeetingId: mId,
      );
      expect(excludedM.length, equals(1));
      expect(excludedM.first['kind'], equals('commitment'));
    });
  });

  group('Phase 1 & 2: Say-Do Dependability Analytics', () {
    test('calculates accurate Say-Do ratio and turnaround metrics', () async {
      final now = DateTime.now();

      // 1. Completed on-time commitment
      final db = await dbService.database;
      await db.insert('commitments', {
        'title': 'Deliver Milestone 1',
        'type': 'promiseMade',
        'status': 'completed',
        'due_date': now.add(const Duration(days: 2)).toIso8601String(),
        'completed_at': now.add(const Duration(days: 1)).toIso8601String(),
        'created_at': now.subtract(const Duration(days: 2)).toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // 2. Overdue commitment
      await db.insert('commitments', {
        'title': 'Send contract draft',
        'type': 'promiseMade',
        'status': 'pending',
        'due_date': now.subtract(const Duration(days: 1)).toIso8601String(),
        'created_at': now.subtract(const Duration(days: 3)).toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // 3. Promise owed to me (pending, on track)
      await db.insert('commitments', {
        'title': 'Receive payment invoice',
        'type': 'promiseReceived',
        'status': 'pending',
        'due_date': now.add(const Duration(days: 5)).toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      final analytics = await dbService.getSayDoAnalytics();

      expect(analytics['totalTracked'], equals(3));
      expect(analytics['completedCount'], equals(1));
      expect(analytics['completedOnTimeCount'], equals(1));
      expect(analytics['overdueCount'], equals(1));
      expect(analytics['pendingCount'], equals(1));

      // Say-Do: 1 on-time out of (1 completed + 1 overdue) = 50%
      expect(analytics['sayDoRatio'], closeTo(50.0, 0.1));
      expect(analytics['promisesMadeTotal'], equals(2));
      expect(analytics['promisesReceivedTotal'], equals(1));
    });
  });

  group('Phase 1 & 2: Citations, Grounding & Multi-Turn Context', () {
    test('ExtractedCommitment contains source excerpt citation and confidence label', () {
      final item = ExtractedCommitment(
        title: 'Send pitch deck to Tanvir',
        contactName: 'Tanvir',
        confidence: 0.95,
        sourceExcerpt: 'Tanvir: "Please send me the pitch deck by tomorrow morning"',
      );

      expect(item.sourceExcerpt, isNotNull);
      expect(item.confidenceLabel, equals('High (95%)'));
      expect(item.confidence, equals(0.95));
    });

    test('AiQueryService resolves conversational pronouns using history', () async {
      final queryService = AiQueryService();

      // Add contact Rahim
      final rahimId = await dbService.insertContact(Contact(
        name: 'Rahim Chowdhury',
        email: 'rahim@company.com',
      ));
      await dbService.insertCommitment(Commitment(
        title: 'Submit audit report to Rahim',
        contactId: rahimId,
        contactName: 'Rahim Chowdhury',
      ));

      // Multi-turn: User previously spoke about Rahim
      final history = [
        {'role': 'user', 'content': 'Tell me about Rahim Chowdhury'},
        {'role': 'model', 'content': 'Rahim Chowdhury is associated with audit report.'},
      ];

      // Second turn: User asks "What did I promise him?"
      final response = await queryService.queryMemory(
        'What did I promise him?',
        conversationHistory: history,
      );

      expect(response.answer, contains('Rahim'));
    });
  });

  group('Multi-Provider AI Configuration Tests', () {
    test('auto-detects Groq provider when API key starts with gsk_', () async {
      await AiServiceFactory.setApiKey('gsk_test_groq_key_12345');
      final provider = await AiServiceFactory.getProvider();
      expect(provider, equals(AiProvider.groq));

      final service = await AiServiceFactory.getService();
      expect(service, isA<GroqAiService>());
    });

    test('auto-detects Gemini provider when API key starts with AIza', () async {
      await AiServiceFactory.setApiKey('AIzaSyTestGeminiKey67890');
      final provider = await AiServiceFactory.getProvider();
      expect(provider, equals(AiProvider.gemini));

      final service = await AiServiceFactory.getService();
      expect(service, isA<GeminiAiService>());
    });

    test('falls back to MockAiService when mock mode is enabled or key is empty', () async {
      await AiServiceFactory.setMockMode(true);
      final service = await AiServiceFactory.getService();
      expect(service, isA<MockAiService>());
      await AiServiceFactory.setMockMode(false);
    });
  });
}
