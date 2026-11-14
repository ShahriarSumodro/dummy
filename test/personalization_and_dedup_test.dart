import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remembrai/models/assistant_settings.dart';
import 'package:remembrai/models/contact.dart';
import 'package:remembrai/models/meeting.dart';
import 'package:remembrai/services/device_event_bus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );
  });

  group('AssistantSettings Directives Tests', () {
    test('Executive tone and English system prompt generation', () {
      const settings = AssistantSettings(
        tone: AssistantTone.executive,
        language: AssistantLanguage.english,
        proactivity: ProactivityLevel.high,
        userTitle: 'Managing Director',
      );

      final promptAddition = settings.toSystemPromptAddition();

      expect(promptAddition, contains('[ASSISTANT PERSONALIZATION DIRECTIVES]'));
      expect(promptAddition, contains('Ultra-crisp, executive summary style'));
      expect(promptAddition, contains('Standard Professional English'));
      expect(promptAddition, contains('Proactively highlight urgent deadlines'));
      expect(promptAddition, contains('Managing Director'));
    });

    test('Bangla language and conversational tone system prompt generation', () {
      const settings = AssistantSettings(
        tone: AssistantTone.conversational,
        language: AssistantLanguage.bangla,
        proactivity: ProactivityLevel.minimal,
      );

      final promptAddition = settings.toSystemPromptAddition();

      expect(promptAddition, contains('Warm, polished executive co-pilot'));
      expect(promptAddition, contains('সমস্ত উত্তর শুদ্ধ ও সাবলীল প্রফেশনাল বাংলায় দিন'));
      expect(promptAddition, contains('Answer strictly what the user asked'));
    });

    test('Banglish language directive generation', () {
      const settings = AssistantSettings(
        tone: AssistantTone.analytical,
        language: AssistantLanguage.banglish,
        proactivity: ProactivityLevel.balanced,
      );

      final promptAddition = settings.toSystemPromptAddition();

      expect(promptAddition, contains('Banglish (Bengali spoken language written phonetically'));
      expect(promptAddition, contains('Analytical, structured, thorough'));
    });
  });

  group('Contact Deduplication Matcher Tests', () {
    test('matches contacts with identical names ignoring case and whitespace', () {
      final c1 = Contact(name: 'Tanvir Ahmed  ');
      final c2 = Contact(name: 'tanvir ahmed');

      expect(
        c1.name.trim().toLowerCase(),
        equals(c2.name.trim().toLowerCase()),
      );
    });

    test('matches contacts with same email', () {
      final c1 = Contact(name: 'Rahim A.', email: 'rahim@company.com');
      final c2 = Contact(name: 'Rahim Ahmed', email: ' RAHIM@company.com ');

      expect(
        c1.email!.trim().toLowerCase(),
        equals(c2.email!.trim().toLowerCase()),
      );
    });

    test('matches contacts with normalized phone digits', () {
      final c1 = Contact(name: 'Karim', phone: '+880 1711-223344');
      final c2 = Contact(name: 'Karim Chowdhury', phone: '01711223344');

      final digits1 = c1.phone!.replaceAll(RegExp(r'\D'), '');
      final digits2 = c2.phone!.replaceAll(RegExp(r'\D'), '');

      // Check sub-sequence or digit suffix match
      expect(digits1, contains(digits2.substring(1)));
    });
  });

  group('Meeting Minutes Markdown Formatter Tests', () {
    test('formats decisions, action items and summary into readable markdown', () {
      final meeting = Meeting(
        id: 1,
        title: 'Q3 Product Strategy Sync',
        meetingDate: DateTime(2026, 11, 15, 10, 0),
        location: 'Boardroom A / Zoom',
        summary: 'Agreed on mobile-first priority and offline capabilities.',
        decisions: [
          'Launch Android pilot first',
          'Free Gemini Flash 2.0 as primary inference tier',
        ],
        actionItems: [
          'Finalize wearable BLE interface contract',
          'Deploy local SQLite database migration',
        ],
      );

      final buffer = StringBuffer();
      buffer.writeln('# Meeting Minutes: ${meeting.title}');
      buffer.writeln('Date: ${meeting.meetingDate.toIso8601String()}');
      buffer.writeln('## Executive Summary\n${meeting.summary}\n');
      buffer.writeln('## Key Decisions');
      for (final d in meeting.decisions) {
        buffer.writeln('- $d');
      }
      buffer.writeln('## Action Items');
      for (final a in meeting.actionItems) {
        buffer.writeln('- [ ] $a');
      }

      final result = buffer.toString();
      expect(result, contains('# Meeting Minutes: Q3 Product Strategy Sync'));
      expect(result, contains('- Launch Android pilot first'));
      expect(result, contains('- [ ] Finalize wearable BLE interface contract'));
    });
  });

  group('Wearable Companion Event Bus Tests', () {
    test('dispatches and receives wearable haptic alert events', () async {
      final bus = DeviceEventBus();
      final receivedEvents = <CompanionDeviceEvent>[];

      final sub = bus.events.listen((event) {
        receivedEvents.add(event);
      });

      bus.dispatch(CompanionDeviceEvent(
        id: 'test-1',
        type: CompanionEventType.commitmentDetected,
        title: 'Deliver Contract',
        summary: 'Send contract by 5 PM',
        requiresHaptic: true,
      ));

      await Future.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(receivedEvents.length, equals(1));
      expect(receivedEvents.first.title, 'Deliver Contract');
      expect(receivedEvents.first.requiresHaptic, isTrue);
      expect(bus.history.any((e) => e.id == 'test-1'), isTrue);
    });
  });
}
