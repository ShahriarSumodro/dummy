import 'package:flutter_test/flutter_test.dart';
import 'package:remembrai/models/contact.dart';
import 'package:remembrai/models/memory_item.dart';
import 'package:remembrai/services/ai_service.dart';
import 'package:remembrai/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('MemoryItem Model & Categories Tests (Module 2)', () {
    test('MemoryCategory parses from strings accurately', () {
      expect(MemoryCategory.fromString('preference'), MemoryCategory.preference);
      expect(MemoryCategory.fromString('Personal Preference'), MemoryCategory.preference);
      expect(MemoryCategory.fromString('project'), MemoryCategory.project);
      expect(MemoryCategory.fromString('decision'), MemoryCategory.decision);
      expect(MemoryCategory.fromString('workingHabit'), MemoryCategory.workingHabit);
      expect(MemoryCategory.fromString('unknown_category'), MemoryCategory.fact);
    });

    test('MemoryItem map serialization round-trip', () {
      final original = MemoryItem(
        id: 42,
        category: MemoryCategory.preference,
        content: 'Prefers dark roast coffee with no sugar',
        contactId: 7,
        contactName: 'Karim Ullah',
        source: 'user_stated',
        confidence: 0.98,
        isVerified: true,
        createdAt: DateTime(2026, 11, 15, 14, 30),
        updatedAt: DateTime(2026, 11, 15, 14, 35),
      );

      final map = original.toMap();
      expect(map['id'], 42);
      expect(map['category'], 'preference');
      expect(map['content'], 'Prefers dark roast coffee with no sugar');
      expect(map['contact_id'], 7);
      expect(map['source'], 'user_stated');
      expect(map['confidence'], 0.98);
      expect(map['is_verified'], 1);

      final restored = MemoryItem.fromMap(map);
      expect(restored.id, 42);
      expect(restored.category, MemoryCategory.preference);
      expect(restored.content, 'Prefers dark roast coffee with no sugar');
      expect(restored.contactId, 7);
      expect(restored.source, 'user_stated');
      expect(restored.confidence, 0.98);
      expect(restored.isVerified, isTrue);
    });
  });

  group('DatabaseService Memory Engine CRUD Tests', () {
    late DatabaseService db;

    setUp(() async {
      db = DatabaseService();
      await db.initInMemoryForTesting();
      await db.clearAllData();
    });

    test('Inserts, retrieves, filters, updates, and deletes memories', () async {
      // 1. Create a contact
      final contactId = await db.insertContact(Contact(
        name: 'Tariq Rahman',
        company: 'VentureBD',
        role: 'Partner',
      ));

      // 2. Insert memories
      final mem1Id = await db.insertMemory(MemoryItem(
        category: MemoryCategory.preference,
        content: 'Prefers meeting after 2 PM; drinks green tea',
        contactId: contactId,
      ));

      final mem2Id = await db.insertMemory(MemoryItem(
        category: MemoryCategory.project,
        content: 'Targeting Series A round closing by Q3 2027',
      ));

      final mem3Id = await db.insertMemory(MemoryItem(
        category: MemoryCategory.workingHabit,
        content: 'Works best in late night deep focus sessions',
      ));

      // 3. Count
      final count = await db.countMemories();
      expect(count, 3);

      // 4. Retrieve single
      final fetched = await db.getMemory(mem1Id);
      expect(fetched, isNotNull);
      expect(fetched!.content, 'Prefers meeting after 2 PM; drinks green tea');
      expect(fetched.contactName, 'Tariq Rahman');

      // 5. Category filter
      final projectMemories = await db.getAllMemories(category: 'project');
      expect(projectMemories.length, 1);
      expect(projectMemories.first.id, mem2Id);

      // 6. Contact filter
      final contactMemories = await db.getAllMemories(contactId: contactId);
      expect(contactMemories.length, 1);
      expect(contactMemories.first.id, mem1Id);

      // 7. Search query
      final searchResults = await db.getAllMemories(searchQuery: 'deep focus');
      expect(searchResults.length, 1);
      expect(searchResults.first.id, mem3Id);

      // 8. Update
      final updated = fetched.copyWith(
        content: 'Prefers meeting after 3 PM; drinks jasmine green tea',
      );
      await db.updateMemory(updated);
      final refetched = await db.getMemory(mem1Id);
      expect(refetched!.content, 'Prefers meeting after 3 PM; drinks jasmine green tea');

      // 9. Delete
      await db.deleteMemory(mem2Id);
      final afterDeleteCount = await db.countMemories();
      expect(afterDeleteCount, 2);
    });

    test('buildRagContextSummary includes stored knowledge and preferences', () async {
      await db.insertMemory(MemoryItem(
        category: MemoryCategory.preference,
        content: 'Prefers concise bullet points in executive briefings',
      ));

      final contactId = await db.insertContact(Contact(
        name: 'Dr. Kamal Hossain',
        company: 'Apex Health',
      ));

      await db.insertMemory(MemoryItem(
        category: MemoryCategory.fact,
        content: 'Lives in Gulshan 2 and graduated from Harvard Medical School',
        contactId: contactId,
      ));

      final ragSummary = await db.buildRagContextSummary();
      expect(ragSummary, contains('-- STORED KNOWLEDGE & PREFERENCES'));
      expect(ragSummary, contains('Prefers concise bullet points'));
      expect(ragSummary, contains('Dr. Kamal Hossain'));
      expect(ragSummary, contains('Lives in Gulshan 2'));
    });
  });

  group('AI Extraction Memory Tests', () {
    final aiService = MockAiService();

    final testContacts = [
      Contact(id: 1, name: 'Karim Ullah', company: 'TechBD'),
      Contact(id: 2, name: 'Rahim Ahmed', company: 'Apex Corp'),
    ];

    test('MockAiService extracts personal preferences and facts into memories without fake commitments', () async {
      const input = 'Karim likes dark roast coffee without sugar and prefers afternoon calls.';
      final result = await aiService.extract(
        text: input,
        existingContacts: testContacts,
      );

      expect(result.memories.isNotEmpty, isTrue);
      final mem = result.memories.first;
      expect(mem.category, 'preference');
      expect(mem.contactName, 'Karim Ullah');
      expect(mem.matchedContactId, 1);
      expect(mem.content.toLowerCase(), contains('dark roast coffee'));
    });

    test('MockAiService extracts project milestones into project memories', () async {
      const input = 'Our MVP launch milestone target is end of next month.';
      final result = await aiService.extract(text: input);

      expect(result.memories.isNotEmpty, isTrue);
      final mem = result.memories.first;
      expect(mem.category, 'project');
      expect(mem.content, contains('MVP launch milestone target'));
    });

    test('MockAiService extracts agreed decisions', () async {
      const input = 'We decided to use SQLite for completely offline-first local data storage.';
      final result = await aiService.extract(text: input);

      expect(result.memories.isNotEmpty, isTrue);
      final mem = result.memories.first;
      expect(mem.category, 'decision');
      expect(mem.content, contains('decided to use SQLite'));
    });
  });
}
