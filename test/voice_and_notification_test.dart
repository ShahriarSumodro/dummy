import 'package:flutter_test/flutter_test.dart';
import 'package:remembrai/services/voice_service.dart';
import 'package:remembrai/services/notification_service.dart';
import 'package:remembrai/services/ai_service.dart';
import 'package:remembrai/models/assistant_settings.dart';
import 'package:remembrai/models/commitment.dart';
import 'package:remembrai/models/ai_extraction_result.dart';
import 'package:remembrai/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('VoiceService & Speech Processing Tests', () {
    test('cleanTextForSpeech strips markdown formatting correctly', () {
      const raw = '''
### Executive Briefing
Here is the summary:
- **Karim**: Prominded to deliver `draft_invoice.pdf` by *tomorrow*.
- [Click here](https://remembrai.app) to review.
```dart
void test() {}
```
      ''';

      final cleaned = VoiceService.cleanTextForSpeech(raw);

      // Should not contain markdown syntax
      expect(cleaned.contains('###'), isFalse);
      expect(cleaned.contains('**'), isFalse);
      expect(cleaned.contains('*tomorrow*'), isFalse);
      expect(cleaned.contains('`'), isFalse);
      expect(cleaned.contains('https://remembrai.app'), isFalse);
      expect(cleaned.contains('void test'), isFalse);

      // Should retain spoken content
      expect(cleaned.contains('Executive Briefing'), isTrue);
      expect(cleaned.contains('Karim'), isTrue);
      expect(cleaned.contains('draft_invoice.pdf'), isTrue);
      expect(cleaned.contains('Click here'), isTrue);
    });

    test('cleanTextForSpeech handles plain text cleanly', () {
      const plain = 'Meeting with Apex Corp is scheduled for 3 PM.';
      final cleaned = VoiceService.cleanTextForSpeech(plain);
      expect(cleaned, equals('Meeting with Apex Corp is scheduled for 3 PM.'));
    });
  });

  group('NotificationService Structure Tests', () {
    test('NotificationService singleton maintains proper channel constants', () {
      final service1 = NotificationService();
      final service2 = NotificationService();
      expect(identical(service1, service2), isTrue);

      expect(NotificationService.channelIdReminders, equals('remembrai_reminders'));
      expect(NotificationService.channelIdBriefing, equals('remembrai_briefings'));
    });
  });

  group('AssistantSettings Voice & Notification Persistence', () {
    late DatabaseService dbService;

    setUp(() async {
      dbService = DatabaseService();
      await dbService.initInMemoryForTesting();
    });

    test('saves and loads voice & notification preferences', () async {
      final initial = await dbService.getAssistantSettings();
      expect(initial.autoSpeakResponses, isFalse);
      expect(initial.notificationsEnabled, isTrue);
      expect(initial.speechRate, equals(0.5));

      final updated = initial.copyWith(
        autoSpeakResponses: true,
        notificationsEnabled: false,
        speechRate: 0.8,
        language: AssistantLanguage.bangla,
      );

      await dbService.saveAssistantSettings(updated);

      final loaded = await dbService.getAssistantSettings();
      expect(loaded.autoSpeakResponses, isTrue);
      expect(loaded.notificationsEnabled, isFalse);
      expect(loaded.speechRate, equals(0.8));
      expect(loaded.language, equals(AssistantLanguage.bangla));
    });

    test('insertCommitment, updateCommitment, and deleteCommitment execute smoothly', () async {
      final commitment = Commitment(
        title: 'Send Revised Contract',
        description: 'Promise made during review meeting',
        type: CommitmentType.promiseMade,
        dueDate: DateTime.now().add(const Duration(days: 2)),
      );

      final id = await dbService.insertCommitment(commitment);
      expect(id, isPositive);

      final all = await dbService.getAllCommitments();
      expect(all.length, equals(1));
      expect(all.first.title, equals('Send Revised Contract'));

      final updated = all.first.copyWith(
        status: CommitmentStatus.completed,
      );
      await dbService.updateCommitment(updated);

      final completed = await dbService.getAllCommitments(statusFilter: 'completed');
      expect(completed.length, equals(1));

      await dbService.deleteCommitment(id);
      final remaining = await dbService.getAllCommitments();
      expect(remaining.isEmpty, isTrue);
    });
  });

  group('Voice AI Decoding & Auto-Setup Tests', () {
    test('MockAiService extracts and decodes voice notes into structured promises and contacts', () async {
      final mock = MockAiService();
      const voiceTranscript =
          'I had a call with Karim from Apex Corp. I promised to send him the quotation tomorrow at 4 PM.';

      final result = await mock.extract(text: voiceTranscript);

      expect(result.commitments.isNotEmpty, isTrue);
      final comm = result.commitments.first;
      expect(comm.type, equals(CommitmentType.promiseMade));
      expect(comm.dueDate, isNotNull);

      expect(result.contacts.isNotEmpty, isTrue);
      final contact = result.contacts.first;
      expect(contact.name.toLowerCase(), contains('karim'));
    });

    test('formatCommitmentSpeech normalizes first-person echoing into executive assistant speech', () {
      final speech1 = VoiceService.formatCommitmentSpeech(
        title: "I've a meeting at 10:30 with Raju",
        type: CommitmentType.task,
        dueDate: DateTime(2026, 11, 16, 10, 30),
      );
      expect(speech1, anyOf(contains('You have a meeting with Raju'), contains('You have a Meeting at 10:30 with Raju')));
      expect(speech1.contains("I've"), isFalse);

      final speech2 = VoiceService.formatCommitmentSpeech(
        title: 'I promised to send the revised quotation',
        type: CommitmentType.promiseMade,
        contactName: 'Karim',
        dueDate: DateTime(2026, 11, 17, 16, 0),
      );
      expect(speech2.toLowerCase(), contains('you promised karim to send the revised quotation'));
      expect(speech2.contains('I promised'), isFalse);

      final speech3 = VoiceService.formatCommitmentSpeech(
        title: 'They promised to send the commercial contract',
        type: CommitmentType.promiseReceived,
        contactName: 'Apex Corp',
      );
      expect(speech3.toLowerCase(), contains('apex corp promised you to send the commercial contract'));
    });

    test('formatCommitmentSpeech eliminates duplicate contact names and conflicting embedded dates', () {
      final speech1 = VoiceService.formatCommitmentSpeech(
        title: "Raheem I will send the quotation tomorrow by 3 p.m.",
        type: CommitmentType.promiseMade,
        contactName: "Raheem",
        dueDate: DateTime(2026, 11, 14, 15, 0),
      );
      expect(speech1, equals('You promised Raheem to send the quotation on Saturday, Nov 14 at 3:00 PM.'));
      expect(speech1.contains('Raheem to Raheem'), isFalse);
      expect(speech1.contains('I will'), isFalse);
      expect(speech1.contains('tomorrow by 3 p.m. on Saturday'), isFalse);

      final speech2 = VoiceService.formatCommitmentSpeech(
        title: "I have a meeting tomorrow with Raju Ahmed at 10:00",
        type: CommitmentType.task,
        contactName: "Raju Ahmed",
        dueDate: DateTime(2026, 11, 16, 10, 0),
      );
      expect(speech2.toLowerCase(), equals('you have a meeting with raju ahmed on monday, nov 16 at 10:00 am.'));
      expect(speech2.contains('tomorrow'), isFalse);
    });

    test('MockAiService filters casual banter and isolates actionable commitments', () async {
      final mock = MockAiService();
      const rawBanterTranscript =
          "What's up? Yeah, man, it's all good. Hello, do you have a class tomorrow? Yeah, maybe, I'm not sure. Okay, so let's see, call our teacher to get ready of our class. Okay, it's all good.";

      final result = await mock.extract(text: rawBanterTranscript);
      expect(result.commitments.isNotEmpty, isTrue);
      final comm = result.commitments.first;
      expect(comm.title.toLowerCase(), contains('call our teacher'));
      expect(comm.title.toLowerCase().contains("what's up"), isFalse);
      expect(comm.title.toLowerCase().contains("hey man"), isFalse);
    });

    test('MockAiService dynamically extracts Person D and Person B from 5-person meeting note', () async {
      final mock = MockAiService();
      const multiPersonNote =
          'Had a discussion with 5 people. Person D said he will send the revised design by tomorrow. Person B will do nothing, and the other one said nothing. and I promised to do the work for person D, and no one else.';

      final result = await mock.extract(text: multiPersonNote);
      expect(result.hasUnresolvedParticipants, isTrue);

      final tags = result.unresolvedParticipants.map((p) => p.placeholderTag).toList();
      expect(tags.contains('Person D'), isTrue);
      expect(tags.contains('Person B'), isTrue);
    });

    test('Self-correction and disfluency: ignores retracted tomorrow and extracts Nov 16 at 3 PM', () async {
      final mock = MockAiService();
      const speechNote =
          'Hi, I have a meeting tomorrow, not tomorrow, maybe 16th of November at 3 p.m. at my office.';

      final result = await mock.extract(text: speechNote);
      expect(result.commitments.isNotEmpty, isTrue);
      final comm = result.commitments.first;

      // Retracted 'tomorrow' should not be used as the due date
      expect(comm.dueDate, isNotNull);
      expect(comm.dueDate!.month, equals(11));
      expect(comm.dueDate!.day, equals(16));
      expect(comm.dueDate!.hour, equals(15));
      expect(comm.dueDate!.minute, equals(0));

      // Greeting 'Hi,' must be stripped and title normalized
      expect(comm.title.toLowerCase().startsWith('hi'), isFalse);
      expect(comm.title, equals('Meeting at office'));

      // Voice assistant speech output
      final spoken = VoiceService.formatCommitmentSpeech(
        title: comm.title,
        type: comm.type,
        dueDate: comm.dueDate,
      );
      expect(spoken.contains('Hi,'), isFalse);
      expect(spoken.contains('May 16th'), isFalse);
      expect(spoken, contains('You have a meeting at office on'));
      expect(spoken, contains('Nov 16 at 3:00 PM.'));
    });
  });
}
