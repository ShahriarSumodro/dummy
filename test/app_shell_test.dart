import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remembrai/screens/shell_screen.dart';
import 'package:remembrai/screens/home_screen.dart';
import 'package:remembrai/screens/commitments_screen.dart';
import 'package:remembrai/screens/people_screen.dart';
import 'package:remembrai/screens/memory_hub_screen.dart';
import 'package:remembrai/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final db = DatabaseService();
    await db.initInMemoryForTesting();
  });

  group('App Shell Tests (Stage 2)', () {
    testWidgets('ShellScreen mounts with floating bottom bar and 4+1 structure', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ShellScreen(),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }

      // Check tab items
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Promises'), findsOneWidget);
      expect(find.text('People'), findsOneWidget);
      expect(find.text('Memory'), findsOneWidget);

      // Verify default tab is HomeScreen
      expect(find.byType(HomeScreen), findsOneWidget);

      // Tap Commitments/Promises tab
      await tester.tap(find.text('Promises'));
      for (int i = 0; i < 5; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
      expect(find.byType(CommitmentsScreen), findsOneWidget);

      // Tap People tab
      await tester.tap(find.text('People'));
      for (int i = 0; i < 5; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
      expect(find.byType(PeopleScreen), findsOneWidget);

      // Tap Memory tab
      await tester.tap(find.text('Memory'));
      for (int i = 0; i < 5; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
      expect(find.byType(MemoryHubScreen), findsOneWidget);
    });

    testWidgets('Tapping center Capture button presents capture sheet options', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ShellScreen(),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }

      // Find center FAB
      final fabFinder = find.byIcon(Icons.add_rounded);
      expect(fabFinder, findsOneWidget);

      await tester.tap(fabFinder);
      for (int i = 0; i < 5; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }

      // Verify bottom sheet options
      expect(find.text('Capture Business Memory'), findsOneWidget);
      expect(find.text('Voice Transcribe & Decode'), findsOneWidget);
      expect(find.text('Quick Text Note'), findsOneWidget);
      expect(find.text('Log Business Meeting'), findsOneWidget);
    });
  });
}
