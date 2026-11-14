# RemembrAI Workflow Contract

> **Contract Rule**: All data models, database tables, CRUD flows, state transitions, confirmation gates, permission layers, and notification services defined in this document MUST be preserved exactly throughout the UI redesign. No functionality may be deleted or broken.

---

## 1. Core Workflow Pipeline
```
[Voice/Text Conversation]
        │
        ▼
[AI Extraction (Groq / Gemini / Local Rules)]
        │
        ▼
[Confirmation Gate: AI Review Screen (ai_review_screen.dart)]
  ├─ Unconfirmed status explicitly marked with confidence score
  ├─ Multi-Participant Resolution (Person A, Person B, etc.)
  └─ User MUST tap "Confirm & Save" (or edit/delete individual items)
        │
        ▼
[Saved to Local SQLite (database_service.dart)]
  ├─ Commitments (status: pending)
  ├─ Contacts (linked or created)
  ├─ Reminders (scheduled via flutter_local_notifications)
        │
        ▼
[Executive Briefing & Preparation (voice_service.dart / briefing_screen.dart)]
        │
        ▼
[Approved Action: Action Drafts (action_draft_detail_screen.dart)]
  ├─ User inspects drafted Email / WhatsApp / SMS
  ├─ User explicitly taps "Open Channel" (external app launch)
  └─ Marked sent ONLY after user approval
        │
        ▼
[Completion / Snooze / Reschedule]
```

---

## 2. Screen & Workflow Inventory

### 1. App Shell & Navigation (`lib/screens/shell_screen.dart`)
- **Type**: Persistent bottom navigation shell.
- **Current Destinations**:
  1. Home (`HomeScreen`)
  2. People (`PeopleScreen`)
  3. Commitments (`CommitmentsScreen`)
  4. Reminders (`RemindersScreen`)
- **User Actions**: Switch tabs, preserve state across tab switches.

### 2. Home / Assistant Dashboard (`lib/screens/home_screen.dart`)
- **Features & Metrics**:
  - Overdue promises count (`_db.countOverdueCommitments()`)
  - Deliverables due today count (`_db.countTodayCommitments()`)
  - Upcoming reminders count (`_db.countUpcomingReminders()`)
  - Tracked business contacts count (`_db.countContacts()`)
  - Urgent commitments list (top 5 overdue or due today)
  - Today's reminders list
- **Quick Action Triggers**:
  - Spoken Audio Briefing (Play/Pause TTS via `VoiceService`)
  - AI Memory Capture Modal (`AiCaptureSheet`)
  - Live Voice Capture (`VoiceCaptureScreen`)
  - Ask Assistant Chat (`AssistantChatScreen`)
  - Log Meeting (`MeetingsScreen` / `MeetingFormScreen`)
  - View Drafts (`ActionDraftsScreen`)
  - Relationship Health (`RelationshipHealthScreen`)
  - Global Search (`GlobalSearchScreen`)
  - Settings (`SettingsScreen`)

### 3. Commitments (`lib/screens/commitments_screen.dart` & `commitment_detail_screen.dart` & `commitment_form_screen.dart`)
- **Data Model**: `Commitment` (id, title, description, contactId, type, status, dueDate, completedAt, createdAt, updatedAt).
- **Types**: `promiseMade`, `promiseReceived`, `followUp`, `task`.
- **Statuses**: `pending`, `completed`.
- **Features & Actions**:
  - Filter tabs: All, Promises Made, Promises Received, Follow-ups, Tasks.
  - Status toggle: Pending vs. Completed.
  - Conflict warning banner when another commitment overlaps $\pm 2$ hours.
  - One-tap status toggle: Complete / Reopen.
  - Reschedule / Snooze due date.
  - Generate Follow-up Draft (`ActionDraftService`).
  - Delete with confirmation.
  - Create commitment form with contact picker & schedule conflict check.

### 4. People & Organizations (`lib/screens/people_screen.dart`, `contact_detail_screen.dart`, `organizations_screen.dart`)
- **Data Models**: `Contact`, `Organization`.
- **Features & Actions**:
  - Search contacts by name, company, role.
  - Touchpoint Cadence status: Active, Due Soon, Overdue for follow-up based on `cadenceDays`.
  - Direct communication actions: Call phone, launch WhatsApp, launch Email client.
  - Contact Profile: Linked commitments, reminders, interaction audit history.
  - Organization List & Profile: Employee roster, linked active commitments.
  - Create / Edit Contact & Organization forms.
  - Duplicate detection & Contact Merge flow (`_db.mergeContacts()`).

### 5. Reminders & Push Notifications (`lib/screens/reminders_screen.dart`, `reminder_form_screen.dart`, `notification_service.dart`)
- **Data Model**: `Reminder` (id, title, notes, commitmentId, contactId, remindAt, isRecurring, status).
- **Features & Actions**:
  - Filter: Upcoming vs. Completed.
  - Quick Snooze (1 hour, tomorrow morning, custom date/time).
  - Native Android push notification scheduling (`flutter_local_notifications`).
  - Auto-cancel notification when commitment/reminder is completed.
  - Form to create/edit custom reminder.

### 6. AI Capture & Confirmation Gate (`lib/screens/ai_capture_sheet.dart`, `ai_review_screen.dart`, `multi_participant_resolution_screen.dart`)
- **CRITICAL WORKFLOW**:
  - Unconfirmed items are displayed with confidence scores and source excerpts.
  - Multi-Party Resolution: Detects tags ("Person A", "Person B", "Person D") and prompts user to assign real names/roles.
  - User can edit any extracted title, date, or contact before committing to DB.
  - Single explicit "Confirm & Save to Memory" action commits data and schedules notifications.

### 7. Voice Recording (`lib/screens/voice_capture_screen.dart`)
- **Features & Actions**:
  - Live speech-to-text with locale selection (English, বাংলা `bn_BD`, Banglish).
  - Live transcription text area with manual edit capability.
  - Auto-stop watchdog (synchronizes microphone button when speech engine stops).
  - 1-tap "Extract Memory with AI" button transitioning to `AiReviewScreen`.

### 8. Executive Assistant Chat (`lib/screens/assistant_chat_screen.dart`)
- **Features & Actions**:
  - Natural language Q&A grounded in verified SQLite business memory (`AiQueryService`).
  - Source citations / references linking back to memory items.
  - Suggested next action chips.
  - Multi-turn conversation context.
  - Text-to-speech button to listen to answers.

### 9. Action Drafts & External Channels (`lib/screens/action_drafts_screen.dart`, `action_draft_detail_screen.dart`)
- **Data Model**: `ActionDraft` (type, title, recipientName, recipientContact, subject, body, status).
- **Channels**: Email (`mailto:` with RFC 6068 percent-encoding), WhatsApp (`wa.me`), SMS (`sms:`).
- **Gate**: Draft status starts as `draft`. User must inspect and approve before launching external app. Marked `sent` upon launch. Copy-to-clipboard fallback.

### 10. Meetings & Intelligence (`lib/screens/meetings_screen.dart`, `meeting_detail_screen.dart`, `meeting_form_screen.dart`)
- **Data Model**: `Meeting` (title, meetingDate, location, rawNotes, summary, decisions, actionItems, organizationId, attendeeIds).
- **Features & Actions**:
  - AI extraction of Key Decisions and Action Items from meeting notes.
  - Schedule conflict detection ($\pm 2$ hours).
  - Link meetings to Organizations and Contacts.

### 11. Settings & Data Privacy (`lib/screens/settings_screen.dart`, `data_privacy_screen.dart`)
- **Features & Actions**:
  - Active AI Provider selector: Google Gemini vs. Groq Cloud vs. Offline Mock.
  - API Key entry with live connection test (`AiServiceFactory.testConnection`).
  - Persona & Language: Executive / Conversational / Analytical; English / Bangla / Banglish.
  - Voice settings: Speech rate slider, Auto-speak toggle.
  - Push notification toggle.
  - Data Privacy: Full JSON database export, JSON backup restore, complete wipe.
