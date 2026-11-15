import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remembrai/screens/home_screen.dart';
import 'package:remembrai/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (MethodCall methodCall) async => 1,
    );
  });

  group('Companion-First Home Screen Tests (Cycle 4 / Section 15.3)', () {
    late DatabaseService db;

    setUp(() async {
      db = DatabaseService();
      await db.initInMemoryForTesting();
      await db.clearAllData();
    });

    testWidgets('HomeScreen renders companion greeting, persona badge, and inline chat bar',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      // Wait for async database queries to settle
      for (int i = 0; i < 30; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
        if (find.text('Dummy.').evaluate().isNotEmpty &&
            find.byType(TextField).evaluate().isNotEmpty) {
          break;
        }
      }

      // 1. Verify AppBar title is Dummy.
      expect(find.text('Dummy.'), findsOneWidget);

      // 2. Verify Presence Header contains companion status
      expect(find.textContaining('Your companion is active'), findsOneWidget);

      // 3. Verify Quick Conversational Input Bar is present
      expect(
        find.text('Talk to Dummy. or log a follow-up...'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);

      // 4. Verify Spoken Briefing card is visible
      expect(find.text('Daily Executive Briefing'), findsOneWidget);

      // 5. Verify Metric labels are present
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('Alerts'), findsOneWidget);
      expect(find.text('Network'), findsOneWidget);
    });

    testWidgets('Typing in Quick Conversational bar updates input state',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      for (int i = 0; i < 30; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
        if (find.byType(TextField).evaluate().isNotEmpty) break;
      }

      final inputFinder = find.byType(TextField);
      expect(inputFinder, findsOneWidget);

      await tester.enterText(inputFinder, 'What commitments are due today?');
      await tester.pump();

      expect(find.text('What commitments are due today?'), findsOneWidget);
    });
  });
}
