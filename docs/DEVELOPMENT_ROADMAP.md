
# Dummy. — Development Roadmap

## Phase 1: Working Mobile Prototype ✅

- Flutter project setup with Android support.
- Material 3 theme with dynamic light/dark modes.
- 4-tab bottom navigation: Home, Promises, People, Memory.
- SQLite local database via `sqflite`, with foreign keys and indexes.
- People feature: Add, edit, delete, search, and detail view.
- Promises feature: Promise Made, Promise Received, Follow-up, and Task.
- Reminders feature: Recurring rules, snooze 1h / 1d, and completion toggling.
- Home dashboard with metrics and urgent priority queue.

---

## Phase 2: AI Memory Extraction & Confirmation Workflow ✅

- AI Service architecture with supported cloud providers, fallback handling, and mock implementations for testing.
- Quick AI Memory Capture.
- AI extraction of contacts, promises, reminders, and memories.
- Review and Confirmation Workflow through `AiReviewScreen`.
- Settings screen for API configuration and AI preferences.
- Bangla and English input support, including relative date and time parsing.

---

## Phase 3 & 4: Comprehensive Personal Memory Suite

### 1. Conversational AI Memory Assistant

Files: `assistant_chat_screen.dart`, `ai_query_service.dart`

- Ask natural-language questions about stored personal information.
- Examples:
  - "What did I promise Rahim?"
  - "Show pending promises."
  - "What happened in my last meeting?"
- Local Grounded RAG: Answers are grounded in relevant SQLite records.
- Distinguish verified records from unverified memories.
- Cite source records such as contacts, promises, and meetings.
- Interactive follow-up actions and contextual suggestions.
- Emotional awareness in conversations without assuming or diagnosing the user's mental state.

### 2. Action Assistance & Follow-Up Drafter

Files: `action_draft_service.dart`, `action_drafts_screen.dart`

- Permission levels: Suggest → Prepare Draft → Ask for Approval → Execute/Send.
- Generate email follow-ups, WhatsApp/SMS messages, and meeting memos from stored context.
- Review and edit subject and message body.
- Copy drafts to clipboard.
- Track delivery status: `draft` → `approved` → `sent`.

### 3. Meeting Intelligence Hub

Files: `meetings_screen.dart`, `meeting_form_screen.dart`, `meeting_detail_screen.dart`, `meeting_summary_screen.dart`

- Log in-person, Google Meet, or Zoom discussions.
- Record meeting notes and relevant details.
- AI-assisted decision and action-item extraction.
- Identify promises, responsibilities, and follow-up requirements.
- Convert meeting action items into tracked promises.
- Link meeting participants to existing or newly created contacts.

### 4. Companies & Organizations Directory

Files: `organizations_screen.dart`, `organization_detail_screen.dart`

- Group contacts and promises by client organization.
- View associated people and pending promises.
- Access organization-level relationship context.
- Review promises and interactions associated with an organization.

### 5. Pre-Meeting & Executive Daily Briefing Engine

Files: `briefing_screen.dart`

**Daily Briefing**
- Summarize overdue promises, today's commitments, scheduled meetings, and reminders.
- Provide an actionable daily overview.

**Contact Dossier**
- Summarize who a person is.
- Show promises made to and received from them.
- Present relevant interaction history.
- Provide useful conversation context and meeting openers.

### 6. Relationship Health & Follow-Up Radar

Files: `relationship_health_screen.dart`

- Analyze communication frequency and interaction history.
- Identify overdue promises.
- Highlight relationships that may need follow-up.
- Surface stale interactions and neglected contacts.

### 7. Unified Global Search

Files: `global_search_screen.dart`

- Search across contacts, organizations, promises, and meetings.
- Provide contextual search results.
- Navigate directly to relevant records.

### 8. Data Privacy, Security & Portability

Files: `data_privacy_screen.dart`

- Local-first SQLite database (not encrypted).
- Optional cloud AI processing with explicit user consent.
- JSON data export and backup.
- Double-confirmed permanent data wipe.
- Clear distinction between locally stored data and information sent to external AI services.

**Security Note:** Local database encryption is not currently implemented. Do not describe the database as encrypted until encryption has been implemented and verified.

### 9. Hardware & Wearable Companion Abstraction

Files: `device_event_bus.dart`, `hardware_companion_screen.dart`

- Software First, Hardware Later — One Platform, Multiple Interfaces.
- Companion device event bus for reminder triggers, promise alerts, and haptic events.
- Wearable OLED companion simulator.
- Architecture intended to support future wearable and external hardware integrations.

**Note:** The simulator and event abstraction do not establish that physical wearable hardware integration is complete.

### 10. Voice Capture & Meeting Intelligence

Files: `voice_capture_screen.dart`, `voice_service.dart`, `diarization_service.dart`, `meeting_analysis_service.dart`

- Voice-based personal memory capture.
- Meeting audio recording.
- Speech transcription.
- Speaker diarization and speaker identification.
- Estimated emotional tone detection from speaker utterances.
- Meeting summaries and promise extraction.
- Participant resolution for unidentified speakers.
- AI-assisted review of extracted information.
- Voice feedback and recording-state handling.
- Audio recording lifecycle management.

### 11. Centralized Saving & Data Consistency

File: `capture_save_service.dart`

- Centralized saving of extracted contacts, promises, reminders, and memories.
- Consistent save behavior across voice capture and AI review workflows.
- Preserve relationships between contacts, promises, reminders, interactions, and memories.
- Support unverified memory status.
- Transaction-based saving where supported.
- Undo support for recent capture operations where implemented.
- Synchronize reminder notifications after saving.

---

## Phase 5: Reliability, Localization & Product Refinement

### 1. Bangla & Bilingual Intelligence

- Convert Bangla numerals into standard numeric values.
- Understand Bangla and Banglish dates and times.
- Improve relative-date interpretation.
- Handle negation when interpreting dates and reminders.
- Improve extraction accuracy for mixed Bangla-English conversations.
- Test ambiguous date and time expressions.

### 2. Product Language & Interface Consistency

- Use "Promises" consistently instead of "Commitments" in primary interface wording.
- Maintain consistent terminology across Home, Promises, People, and Memory.
- Improve empty states, loading states, and error messages.
- Ensure voice capture, meeting summaries, and AI review use consistent language.

### 3. AI Reliability

- Keep AI provider prompts consistent.
- Improve emotional-awareness behavior across supported providers.
- Prevent invented contacts, promises, dates, and memories.
- Handle unknown information transparently.
- Ensure AI responses distinguish stored facts from generated suggestions.
- Test cloud-provider failures and fallback behavior.

### 4. Database & Save Reliability

- Verify database relationships and foreign-key behavior.
- Test centralized saving and rollback.
- Verify undo behavior across all saved entity types.
- Ensure reminder notifications are synchronized correctly.
- Test application restart and data persistence.
- Review database migration and schema-version handling.

### 5. Voice & Meeting Reliability

- Fix and verify speaker diarization parsing.
- Validate speaker identity mapping.
- Test recordings with multiple speakers.
- Test long recordings and audio-processing failures.
- Verify recording lifecycle and wakelock handling.
- Ensure participant resolution works before saving unresolved identities.
- Validate meeting summary and promise extraction accuracy.

### 6. Regression & End-to-End Testing

Test the following complete workflows:

1. Voice capture → Extraction → Review → Save.
2. Meeting recording → Transcription → Diarization → Summary.
3. Meeting summary → Participant resolution → Promise extraction → Save.
4. Contact creation → Interaction history → Promise association.
5. Promise creation → Reminder scheduling → Notification delivery.
6. AI query → Grounded database retrieval → Source reference.
7. Capture → Save → Undo → Database verification.

---

## Phase 6: Security, Performance & Release Preparation

### 1. Security Improvements

- Evaluate local database encryption.
- Secure API key storage.
- Review cloud AI consent and data transmission.
- Protect sensitive personal information.
- Define backup and data deletion policies.

### 2. Performance & Stability

- Optimize SQLite queries and indexes.
- Reduce unnecessary database reloads.
- Improve long-running AI operations.
- Handle network failures and API timeouts.
- Optimize audio processing and memory usage.
- Test low-memory Android devices.

### 3. Release Preparation

- Test on multiple Android devices and screen sizes.
- Verify permissions for microphone, notifications, and storage.
- Test fresh installation and application upgrades.
- Prepare release builds.
- Create onboarding and user documentation.
- Conduct a small closed beta before public release.

---

## Phase 7: Future Expansion — One Platform, Multiple Interfaces

### 1. Personal Assistant Expansion

- More natural conversational interaction.
- Configurable assistant personality.
- Better contextual memory across work and everyday life.
- Proactive reminders and follow-up suggestions.
- Personalized daily planning and assistance.

### 2. Wearable Companion

- Physical wearable device integration.
- Bluetooth communication with the mobile application.
- Voice interaction and notification delivery.
- Haptic feedback.
- Device configuration and software updates.

### 3. Desktop & Cross-Platform Support

- Desktop companion interface.
- iOS application.
- Cross-device synchronization.
- Consistent personal memory across supported devices.

### 4. Advanced Integrations

- Calendar integration.
- Email and messaging integrations.
- External task-management services.
- Additional communication channels.
- More AI provider options.

---

## Development Principles

1. Local First: Core personal data remains accessible locally.
2. User Control: AI-generated information must not silently become confirmed personal facts.
3. Privacy by Design: Cloud processing requires explicit user consent.
4. Incremental Development: Build, test, and stabilize features before expanding.
5. Modular Architecture: Keep services and integrations replaceable.
6. Data Consistency: Maintain reliable relationships across all stored information.
7. Hardware Independence: Build the software platform before committing to specialized hardware.
8. Honest Product Status: Mark a feature complete only after its primary workflow has been tested successfully.
