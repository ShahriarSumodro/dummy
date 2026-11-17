import '../models/ai_extraction_result.dart';
import '../models/commitment.dart';
import '../models/contact.dart';
import '../models/interaction.dart';
import '../models/memory_item.dart';
import '../models/reminder.dart';
import 'database_service.dart';
import 'notification_service.dart';

/// What a capture saved, so it can be undone.
///
/// Tracks only records created by this capture.
/// Existing records reused during extraction are never deleted.
class SaveOutcome {
  final List<int> newContactIds;
  final List<Commitment> commitments;
  final List<Reminder> reminders;
  final List<int> memoryIds;
  final List<int> interactionIds;

  bool _undone = false;

  SaveOutcome({
    required List<int> newContactIds,
    required List<Commitment> commitments,
    required List<Reminder> reminders,
    required List<int> memoryIds,
    List<int> interactionIds = const [],
  }) : newContactIds = List.unmodifiable(newContactIds),
       commitments = List.unmodifiable(commitments),
       reminders = List.unmodifiable(reminders),
       memoryIds = List.unmodifiable(memoryIds),
       interactionIds = List.unmodifiable(interactionIds);

  /// Total number of saved business records.
  ///
  /// Timeline interactions are excluded from this count.
  int get itemCount =>
      newContactIds.length +
      commitments.length +
      reminders.length +
      memoryIds.length;

  bool get isUndone => _undone;

  /// Deletes only records created by this capture.
  ///
  /// Safe to call more than once.
  /// Notification cancellation is best-effort because the database
  /// deletion must not be repeated if notification cancellation fails.
  Future<void> undo() async {
    if (_undone) return;

    final database = await DatabaseService().database;

    await database.transaction((txn) async {
      // 1. Delete reminders first because they may reference commitments.
      for (final reminder in reminders) {
        final id = reminder.id;
        if (id == null) continue;

        await txn.delete('reminders', where: 'id = ?', whereArgs: [id]);
      }

      // 2. Delete only timeline interactions created by this capture.
      for (final interactionId in interactionIds) {
        await txn.delete(
          'interactions',
          where: 'id = ?',
          whereArgs: [interactionId],
        );
      }

      // 3. Delete commitments created by this capture.
      for (final commitment in commitments) {
        final id = commitment.id;
        if (id == null) continue;

        await txn.delete('commitments', where: 'id = ?', whereArgs: [id]);
      }

      // 4. Delete memories created by this capture.
      for (final memoryId in memoryIds) {
        await txn.delete('memories', where: 'id = ?', whereArgs: [memoryId]);
      }

      // 5. Delete only contacts created by this capture.
      for (final contactId in newContactIds) {
        await txn.delete('contacts', where: 'id = ?', whereArgs: [contactId]);
      }
    });

    // Database deletion succeeded. Mark as undone before attempting
    // notification cancellation, so a notification failure cannot
    // cause the database deletion to be repeated.
    _undone = true;

    final notificationService = NotificationService();

    // Cancel reminder notifications.
    for (final reminder in reminders) {
      final id = reminder.id;
      if (id == null) continue;

      try {
        await notificationService.cancelReminder(
          DatabaseService.reminderNotifOffset + id,
        );
      } catch (_) {
        // Database records are already deleted.
      }
    }

    // Cancel commitment notifications.
    for (final commitment in commitments) {
      final id = commitment.id;
      if (id == null) continue;

      try {
        await notificationService.cancelReminder(id);
      } catch (_) {
        // Database records are already deleted.
      }
    }
  }
}

/// Converts AI-extracted information into saved application records.
///
/// All database inserts happen inside one transaction.
/// Notifications are scheduled only after the transaction succeeds.
class CaptureSaveService {
  static final DatabaseService _db = DatabaseService();

  CaptureSaveService._();

  /// Saves selected contacts, commitments, reminders, and memories.
  ///
  /// [memoriesVerified] controls whether extracted memories are
  /// immediately marked as verified.
  static Future<SaveOutcome> save(
    AiExtractionResult result, {
    bool memoriesVerified = true,
  }) async {
    final database = await _db.database;

    final newContactIds = <int>[];
    final contactIdMap = <String, int>{};
    final validContactIds = <int>{};

    final commitments = <Commitment>[];
    final reminders = <Reminder>[];
    final memoryIds = <int>[];
    final interactionIds = <int>[];

    // ===============================================================
    // DATABASE TRANSACTION
    // ===============================================================

    await database.transaction((txn) async {
      // -------------------------------------------------------------
      // 1. Load existing contacts.
      // -------------------------------------------------------------

      final existingContacts = await txn.query(
        'contacts',
        columns: ['id', 'name'],
      );

      for (final row in existingContacts) {
        final id = row['id'] as int?;
        final name = row['name'] as String?;

        if (id == null || name == null || name.trim().isEmpty) {
          continue;
        }

        validContactIds.add(id);
        contactIdMap[_normalizeName(name)] = id;
      }

      // -------------------------------------------------------------
      // 2. Save selected contacts.
      // -------------------------------------------------------------

      for (final extractedContact in result.contacts) {
        if (!extractedContact.isSelected ||
            extractedContact.isPlaceholder ||
            extractedContact.name.trim().isEmpty) {
          continue;
        }

        final nameKey = _normalizeName(extractedContact.name);

        if (nameKey.isEmpty) continue;

        final matchedId = extractedContact.matchedExistingContactId;

        // Reuse an explicitly matched contact only if it exists.
        if (matchedId != null && validContactIds.contains(matchedId)) {
          contactIdMap[nameKey] = matchedId;
          continue;
        }

        // Reuse an existing contact with the same normalized name.
        if (contactIdMap.containsKey(nameKey)) {
          continue;
        }

        // Convert the extracted contact into a Contact model.
        // Construct a fresh model without carrying over a potentially
        // invalid matchedExistingContactId.
        final convertedContact = extractedContact.toContact();

        final contact = Contact(
          name: convertedContact.name,
          phone: convertedContact.phone,
          email: convertedContact.email,
          company: convertedContact.company,
          role: convertedContact.role,
          notes: convertedContact.notes,
          cadenceDays: convertedContact.cadenceDays,
          createdAt: convertedContact.createdAt,
          updatedAt: convertedContact.updatedAt,
        );

        final contactId = await txn.insert('contacts', contact.toMap());

        newContactIds.add(contactId);
        validContactIds.add(contactId);
        contactIdMap[nameKey] = contactId;
      }

      // -------------------------------------------------------------
      // 3. Save selected commitments and timeline interactions.
      // -------------------------------------------------------------

      for (final extractedCommitment in result.commitments) {
        if (!extractedCommitment.isSelected ||
            extractedCommitment.title.trim().isEmpty) {
          continue;
        }

        final contactId = _resolveContactId(
          matchedContactId: extractedCommitment.matchedContactId,
          contactName: extractedCommitment.contactName,
          contactIdMap: contactIdMap,
          validContactIds: validContactIds,
        );

        final commitment = Commitment(
          title: extractedCommitment.title.trim(),
          description: extractedCommitment.description,
          type: extractedCommitment.type,
          dueDate: extractedCommitment.dueDate,
          contactId: contactId,
          status: CommitmentStatus.pending,
        );

        final commitmentId = await txn.insert(
          'commitments',
          commitment.toMap(),
        );

        final savedCommitment = commitment.copyWith(id: commitmentId);

        commitments.add(savedCommitment);

        // Create a timeline interaction for this commitment.
        final interaction = Interaction(
          type: InteractionType.commitmentCreated,
          title: '[${commitment.type.label}] ${commitment.title}',
          contactId: contactId,
          commitmentId: commitmentId,
          notes: extractedCommitment.sourceExcerpt ?? commitment.description,
        );

        final interactionId = await txn.insert(
          'interactions',
          interaction.toMap(),
        );

        interactionIds.add(interactionId);
      }

      // -------------------------------------------------------------
      // 4. Save selected reminders.
      // -------------------------------------------------------------

      for (final extractedReminder in result.reminders) {
        if (!extractedReminder.isSelected ||
            extractedReminder.title.trim().isEmpty) {
          continue;
        }

        // ExtractedReminder currently has no reliable commitment ID
        // or contact ID. Therefore, do not attach it to an unrelated
        // commitment or contact.
        final reminder = Reminder(
          title: extractedReminder.title.trim(),
          remindAt: extractedReminder.remindAt,
          isRecurring: extractedReminder.isRecurring,
          recurringRule: extractedReminder.recurringRule,
          status: ReminderStatus.pending,
        );

        final reminderId = await txn.insert('reminders', reminder.toMap());

        reminders.add(reminder.copyWith(id: reminderId));
      }

      // -------------------------------------------------------------
      // 5. Save selected memories.
      // -------------------------------------------------------------

      for (final extractedMemory in result.memories) {
        if (!extractedMemory.isSelected ||
            extractedMemory.content.trim().isEmpty) {
          continue;
        }

        final contactId = _resolveContactId(
          matchedContactId: extractedMemory.matchedContactId,
          contactName: extractedMemory.contactName,
          contactIdMap: contactIdMap,
          validContactIds: validContactIds,
        );

        final memory = MemoryItem(
          category: MemoryCategory.fromString(extractedMemory.category),
          content: extractedMemory.content.trim(),
          contactId: contactId,
          source: 'extracted_note',
          confidence: extractedMemory.confidence,
          isVerified: memoriesVerified,
        );

        final memoryId = await txn.insert('memories', memory.toMap());

        memoryIds.add(memoryId);
      }
    });

    // ===============================================================
    // NOTIFICATIONS
    // These run only after the database transaction succeeds.
    // ===============================================================

    final notificationService = NotificationService();

    // Schedule commitment notifications.
    for (final commitment in commitments) {
      try {
        await notificationService.scheduleCommitmentNotification(commitment);
      } catch (_) {
        // Notification failure must not invalidate saved data.
      }
    }

    // Schedule reminder notifications.
    for (final reminder in reminders) {
      try {
        await _db.syncReminderNotification(reminder);
      } catch (_) {
        // Notification failure must not invalidate saved data.
      }
    }

    // ===============================================================
    // RETURN SAVE OUTCOME
    // ===============================================================

    return SaveOutcome(
      newContactIds: newContactIds,
      commitments: commitments,
      reminders: reminders,
      memoryIds: memoryIds,
      interactionIds: interactionIds,
    );
  }

  /// Resolves an extracted participant to a valid saved contact.
  ///
  /// First tries the explicitly matched contact ID.
  /// If that ID is invalid, falls back to normalized name matching.
  static int? _resolveContactId({
    required int? matchedContactId,
    required String? contactName,
    required Map<String, int> contactIdMap,
    required Set<int> validContactIds,
  }) {
    if (matchedContactId != null &&
        validContactIds.contains(matchedContactId)) {
      return matchedContactId;
    }

    if (contactName == null || contactName.trim().isEmpty) {
      return null;
    }

    return contactIdMap[_normalizeName(contactName)];
  }

  /// Normalizes names for consistent contact matching.
  static String _normalizeName(String name) {
    return name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
