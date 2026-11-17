
# Dummy. — System Architecture

## Architecture Overview

Dummy. is a local-first, modular mobile application built with Flutter and SQLite. Core personal data is stored locally. Optional cloud AI services support extraction, transcription, and conversational assistance with explicit user consent.

```text
┌──────────────────────────────────────────────────────────┐
│                    Presentation Layer                    │
│                                                          │
│       Home · Promises · People · Memory                  │
│       Voice Capture · Meeting Summary · AI Review        │
│       Material 3 · Adaptive Navigation                   │
└────────────────────────────┬─────────────────────────────┘
                             │
┌────────────────────────────▼─────────────────────────────┐
│                    Service Layer                         │
│                                                          │
│  CaptureSaveService · DatabaseService · AIService        │
│  AIQueryService · VoiceService · DiarizationService       │
│  MeetingAnalysisService · Notification Handling          │
└────────────────────────────┬─────────────────────────────┘
                             │
┌────────────────────────────▼─────────────────────────────┐
│                  Business & Model Layer                  │
│                                                          │
│  Contact · Commitment · Reminder · Interaction           │
│  Memory · AIExtractionResult · Meeting Data              │
│  Enums and domain-specific models                        │
└────────────────────────────┬─────────────────────────────┘
                             │
┌────────────────────────────▼─────────────────────────────┐
│                   Persistence Layer                      │
│                                                          │
│  DatabaseService (SQLite via sqflite)                    │
│  Tables: contacts, commitments, reminders,               │
│          interactions, memories                          │
└────────────────────────────┬─────────────────────────────┘
                             │
┌────────────────────────────▼─────────────────────────────┐
│                 External Integrations                    │
│                                                          │
│  Optional Cloud AI · Speech Processing · Local           │
│  Notifications · Platform Services                       │
│  Cloud services require user consent                     │
└──────────────────────────────────────────────────────────┘
```

## Data Schema & Relationships

1. **Contacts:** People and organizations stored as part of the user's personal memory.
   - Core fields: `id`, `name`, `phone`, `email`, `company`, `role`, `notes`, timestamps.

2. **Commitments:** Promises, obligations, tasks, and follow-ups associated with people.
   - Core fields: `id`, `title`, `description`, `contact_id`, `type`, `status`, `due_date`, `completed_at`, timestamps.

3. **Reminders:** Time-based notifications associated with commitments or contacts.
   - Core fields: `id`, `title`, `notes`, `commitment_id`, `contact_id`, `remind_at`, recurrence fields, `status`, timestamps.

4. **Interactions:** Records of meetings, conversations, and other interactions with contacts.
   - Stores interaction history and relevant context for future reference.

5. **Memories:** Important facts, preferences, and contextual information extracted from user inputs and interactions.
   - Can be associated with contacts where applicable.

## Key Design Principles

- **Local First:** Core data is stored in a local SQLite database. Cloud AI is optional and requires explicit user consent.
- **Centralized Saving:** CaptureSaveService provides a consistent save path for extracted contacts, promises, reminders, and memories.
- **Relational Integrity:** Relationships between contacts, commitments, reminders, interactions, and memories should be maintained safely when records are updated or deleted.
- **User Verification:** AI-extracted information is subject to user review where required. Unverified memories must not be treated as confirmed facts.
- **Immediate State Consistency:** Switching tabs should refresh relevant data so that changes are reflected across the application.
- **Undo Support:** Recent capture operations should support undo where implemented.
