# RemembrAI — System Architecture

## Architecture Overview
RemembrAI is built as an offline-first, modular mobile application using Flutter and SQLite.

```
┌────────────────────────────────────────────────────────┐
│                   Presentation Layer                   │
│   HomeScreen · PeopleScreen · Commitments · Reminders  │
│   (StatefulWidgets, Material 3, Adaptive Navigation)   │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│                    Business & Model                    │
│        Contact  ·  Commitment  ·  Reminder             │
│        Enums: CommitmentType, CommitmentStatus, etc.   │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│                   Persistence Layer                    │
│      DatabaseService (SQLite Singleton via sqflite)    │
│      Tables: contacts, commitments, reminders          │
│      Indexes on due_date, status, remind_at, relations │
└────────────────────────────────────────────────────────┘
```

## Data Schema & Relationships
1. **Contacts**: Primary entity for personal business memory.
   - `id`, `name`, `phone`, `email`, `company`, `role`, `notes`, `created_at`, `updated_at`.
2. **Commitments**: Obligations and promises.
   - `id`, `title`, `description`, `contact_id` (FK), `type` (promiseMade, promiseReceived, followUp, task), `status` (pending, completed, overdue, cancelled), `due_date`, `completed_at`, timestamps.
3. **Reminders**: Time-based notifications and alerts.
   - `id`, `title`, `notes`, `commitment_id` (FK), `contact_id` (FK), `remind_at`, `is_recurring`, `recurring_rule`, `status`, timestamps.

## Key Design Principles
- **Offline First**: All core data is stored locally in SQLite with zero cloud dependencies for Phase 1.
- **Relational Integrity**: Deleting a contact sets `contact_id = NULL` on linked commitments and reminders, preventing accidental data loss.
- **Immediate State Consistency**: Switching tabs triggers fresh queries, guaranteeing real-time metric accuracy across views.
