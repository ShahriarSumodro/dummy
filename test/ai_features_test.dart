import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remembrai/models/contact.dart';
import 'package:remembrai/models/commitment.dart';
import 'package:remembrai/models/action_draft.dart';
import 'package:remembrai/services/action_draft_service.dart';
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

  group('ActionDraftService Tests', () {
    final draftService = ActionDraftService();

    test('generates professional email follow-up template', () async {
      final contact = Contact(
        id: 1,
        name: 'Rahim Ahmed',
        company: 'Apex Corp',
        email: 'rahim@apex.com',
      );

      final commitment = Commitment(
        id: 10,
        title: 'Send revised quotation',
        contactId: 1,
        type: CommitmentType.promiseMade,
      );

      final draft = await draftService.generateDraftForCommitment(
        commitment: commitment,
        contact: contact,
        type: DraftType.email,
        forceOffline: true,
      );

      expect(draft.type, DraftType.email);
      expect(draft.recipientName, 'Rahim Ahmed');
      expect(draft.recipientContact, 'rahim@apex.com');
      expect(draft.subject, contains('Send revised quotation'));
      expect(draft.body, contains('Dear Rahim Ahmed'));
      expect(draft.status, DraftStatus.draft);
    });

    test('generates compact WhatsApp / SMS message template', () async {
      final commitment = Commitment(
        id: 11,
        title: 'Review proposal deck',
        contactName: 'Karim',
        type: CommitmentType.followUp,
      );

      final draft = await draftService.generateDraftForCommitment(
        commitment: commitment,
        type: DraftType.whatsapp,
        forceOffline: true,
      );

      expect(draft.type, DraftType.whatsapp);
      expect(draft.recipientName, 'Karim');
      expect(draft.body, contains('Hi Karim'));
      expect(draft.body, contains('Review proposal deck'));
    });
  });

  group('DeviceEventBus Hardware Abstraction Tests', () {
    final bus = DeviceEventBus();

    test('broadcasts companion hardware events', () async {
      final event = CompanionDeviceEvent(
        id: 'evt-1',
        type: CompanionEventType.commitmentDetected,
        title: 'Meeting promise captured',
        summary: 'Follow up with Rahim by tomorrow',
        requiresHaptic: true,
      );

      expectLater(
        bus.events,
        emits(predicate<CompanionDeviceEvent>((e) =>
            e.id == 'evt-1' &&
            e.title == 'Meeting promise captured' &&
            e.requiresHaptic)),
      );

      bus.dispatch(event);
      expect(bus.history.first.id, 'evt-1');
    });
  });
}
