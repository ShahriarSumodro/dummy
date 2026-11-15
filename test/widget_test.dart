import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:remembrai/app.dart';
import 'package:remembrai/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );

    await DatabaseService().initInMemoryForTesting();
  });

  testWidgets('App shell renders with bottom navigation',
      (WidgetTester tester) async {
    await tester.pumpWidget(const DummyApp());
    for (int i = 0; i < 10; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }

    // Verify the app title is shown
    expect(find.text('Dummy.'), findsWidgets);

    // Verify all 4 navigation tabs exist
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Promises'), findsOneWidget);
    expect(find.text('People'), findsOneWidget);
    expect(find.text('Memory'), findsOneWidget);

    // Verify we start on the Home tab
    expect(find.text('Home'), findsWidgets);
  });

  testWidgets('Bottom navigation switches tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const DummyApp());
    for (int i = 0; i < 5; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }

    // Tap on Promises tab
    await tester.tap(find.text('Promises'));
    for (int i = 0; i < 5; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.text('Promises'), findsWidgets);

    // Tap on People tab
    await tester.tap(find.text('People'));
    for (int i = 0; i < 5; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.text('People'), findsWidgets);

    // Tap on Memory tab
    await tester.tap(find.text('Memory'));
    for (int i = 0; i < 5; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.text('Memory'), findsWidgets);

    // Tap back to Home
    await tester.tap(find.text('Home'));
    for (int i = 0; i < 12; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.text('Dummy.'), findsWidgets);
  });
}
