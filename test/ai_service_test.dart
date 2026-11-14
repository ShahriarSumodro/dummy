import 'package:flutter_test/flutter_test.dart';
import 'package:remembrai/models/contact.dart';
import 'package:remembrai/models/commitment.dart';
import 'package:remembrai/services/ai_service.dart';

void main() {
  group('MockAiService Tests', () {
    final aiService = MockAiService();

    final testContacts = [
      Contact(id: 1, name: 'Rahim Ahmed', company: 'Apex Corp'),
      Contact(id: 2, name: 'Karim Ullah', company: 'TechBD'),
    ];

    test('extracts promise made and matches existing contact', () async {
      const input = 'I promised Rahim I will send the quotation tomorrow by 3 PM.';
      final result = await aiService.extract(
        text: input,
        existingContacts: testContacts,
      );

      expect(result.commitments.isNotEmpty, isTrue);
      final commitment = result.commitments.first;
      expect(commitment.type, CommitmentType.promiseMade);
      expect(commitment.contactName, 'Rahim Ahmed');
      expect(commitment.matchedContactId, 1);
      expect(commitment.dueDate, isNotNull);
      expect(result.reminders.isNotEmpty, isTrue);
    });

    test('extracts promise received from third party', () async {
      const input = 'They promised to send the audited financial statements on Friday.';
      final result = await aiService.extract(
        text: input,
        existingContacts: testContacts,
      );

      expect(result.commitments.isNotEmpty, isTrue);
      final commitment = result.commitments.first;
      expect(commitment.type, CommitmentType.promiseReceived);
      expect(commitment.dueDate, isNotNull);
    });

    test('extracts follow-up task', () async {
      const input = 'Follow up with Karim next week about the invoice payment.';
      final result = await aiService.extract(
        text: input,
        existingContacts: testContacts,
      );

      expect(result.commitments.isNotEmpty, isTrue);
      final commitment = result.commitments.first;
      expect(commitment.type, CommitmentType.followUp);
      expect(commitment.contactName, 'Karim Ullah');
      expect(commitment.matchedContactId, 2);
    });
  });
}
