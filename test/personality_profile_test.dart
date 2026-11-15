import 'package:flutter_test/flutter_test.dart';
import 'package:remembrai/models/assistant_settings.dart';
import 'package:remembrai/models/contact.dart';
import 'package:remembrai/models/commitment.dart';
import 'package:remembrai/models/memory_item.dart';
import 'package:remembrai/models/personality_profile.dart';
import 'package:remembrai/services/ai_query_service.dart';
import 'package:remembrai/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('PersonalityProfile Model & Presets (Module 10)', () {
    test('Preset archetypes provide expected trait configurations', () {
      final companion = PersonalityProfile.companion;
      expect(companion.id, 'companion');
      expect(companion.warmth, greaterThanOrEqualTo(4.0));
      expect(companion.humor, greaterThanOrEqualTo(3.0));

      final chiefOfStaff = PersonalityProfile.chiefOfStaff;
      expect(chiefOfStaff.id, 'chiefOfStaff');
      expect(chiefOfStaff.formality, 5.0);
      expect(chiefOfStaff.brevity, 5.0);
      expect(chiefOfStaff.humor, 1.0);

      final casualPartner = PersonalityProfile.casualPartner;
      expect(casualPartner.id, 'casualPartner');
      expect(casualPartner.formality, lessThanOrEqualTo(2.0));
      expect(casualPartner.humor, greaterThanOrEqualTo(4.0));

      final calmMentor = PersonalityProfile.calmMentor;
      expect(calmMentor.id, 'calmMentor');
      expect(calmMentor.warmth, 5.0);
    });

    test('PersonalityProfile map serialization round-trip', () {
      final original = PersonalityProfile(
        id: 'custom_pro',
        name: 'Custom Focus',
        tagline: 'Deep flow and minimum noise',
        description: 'Tuned for intensive coding sprints',
        formality: 2.5,
        humor: 2.0,
        warmth: 3.5,
        brevity: 4.5,
        proactivity: 2.0,
      );

      final map = original.toMap();
      final restored = PersonalityProfile.fromMap(map);

      expect(restored.id, 'custom_pro');
      expect(restored.name, 'Custom Focus');
      expect(restored.formality, 2.5);
      expect(restored.humor, 2.0);
      expect(restored.warmth, 3.5);
      expect(restored.brevity, 4.5);
      expect(restored.proactivity, 2.0);
    });

    test('toPromptDirectives produces structured LLM instructions', () {
      final directives = PersonalityProfile.chiefOfStaff.toPromptDirectives();
      expect(directives, contains('[PERSONALITY PROFILE: Executive Chief of Staff]'));
      expect(directives, contains('Formality (5.0/5.0): Formal, professional, executive register.'));
      expect(directives, contains('Brevity (5.0/5.0): Ultra-crisp bullet points, high-signal, zero fluff.'));
    });
  });

  group('AssistantSettings & Database Persona Persistence', () {
    late DatabaseService db;

    setUp(() async {
      db = DatabaseService();
      await db.initInMemoryForTesting();
      await db.clearAllData();
    });

    test('Saves and restores active PersonalityProfile without affecting existing data', () async {
      // 1. Seed existing data (contacts, commitments, memories)
      final contactId = await db.insertContact(Contact(
        name: 'Rashid Khan',
        company: 'Apex Ltd',
      ));
      final commitmentId = await db.insertCommitment(Commitment(
        title: 'Review quarterly balance sheet',
        contactId: contactId,
        status: CommitmentStatus.pending,
      ));
      final memoryId = await db.insertMemory(MemoryItem(
        category: MemoryCategory.preference,
        content: 'Prefers weekly executive summaries on Mondays',
        contactId: contactId,
      ));

      // 2. Change personality profile to Chief of Staff
      final cosSettings = AssistantSettings(
        personality: PersonalityProfile.chiefOfStaff,
        tone: AssistantTone.executive,
        language: AssistantLanguage.english,
        proactivity: ProactivityLevel.high,
      );
      await db.saveAssistantSettings(cosSettings);

      // 3. Retrieve settings
      final retrievedSettings = await db.getAssistantSettings();
      expect(retrievedSettings.personality.id, 'chiefOfStaff');
      expect(retrievedSettings.personality.formality, 5.0);

      // 4. Verify architectural rule: existing memory/commitments/contacts must be 100% intact
      final contact = await db.getContact(contactId);
      final commitment = await db.getCommitment(commitmentId);
      final memory = await db.getMemory(memoryId);

      expect(contact, isNotNull);
      expect(contact!.name, 'Rashid Khan');
      expect(commitment, isNotNull);
      expect(commitment!.title, 'Review quarterly balance sheet');
      expect(memory, isNotNull);
      expect(memory!.content, 'Prefers weekly executive summaries on Mondays');

      // 5. Change to Casual Creative Partner and verify persistence again
      final casualSettings = retrievedSettings.copyWith(
        personality: PersonalityProfile.casualPartner,
        tone: AssistantTone.conversational,
      );
      await db.saveAssistantSettings(casualSettings);

      final secondRetrieval = await db.getAssistantSettings();
      expect(secondRetrieval.personality.id, 'casualPartner');
      expect(secondRetrieval.personality.humor, greaterThanOrEqualTo(4.0));

      final memoryAfterSecondSwitch = await db.getMemory(memoryId);
      expect(memoryAfterSecondSwitch, isNotNull);
    });
  });

  group('AiQueryService Persona Delivery Tests', () {
    late DatabaseService db;
    final queryService = AiQueryService();

    setUp(() async {
      db = DatabaseService();
      await db.initInMemoryForTesting();
      await db.clearAllData();
    });

    test('Executive Chief of Staff responds with crisp, decision-focused delivery', () async {
      await db.saveAssistantSettings(const AssistantSettings(
        personality: PersonalityProfile.chiefOfStaff,
        tone: AssistantTone.executive,
      ));

      final greetingRes = await queryService.queryMemory('hello');
      expect(greetingRes.answer, contains('Executive Chief of Staff active'));

      final nightRes = await queryService.queryMemory('I have been working late on this for hours');
      expect(nightRes.answer, contains('Continuous focus session logged'));
      expect(nightRes.answer, contains('Recommendation'));
    });

    test('Casual Creative Partner responds with witty, relaxed camaraderie', () async {
      await db.saveAssistantSettings(const AssistantSettings(
        personality: PersonalityProfile.casualPartner,
        tone: AssistantTone.conversational,
      ));

      final greetingRes = await queryService.queryMemory('hello');
      expect(greetingRes.answer, contains('What’s happening?'));

      final nightRes = await queryService.queryMemory('I have been working late on this for hours');
      expect(nightRes.answer, contains('Yo, you’ve been at it for hours'));
      expect(nightRes.answer, contains('call it a night'));
    });

    test('Calm Mentor responds with patient, reflective advisor tone', () async {
      await db.saveAssistantSettings(const AssistantSettings(
        personality: PersonalityProfile.calmMentor,
        tone: AssistantTone.analytical,
      ));

      final greetingRes = await queryService.queryMemory('hello');
      expect(greetingRes.answer, contains('Peace to your day'));

      final nightRes = await queryService.queryMemory('I have been working late on this for hours');
      expect(nightRes.answer, contains('quiet hours to this work'));
      expect(nightRes.answer, contains('clarity comes with rest'));
    });

    test('Default RemembrAI Companion delivers warm, balanced executive follow-through', () async {
      await db.saveAssistantSettings(const AssistantSettings(
        personality: PersonalityProfile.companion,
        tone: AssistantTone.companion,
      ));

      final greetingRes = await queryService.queryMemory('hello');
      expect(greetingRes.answer, contains('RemembrAI, your personal companion'));
      expect(greetingRes.answer, contains('Always right here beside you'));

      final nightRes = await queryService.queryMemory('I have been working late on this for hours');
      expect(nightRes.answer, contains('You’ve been at it for hours! Don’t burn yourself out'));
    });
  });
}
