import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:remembrai/services/database_service.dart';
import 'package:remembrai/services/device_event_bus.dart';
import 'package:remembrai/models/contact.dart';
import 'package:remembrai/models/commitment.dart';
import 'package:remembrai/models/memory_item.dart';
import 'package:remembrai/screens/hardware_companion_screen.dart';
import 'package:remembrai/screens/briefing_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseService db;

  setUp(() async {
    db = DatabaseService();
    await db.initInMemoryForTesting();
    await db.clearAllData();
  });

  group('Hardware & Ambient Companion Tests (Module 8 & Section 17)', () {
    testWidgets('Renders Desk Companion mode with clock, ticker, and mode switcher',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HardwareCompanionScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check title and form factor buttons
      expect(find.text('Wearable & Hardware Simulator'), findsOneWidget);
      expect(find.text('Desk Companion'), findsOneWidget);
      expect(find.text('Wearable Pin'), findsOneWidget);

      // Verify Desk Companion Hub elements
      expect(find.text('RemembrAI Desk Hub'), findsOneWidget);
      expect(find.text('Desk Talk / Late Night Check-in'), findsOneWidget);

      // Switch to Wearable Pin
      await tester.tap(find.text('Wearable Pin'));
      await tester.pumpAndSettle();

      // Verify Wearable elements
      expect(find.text('RemembrAI Companion\nStandby'), findsOneWidget);

      // Switch back to Desk Companion
      await tester.tap(find.text('Desk Companion'));
      await tester.pumpAndSettle();
      expect(find.text('RemembrAI Desk Hub'), findsOneWidget);
    });

    testWidgets('Dispatches and reacts to Companion Device Events',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HardwareCompanionScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap simulate haptic alert
      await tester.tap(find.text('Simulate Haptic Alert'));
      await tester.pumpAndSettle();

      expect(find.text('New Promise Detected'), findsWidgets);
      expect(find.textContaining('Send quotation to Rahim'), findsWidgets);
    });
  });

  group('Executive Briefing & Contact Dossier Tests (Module 7 & Section 16)', () {
    testWidgets('Daily Executive Briefing includes Say-Do ratio and turnaround metrics',
        (tester) async {
      // Seed commitment
      await db.insertCommitment(
        Commitment(
          title: 'Review quarterly architecture roadmap',
          type: CommitmentType.promiseMade,
          status: CommitmentStatus.completed,
          dueDate: DateTime.now().subtract(const Duration(days: 1)),
          completedAt: DateTime.now().subtract(const Duration(hours: 12)),
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: BriefingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Executive Briefing'), findsOneWidget);
      expect(find.textContaining('Dependability & Follow-Through Health'), findsOneWidget);
      expect(find.textContaining('Say-Do Ratio: 100%'), findsOneWidget);
      expect(find.textContaining('Average Turnaround'), findsOneWidget);
    });

    testWidgets('Contact Pre-Meeting Dossier includes stored personal context and preferences',
        (tester) async {
      final contactId = await db.insertContact(
        Contact(
          name: 'Sarah Connor',
          company: 'Cyberdyne Systems',
          role: 'VP Security',
          email: 'sarah@cyberdyne.com',
          notes: 'Important strategic partner.',
        ),
      );

      // Add memory item specifically for Sarah
      await db.insertMemory(
        MemoryItem(
          content: 'Prefers meeting updates before 10 AM; strict privacy advocate.',
          category: MemoryCategory.preference,
          contactId: contactId,
        ),
      );

      final contact = await db.getContact(contactId);

      await tester.pumpWidget(
        MaterialApp(
          home: BriefingScreen(initialContact: contact),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Pre-Meeting Dossier: Sarah Connor'), findsOneWidget);
      expect(find.textContaining('Stored Personal Memory & Preferences'), findsOneWidget);
      expect(
        find.textContaining('Prefers meeting updates before 10 AM'),
        findsOneWidget,
      );
    });
  });

  group('Database Backup & Full State Restore Integrity', () {
    test('JSON Backup and Restore preserves all memories and chat history', () async {
      // 1. Insert contact, commitment, memory, chat message
      final contactId = await db.insertContact(
        Contact(name: 'Marcus Aurelius', company: 'Rome', role: 'Emperor'),
      );
      await db.insertCommitment(
        Commitment(
          title: 'Complete meditations treatise',
          type: CommitmentType.promiseMade,
          contactId: contactId,
        ),
      );
      await db.insertMemory(
        MemoryItem(
          content: 'Writes philosophy reflections at dawn.',
          category: MemoryCategory.workingHabit,
          contactId: contactId,
        ),
      );
      await db.insertChatMessage(
        text: 'I have logged your morning reflection time, Marcus.',
        isUser: false,
      );

      // 2. Export full backup
      final backupData = await db.exportDatabaseJson();
      final backupStr = backupData.toString();
      expect(backupStr, contains('Marcus Aurelius'));
      expect(backupStr, contains('Complete meditations treatise'));
      expect(backupStr, contains('Writes philosophy reflections at dawn.'));
      expect(backupStr, contains('I have logged your morning reflection time, Marcus.'));

      // 3. Clear database
      await db.clearAllData();
      expect(await db.getAllContacts(), isEmpty);
      expect(await db.getAllMemories(), isEmpty);
      expect(await db.getChatMessages(), isEmpty);

      // 4. Restore from backup
      final restoredCount = await db.restoreDatabaseJson(backupData);
      expect(restoredCount, greaterThan(0));

      // 5. Verify restored state
      final restoredContacts = await db.getAllContacts();
      expect(restoredContacts.length, 1);
      expect(restoredContacts.first.name, 'Marcus Aurelius');

      final restoredMemories = await db.getAllMemories();
      expect(restoredMemories.length, 1);
      expect(restoredMemories.first.content, 'Writes philosophy reflections at dawn.');
      expect(restoredMemories.first.category, MemoryCategory.workingHabit);

      final restoredChats = await db.getChatMessages();
      expect(restoredChats.length, 1);
      expect(restoredChats.first['text'], 'I have logged your morning reflection time, Marcus.');
    });
  });
}
