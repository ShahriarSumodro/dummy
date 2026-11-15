import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/contact.dart';
import '../models/commitment.dart';
import '../models/reminder.dart';
import '../models/organization.dart';
import '../models/meeting.dart';
import '../models/action_draft.dart';
import '../models/interaction.dart';
import '../models/assistant_settings.dart';
import '../models/memory_item.dart';
import 'notification_service.dart';

/// Central database service. Singleton — one instance for the whole app.
///
/// Handles all CRUD operations for contacts, commitments, reminders,
/// organizations, meetings, and action drafts.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;
  static Completer<Database>? _openCompleter;

  static void setDatabaseForTesting(Database? db) {
    _database = db;
    _openCompleter = null;
  }

  Future<void> initInMemoryForTesting() async {
    _database = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: _onCreate,
      onOpen: _ensureTables,
    );
    _openCompleter = null;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (_openCompleter != null) return _openCompleter!.future;

    _openCompleter = Completer<Database>();
    try {
      _database = await _initDatabase();
      _openCompleter!.complete(_database);
      return _database!;
    } catch (e, st) {
      _openCompleter!.completeError(e, st);
      _openCompleter = null;
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = join(documentsDir.path, 'remembrai.db');

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
      onOpen: (db) async {
        await _ensureTables(db);
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _ensureTables(db);
  }

  Future<void> _ensureTables(Database db) async {
    // 1. Settings
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // 2. Organizations
    await db.execute('''
      CREATE TABLE IF NOT EXISTS organizations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        industry TEXT,
        website TEXT,
        address TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 3. Contacts
    await db.execute('''
      CREATE TABLE IF NOT EXISTS contacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        company TEXT,
        role TEXT,
        notes TEXT,
        cadence_days INTEGER DEFAULT 30,
        organization_id INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE SET NULL
      )
    ''');

    // 4. Commitments
    await db.execute('''
      CREATE TABLE IF NOT EXISTS commitments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        contact_id INTEGER,
        type TEXT NOT NULL DEFAULT 'task',
        status TEXT NOT NULL DEFAULT 'pending',
        due_date TEXT,
        completed_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (contact_id) REFERENCES contacts (id) ON DELETE SET NULL
      )
    ''');

    // 5. Reminders
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        notes TEXT,
        commitment_id INTEGER,
        contact_id INTEGER,
        remind_at TEXT NOT NULL,
        is_recurring INTEGER NOT NULL DEFAULT 0,
        recurring_rule TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (commitment_id) REFERENCES commitments (id) ON DELETE SET NULL,
        FOREIGN KEY (contact_id) REFERENCES contacts (id) ON DELETE SET NULL
      )
    ''');

    // 6. Meetings
    await db.execute('''
      CREATE TABLE IF NOT EXISTS meetings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        meeting_date TEXT NOT NULL,
        location TEXT,
        raw_notes TEXT,
        summary TEXT,
        decisions TEXT,
        action_items TEXT,
        organization_id INTEGER,
        attendee_ids TEXT,
        is_processed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE SET NULL
      )
    ''');

    // 7. Action Drafts
    await db.execute('''
      CREATE TABLE IF NOT EXISTS action_drafts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        recipient_name TEXT,
        recipient_contact TEXT,
        subject TEXT,
        body TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'draft',
        commitment_id INTEGER,
        contact_id INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (commitment_id) REFERENCES commitments (id) ON DELETE SET NULL,
        FOREIGN KEY (contact_id) REFERENCES contacts (id) ON DELETE SET NULL
      )
    ''');

    // 8. Interactions / Activity Audit Trail
    await db.execute('''
      CREATE TABLE IF NOT EXISTS interactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        notes TEXT,
        contact_id INTEGER,
        commitment_id INTEGER,
        meeting_id INTEGER,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (contact_id) REFERENCES contacts (id) ON DELETE SET NULL,
        FOREIGN KEY (commitment_id) REFERENCES commitments (id) ON DELETE SET NULL,
        FOREIGN KEY (meeting_id) REFERENCES meetings (id) ON DELETE SET NULL
      )
    ''');

    // 9. Persistent Companion Chat Messages
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL,
        is_user INTEGER NOT NULL,
        source_references TEXT,
        suggested_next_actions TEXT,
        timestamp TEXT NOT NULL
      )
    ''');

    // 10. Persistent Personal & Business Memories (Module 2)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS memories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL DEFAULT 'fact',
        content TEXT NOT NULL,
        contact_id INTEGER,
        source TEXT NOT NULL DEFAULT 'user_stated',
        confidence REAL NOT NULL DEFAULT 1.0,
        is_verified INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (contact_id) REFERENCES contacts (id) ON DELETE SET NULL
      )
    ''');

    // Indexes
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_commitments_status ON commitments (status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_commitments_due_date ON commitments (due_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_commitments_contact ON commitments (contact_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reminders_status ON reminders (status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reminders_remind_at ON reminders (remind_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_meetings_date ON meetings (meeting_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_interactions_contact ON interactions (contact_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_interactions_timestamp ON interactions (timestamp)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_chat_messages_timestamp ON chat_messages (timestamp)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_memories_category ON memories (category)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_memories_contact ON memories (contact_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_memories_created_at ON memories (created_at)',
    );

    // Migrations for existing installs
    final migrations = [
      'ALTER TABLE contacts ADD COLUMN cadence_days INTEGER DEFAULT 30',
      'ALTER TABLE contacts ADD COLUMN organization_id INTEGER',
      'ALTER TABLE commitments ADD COLUMN completed_at TEXT',
      'ALTER TABLE commitments ADD COLUMN type TEXT DEFAULT "task"',
      'ALTER TABLE meetings ADD COLUMN organization_id INTEGER',
      'ALTER TABLE meetings ADD COLUMN attendee_ids TEXT',
      'ALTER TABLE meetings ADD COLUMN is_processed INTEGER DEFAULT 0',
      'ALTER TABLE action_drafts ADD COLUMN commitment_id INTEGER',
      'ALTER TABLE action_drafts ADD COLUMN contact_id INTEGER',
    ];
    for (final sql in migrations) {
      try {
        await db.execute(sql);
      } catch (_) {
        // Column already exists or error ignored
      }
    }
  }

  // ─────────────────────────────────────────────
  //  CONTACTS
  // ─────────────────────────────────────────────

  Future<int> insertContact(Contact contact) async {
    final db = await database;
    return await db.insert('contacts', contact.toMap());
  }

  Future<List<Contact>> getAllContacts({String? searchQuery}) async {
    final db = await database;

    List<Map<String, dynamic>> results;
    if (searchQuery != null && searchQuery.isNotEmpty) {
      results = await db.query(
        'contacts',
        where: 'name LIKE ? OR company LIKE ? OR phone LIKE ? OR email LIKE ?',
        whereArgs: List.filled(4, '%$searchQuery%'),
        orderBy: 'name ASC',
      );
    } else {
      results = await db.query('contacts', orderBy: 'name ASC');
    }

    return results.map((map) => Contact.fromMap(map)).toList();
  }

  Future<Contact?> getContact(int id) async {
    final db = await database;
    final results = await db.query(
      'contacts',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return Contact.fromMap(results.first);
  }

  Future<int> updateContact(Contact contact) async {
    final db = await database;
    return await db.update(
      'contacts',
      contact.toMap(),
      where: 'id = ?',
      whereArgs: [contact.id],
    );
  }

  Future<int> deleteContact(int id) async {
    final db = await database;
    return await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────────────────────────────
  //  COMMITMENTS
  // ─────────────────────────────────────────────

  Future<int> insertCommitment(Commitment commitment) async {
    final db = await database;
    final id = await db.insert('commitments', commitment.toMap());
    await insertInteraction(Interaction(
      type: InteractionType.commitmentCreated,
      title: '[${commitment.type.label}] ${commitment.title}',
      contactId: commitment.contactId,
      commitmentId: id,
      notes: commitment.description,
    ));
    try {
      final scheduled = commitment.copyWith(id: id);
      await NotificationService().scheduleCommitmentNotification(scheduled);
    } catch (_) {}
    return id;
  }

  Future<List<Commitment>> getAllCommitments({
    String? statusFilter,
    String? typeFilter,
  }) async {
    final db = await database;

    String query = '''
      SELECT c.*, ct.name as contact_name
      FROM commitments c
      LEFT JOIN contacts ct ON c.contact_id = ct.id
    ''';

    final where = <String>[];
    final args = <dynamic>[];

    if (statusFilter != null) {
      where.add('c.status = ?');
      args.add(statusFilter);
    }
    if (typeFilter != null) {
      where.add('c.type = ?');
      args.add(typeFilter);
    }

    if (where.isNotEmpty) {
      query += ' WHERE ${where.join(' AND ')}';
    }

    query += ' ORDER BY c.due_date ASC, c.created_at DESC';

    final results = await db.rawQuery(query, args);
    return results.map((map) => Commitment.fromMap(map)).toList();
  }

  Future<List<Commitment>> getCommitmentsForContact(int contactId) async {
    final db = await database;
    final results = await db.rawQuery(
      '''
      SELECT c.*, ct.name as contact_name
      FROM commitments c
      LEFT JOIN contacts ct ON c.contact_id = ct.id
      WHERE c.contact_id = ?
      ORDER BY c.created_at DESC
    ''',
      [contactId],
    );
    return results.map((map) => Commitment.fromMap(map)).toList();
  }

  Future<int> updateCommitment(Commitment commitment) async {
    final db = await database;
    final res = await db.update(
      'commitments',
      commitment.toMap(),
      where: 'id = ?',
      whereArgs: [commitment.id],
    );
    if (commitment.status == CommitmentStatus.completed) {
      await insertInteraction(Interaction(
        type: InteractionType.commitmentCompleted,
        title: 'Completed: ${commitment.title}',
        commitmentId: commitment.id,
        contactId: commitment.contactId,
        notes: 'Marked completed on ${DateTime.now().toIso8601String().split('T').first}',
      ));
    }
    try {
      await NotificationService().scheduleCommitmentNotification(commitment);
    } catch (_) {}
    return res;
  }

  Future<int> deleteCommitment(int id) async {
    final db = await database;
    try {
      await NotificationService().cancelReminder(id);
    } catch (_) {}
    return await db.delete('commitments', where: 'id = ?', whereArgs: [id]);
  }

  /// Checks for overlapping commitments or meetings within a time window (default: ±2 hours).
  Future<List<Map<String, dynamic>>> checkScheduleConflicts(
    DateTime targetDate, {
    int? excludeCommitmentId,
    int? excludeMeetingId,
    Duration window = const Duration(hours: 2),
  }) async {
    final startWindow = targetDate.subtract(window).toIso8601String();
    final endWindow = targetDate.add(window).toIso8601String();
    final db = await database;

    final conflicts = <Map<String, dynamic>>[];

    // 1. Check commitments
    final commitmentRows = await db.rawQuery('''
      SELECT id, title, due_date, type FROM commitments
      WHERE status = 'pending' AND due_date IS NOT NULL
      AND due_date >= ? AND due_date <= ?
      ${excludeCommitmentId != null ? 'AND id != $excludeCommitmentId' : ''}
    ''', [startWindow, endWindow]);

    for (final row in commitmentRows) {
      conflicts.add({
        'kind': 'commitment',
        'id': row['id'],
        'title': row['title'],
        'date': DateTime.parse(row['due_date'] as String),
        'label': 'Promise / Task: "${row['title']}"',
      });
    }

    // 2. Check meetings
    final meetingRows = await db.rawQuery('''
      SELECT id, title, meeting_date, location FROM meetings
      WHERE meeting_date >= ? AND meeting_date <= ?
      ${excludeMeetingId != null ? 'AND id != $excludeMeetingId' : ''}
    ''', [startWindow, endWindow]);

    for (final row in meetingRows) {
      conflicts.add({
        'kind': 'meeting',
        'id': row['id'],
        'title': row['title'],
        'date': DateTime.parse(row['meeting_date'] as String),
        'label': 'Meeting: "${row['title']}"',
      });
    }

    return conflicts;
  }

  // ─────────────────────────────────────────────
  //  REMINDERS
  // ─────────────────────────────────────────────

  Future<int> insertReminder(Reminder reminder) async {
    final db = await database;
    return await db.insert('reminders', reminder.toMap());
  }

  Future<List<Reminder>> getAllReminders({String? statusFilter}) async {
    final db = await database;

    String query = '''
      SELECT r.*, ct.name as contact_name, cm.title as commitment_title
      FROM reminders r
      LEFT JOIN contacts ct ON r.contact_id = ct.id
      LEFT JOIN commitments cm ON r.commitment_id = cm.id
    ''';

    final args = <dynamic>[];
    if (statusFilter != null) {
      query += ' WHERE r.status = ?';
      args.add(statusFilter);
    }

    query += ' ORDER BY r.remind_at ASC';

    final results = await db.rawQuery(query, args);
    return results.map((map) => Reminder.fromMap(map)).toList();
  }

  Future<int> updateReminder(Reminder reminder) async {
    final db = await database;
    return await db.update(
      'reminders',
      reminder.toMap(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
  }

  Future<int> deleteReminder(int id) async {
    final db = await database;
    return await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────────────────────────────
  //  ORGANIZATIONS
  // ─────────────────────────────────────────────

  Future<int> insertOrganization(Organization org) async {
    final db = await database;
    return await db.insert('organizations', org.toMap());
  }

  Future<List<Organization>> getAllOrganizations({String? searchQuery}) async {
    final db = await database;
    try {
      String query = '''
        SELECT o.*,
          (SELECT COUNT(*) FROM contacts ct WHERE ct.company = o.name OR ct.organization_id = o.id) as contact_count,
          (SELECT COUNT(*) FROM commitments cm
           JOIN contacts ct ON cm.contact_id = ct.id
           WHERE (ct.company = o.name OR ct.organization_id = o.id) AND cm.status = 'pending') as active_commitment_count
        FROM organizations o
      ''';

      final args = <dynamic>[];
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query += ' WHERE o.name LIKE ? OR o.industry LIKE ?';
        args.addAll(['%$searchQuery%', '%$searchQuery%']);
      }

      query += ' ORDER BY o.name ASC';

      final results = await db.rawQuery(query, args);
      return results.map((m) => Organization.fromMap(m)).toList();
    } catch (_) {
      // Robust fallback if joined query fails
      final fallbackResults = await db.query(
        'organizations',
        where: (searchQuery != null && searchQuery.isNotEmpty)
            ? 'name LIKE ? OR industry LIKE ?'
            : null,
        whereArgs: (searchQuery != null && searchQuery.isNotEmpty)
            ? ['%$searchQuery%', '%$searchQuery%']
            : null,
        orderBy: 'name ASC',
      );
      return fallbackResults.map((m) => Organization.fromMap(m)).toList();
    }
  }

  Future<Organization?> getOrganization(int id) async {
    final db = await database;
    try {
      final results = await db.rawQuery(
        '''
        SELECT o.*,
          (SELECT COUNT(*) FROM contacts ct WHERE ct.company = o.name OR ct.organization_id = o.id) as contact_count,
          (SELECT COUNT(*) FROM commitments cm
           JOIN contacts ct ON cm.contact_id = ct.id
           WHERE (ct.company = o.name OR ct.organization_id = o.id) AND cm.status = 'pending') as active_commitment_count
        FROM organizations o
        WHERE o.id = ?
      ''',
        [id],
      );
      if (results.isEmpty) return null;
      return Organization.fromMap(results.first);
    } catch (_) {
      final fallback = await db.query('organizations', where: 'id = ?', whereArgs: [id]);
      if (fallback.isEmpty) return null;
      return Organization.fromMap(fallback.first);
    }
  }

  Future<int> updateOrganization(Organization org) async {
    final db = await database;
    return await db.update(
      'organizations',
      org.toMap(),
      where: 'id = ?',
      whereArgs: [org.id],
    );
  }

  Future<int> deleteOrganization(int id) async {
    final db = await database;
    return await db.delete('organizations', where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────────────────────────────
  //  MEETINGS
  // ─────────────────────────────────────────────

  Future<int> insertMeeting(Meeting meeting) async {
    final db = await database;
    final id = await db.insert('meetings', meeting.toMap());
    await insertInteraction(Interaction(
      type: InteractionType.meeting,
      title: 'Meeting: ${meeting.title}',
      meetingId: id,
      notes: meeting.summary ?? (meeting.rawNotes != null && meeting.rawNotes!.isNotEmpty ? meeting.rawNotes : null),
    ));
    return id;
  }

  Future<List<Meeting>> getAllMeetings({String? searchQuery}) async {
    final db = await database;
    String query = '''
      SELECT m.*, o.name as organization_name
      FROM meetings m
      LEFT JOIN organizations o ON m.organization_id = o.id
    ''';

    final args = <dynamic>[];
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query +=
          ' WHERE m.title LIKE ? OR m.location LIKE ? OR m.raw_notes LIKE ?';
      args.addAll(['%$searchQuery%', '%$searchQuery%', '%$searchQuery%']);
    }

    query += ' ORDER BY m.meeting_date DESC';

    final results = await db.rawQuery(query, args);
    return results.map((m) => Meeting.fromMap(m)).toList();
  }

  Future<Meeting?> getMeeting(int id) async {
    final db = await database;
    final results = await db.rawQuery(
      '''
      SELECT m.*, o.name as organization_name
      FROM meetings m
      LEFT JOIN organizations o ON m.organization_id = o.id
      WHERE m.id = ?
    ''',
      [id],
    );
    if (results.isEmpty) return null;
    return Meeting.fromMap(results.first);
  }

  Future<int> updateMeeting(Meeting meeting) async {
    final db = await database;
    return await db.update(
      'meetings',
      meeting.toMap(),
      where: 'id = ?',
      whereArgs: [meeting.id],
    );
  }

  Future<int> deleteMeeting(int id) async {
    final db = await database;
    return await db.delete('meetings', where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────────────────────────────
  //  ACTION DRAFTS
  // ─────────────────────────────────────────────

  Future<int> insertActionDraft(ActionDraft draft) async {
    final db = await database;
    return await db.insert('action_drafts', draft.toMap());
  }

  Future<List<ActionDraft>> getAllActionDrafts({String? statusFilter}) async {
    final db = await database;
    List<Map<String, dynamic>> results;
    if (statusFilter != null) {
      results = await db.query(
        'action_drafts',
        where: 'status = ?',
        whereArgs: [statusFilter],
        orderBy: 'created_at DESC',
      );
    } else {
      results = await db.query('action_drafts', orderBy: 'created_at DESC');
    }
    return results.map((m) => ActionDraft.fromMap(m)).toList();
  }

  Future<int> updateActionDraft(ActionDraft draft) async {
    final db = await database;
    final res = await db.update(
      'action_drafts',
      draft.toMap(),
      where: 'id = ?',
      whereArgs: [draft.id],
    );
    if (draft.status == DraftStatus.sent) {
      await insertInteraction(Interaction(
        type: InteractionType.draftSent,
        title: 'Sent: ${draft.subject}',
        contactId: draft.contactId,
        commitmentId: draft.commitmentId,
        notes: draft.body,
      ));
    }
    return res;
  }

  Future<int> deleteActionDraft(int id) async {
    final db = await database;
    return await db.delete('action_drafts', where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────────────────────────────
  //  GLOBAL SEARCH & MEMORY RETRIEVAL (RAG CONTEXT)
  // ─────────────────────────────────────────────

  /// Global search across contacts, organizations, commitments, and meetings.
  Future<Map<String, dynamic>> searchAll(String query) async {
    final q = '%$query%';
    final db = await database;

    final contacts = await db.query(
      'contacts',
      where: 'name LIKE ? OR company LIKE ? OR role LIKE ? OR notes LIKE ?',
      whereArgs: [q, q, q, q],
      limit: 10,
    );

    final commitments = await db.rawQuery(
      '''
      SELECT c.*, ct.name as contact_name
      FROM commitments c
      LEFT JOIN contacts ct ON c.contact_id = ct.id
      WHERE c.title LIKE ? OR c.description LIKE ?
      LIMIT 10
    ''',
      [q, q],
    );

    final meetings = await db.query(
      'meetings',
      where: 'title LIKE ? OR raw_notes LIKE ? OR summary LIKE ?',
      whereArgs: [q, q, q],
      limit: 10,
    );

    final organizations = await db.query(
      'organizations',
      where: 'name LIKE ? OR industry LIKE ? OR notes LIKE ?',
      whereArgs: [q, q, q],
      limit: 10,
    );

    return {
      'contacts': contacts.map((c) => Contact.fromMap(c)).toList(),
      'commitments': commitments.map((c) => Commitment.fromMap(c)).toList(),
      'meetings': meetings.map((m) => Meeting.fromMap(m)).toList(),
      'organizations': organizations
          .map((o) => Organization.fromMap(o))
          .toList(),
    };
  }

  /// Builds a structured text memory snapshot for AI RAG questions.
  Future<String> buildRagContextSummary({String? topic}) async {
    final contacts = await getAllContacts();
    final commitments = await getAllCommitments();
    final meetings = await getAllMeetings();
    final reminders = await getAllReminders(statusFilter: 'pending');
    final memories = await getAllMemories(limit: 50);

    final buffer = StringBuffer();
    buffer.writeln('=== CURRENT PERSONAL BUSINESS MEMORY CONTEXT ===');

    if (memories.isNotEmpty) {
      buffer.writeln('\n-- STORED KNOWLEDGE & PREFERENCES (${memories.length}) --');
      for (final mem in memories) {
        final personStr = mem.contactName != null ? ' (re: ${mem.contactName})' : '';
        buffer.writeln('- [${mem.category.label}]$personStr: ${mem.content}');
      }
    }

    buffer.writeln('\n-- CONTACTS & PEOPLE (${contacts.length}) --');
    for (final c in contacts) {
      buffer.writeln(
        '- ${c.name} (Company: ${c.company ?? 'N/A'}, Role: ${c.role ?? 'N/A'}, Phone: ${c.phone ?? 'N/A'}, Email: ${c.email ?? 'N/A'}, Notes: ${c.notes ?? 'None'})',
      );
    }

    buffer.writeln('\n-- COMMITMENTS & PROMISES (${commitments.length}) --');
    for (final c in commitments) {
      buffer.writeln(
        '- [${c.type.label}] "${c.title}" | Status: ${c.status.label} | Person: ${c.contactName ?? 'None'} | Due: ${c.dueDate?.toIso8601String() ?? 'No due date'}',
      );
    }

    buffer.writeln('\n-- RECENT MEETINGS (${meetings.length}) --');
    for (final m in meetings.take(10)) {
      buffer.writeln(
        '- "${m.title}" on ${m.meetingDate.toIso8601String()} | Summary: ${m.summary ?? m.rawNotes ?? 'None'}',
      );
    }

    buffer.writeln('\n-- PENDING REMINDERS (${reminders.length}) --');
    for (final r in reminders) {
      buffer.writeln(
        '- "${r.title}" at ${r.remindAt.toIso8601String()} (Linked: ${r.contactName ?? r.commitmentTitle ?? 'General'})',
      );
    }

    return buffer.toString();
  }

  // ─────────────────────────────────────────────
  //  RELATIONSHIP HEALTH / STALE CONTACT RADAR
  // ─────────────────────────────────────────────

  /// Identifies contacts who haven't had recent commitments or meetings.
  Future<List<Map<String, dynamic>>> getRelationshipHealthCheck() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT ct.id, ct.name, ct.company, ct.role,
        COALESCE(ct.cadence_days, 30) as cadence_days,
        MAX(cm.created_at) as last_commitment_date,
        COUNT(CASE WHEN cm.status = 'pending' THEN 1 END) as pending_commitments,
        COUNT(CASE WHEN cm.status = 'overdue' OR (cm.status = 'pending' AND cm.due_date < datetime('now')) THEN 1 END) as overdue_commitments
      FROM contacts ct
      LEFT JOIN commitments cm ON ct.id = cm.contact_id
      GROUP BY ct.id
      ORDER BY overdue_commitments DESC, last_commitment_date ASC
    ''');
    return results;
  }

  // ─────────────────────────────────────────────
  //  SAY-DO DEPENDABILITY ANALYTICS
  // ─────────────────────────────────────────────

  /// Computes the executive "Say-Do" dependability ratio, commitment completion
  /// turnaround times, and promise breakdown (promises made vs received).
  Future<Map<String, dynamic>> getSayDoAnalytics() async {
    final db = await database;
    final allCommitments = await db.query('commitments');

    int totalTracked = allCommitments.length;
    int completedCount = 0;
    int completedOnTimeCount = 0;
    int overdueCount = 0;
    int pendingCount = 0;
    int cancelledCount = 0;

    int promisesMadeTotal = 0;
    int promisesMadeCompleted = 0;
    int promisesMadeOverdue = 0;

    int promisesReceivedTotal = 0;
    int promisesReceivedCompleted = 0;
    int promisesReceivedOverdue = 0;

    double totalTurnaroundDays = 0;
    int turnaroundCount = 0;

    final now = DateTime.now();

    for (final row in allCommitments) {
      final statusStr = row['status'] as String? ?? 'pending';
      final typeStr = row['type'] as String? ?? 'task';
      final dueDateStr = row['due_date'] as String?;
      final completedAtStr = row['completed_at'] as String?;
      final createdAtStr = row['created_at'] as String;

      final createdAt = DateTime.tryParse(createdAtStr) ?? now;
      final dueDate = dueDateStr != null ? DateTime.tryParse(dueDateStr) : null;
      final completedAt =
          completedAtStr != null ? DateTime.tryParse(completedAtStr) : null;

      final isOverdue = statusStr == 'overdue' ||
          (statusStr == 'pending' && dueDate != null && dueDate.isBefore(now));

      final isPromiseReceived = typeStr == 'promiseReceived';
      if (isPromiseReceived) {
        promisesReceivedTotal++;
      } else {
        promisesMadeTotal++;
      }

      if (statusStr == 'completed') {
        completedCount++;
        if (isPromiseReceived) {
          promisesReceivedCompleted++;
        } else {
          promisesMadeCompleted++;
        }

        // On-time check: completed on or before due date (or no due date was set)
        if (dueDate == null ||
            (completedAt != null && !completedAt.isAfter(dueDate))) {
          completedOnTimeCount++;
        }

        if (completedAt != null) {
          final diff = completedAt.difference(createdAt).inHours / 24.0;
          if (diff >= 0) {
            totalTurnaroundDays += diff;
            turnaroundCount++;
          }
        }
      } else if (isOverdue) {
        overdueCount++;
        if (isPromiseReceived) {
          promisesReceivedOverdue++;
        } else {
          promisesMadeOverdue++;
        }
      } else if (statusStr == 'cancelled') {
        cancelledCount++;
      } else {
        pendingCount++;
      }
    }

    // Say-Do Ratio: ratio of completed on time out of all evaluated (completed + overdue)
    final totalEvaluated = completedCount + overdueCount;
    final sayDoRatio = totalEvaluated > 0
        ? (completedOnTimeCount / totalEvaluated) * 100.0
        : 100.0;

    // Promises Made Say-Do Ratio
    final evaluatedPromisesMade =
        promisesMadeCompleted + promisesMadeOverdue;
    final promisesMadeSayDo = evaluatedPromisesMade > 0
        ? (promisesMadeCompleted / evaluatedPromisesMade) * 100.0
        : 100.0;

    final avgTurnaroundDays = turnaroundCount > 0
        ? (totalTurnaroundDays / turnaroundCount)
        : 0.0;

    return {
      'sayDoRatio': sayDoRatio.clamp(0.0, 100.0),
      'promisesMadeSayDo': promisesMadeSayDo.clamp(0.0, 100.0),
      'totalTracked': totalTracked,
      'completedCount': completedCount,
      'completedOnTimeCount': completedOnTimeCount,
      'overdueCount': overdueCount,
      'pendingCount': pendingCount,
      'cancelledCount': cancelledCount,
      'promisesMadeTotal': promisesMadeTotal,
      'promisesMadeCompleted': promisesMadeCompleted,
      'promisesMadeOverdue': promisesMadeOverdue,
      'promisesReceivedTotal': promisesReceivedTotal,
      'promisesReceivedCompleted': promisesReceivedCompleted,
      'promisesReceivedOverdue': promisesReceivedOverdue,
      'avgTurnaroundDays': avgTurnaroundDays,
    };
  }

  // ─────────────────────────────────────────────
  //  PERSISTENT CHAT MESSAGES
  // ─────────────────────────────────────────────

  Future<int> insertChatMessage({
    required String text,
    required bool isUser,
    List<String> sourceReferences = const [],
    List<String> suggestedNextActions = const [],
    DateTime? timestamp,
  }) async {
    final db = await database;
    return await db.insert('chat_messages', {
      'text': text,
      'is_user': isUser ? 1 : 0,
      'source_references': jsonEncode(sourceReferences),
      'suggested_next_actions': jsonEncode(suggestedNextActions),
      'timestamp': (timestamp ?? DateTime.now()).toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getChatMessages({int limit = 100}) async {
    final db = await database;
    final results = await db.query(
      'chat_messages',
      orderBy: 'id ASC',
      limit: limit,
    );
    return results.map((row) {
      List<String> refs = [];
      if (row['source_references'] != null) {
        try {
          refs = List<String>.from(jsonDecode(row['source_references'] as String));
        } catch (_) {}
      }
      List<String> actions = [];
      if (row['suggested_next_actions'] != null) {
        try {
          actions = List<String>.from(jsonDecode(row['suggested_next_actions'] as String));
        } catch (_) {}
      }
      return {
        'id': row['id'] as int,
        'text': row['text'] as String,
        'is_user': (row['is_user'] as int) == 1,
        'source_references': refs,
        'suggested_next_actions': actions,
        'timestamp': row['timestamp'] as String,
      };
    }).toList();
  }

  Future<void> clearChatMessages() async {
    final db = await database;
    await db.delete('chat_messages');
  }

  // ─────────────────────────────────────────────
  //  PERSONAL & BUSINESS MEMORIES (MODULE 2)
  // ─────────────────────────────────────────────

  Future<int> insertMemory(MemoryItem memory) async {
    final db = await database;
    return await db.insert('memories', memory.toMap());
  }

  Future<int> updateMemory(MemoryItem memory) async {
    final db = await database;
    return await db.update(
      'memories',
      memory.toMap(),
      where: 'id = ?',
      whereArgs: [memory.id],
    );
  }

  Future<int> deleteMemory(int id) async {
    final db = await database;
    return await db.delete('memories', where: 'id = ?', whereArgs: [id]);
  }

  Future<MemoryItem?> getMemory(int id) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT m.*, c.name as contact_name
      FROM memories m
      LEFT JOIN contacts c ON m.contact_id = c.id
      WHERE m.id = ?
    ''', [id]);
    if (results.isEmpty) return null;
    return MemoryItem.fromMap(results.first);
  }

  Future<List<MemoryItem>> getAllMemories({
    String? category,
    int? contactId,
    String? searchQuery,
    int limit = 100,
  }) async {
    final db = await database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (category != null && category.isNotEmpty && category != 'all') {
      whereClauses.add('m.category = ?');
      whereArgs.add(category);
    }

    if (contactId != null) {
      whereClauses.add('m.contact_id = ?');
      whereArgs.add(contactId);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('(m.content LIKE ? OR c.name LIKE ?)');
      whereArgs.add('%${searchQuery.trim()}%');
      whereArgs.add('%${searchQuery.trim()}%');
    }

    final whereSql = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final results = await db.rawQuery('''
      SELECT m.*, c.name as contact_name
      FROM memories m
      LEFT JOIN contacts c ON m.contact_id = c.id
      $whereSql
      ORDER BY m.created_at DESC
      LIMIT ?
    ''', [...whereArgs, limit]);

    return results.map((row) => MemoryItem.fromMap(row)).toList();
  }

  Future<int> countMemories() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM memories');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ─────────────────────────────────────────────
  //  FULL DATA EXPORT & BACKUP
  // ─────────────────────────────────────────────

  Future<Map<String, dynamic>> exportDatabaseJson() async {
    final contacts = await getAllContacts();
    final commitments = await getAllCommitments();
    final reminders = await getAllReminders();
    final organizations = await getAllOrganizations();
    final meetings = await getAllMeetings();
    final drafts = await getAllActionDrafts();
    final memories = await getAllMemories();

    return {
      'exported_at': DateTime.now().toIso8601String(),
      'version': '1.0',
      'contacts': contacts.map((c) => c.toMap()).toList(),
      'commitments': commitments.map((c) => c.toMap()).toList(),
      'reminders': reminders.map((r) => r.toMap()).toList(),
      'organizations': organizations.map((o) => o.toMap()).toList(),
      'meetings': meetings.map((m) => m.toMap()).toList(),
      'action_drafts': drafts.map((d) => d.toMap()).toList(),
      'memories': memories.map((m) => m.toMap()).toList(),
    };
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('memories');
    await db.delete('chat_messages');
    await db.delete('action_drafts');
    await db.delete('reminders');
    await db.delete('commitments');
    await db.delete('meetings');
    await db.delete('contacts');
    await db.delete('organizations');
  }

  // ─────────────────────────────────────────────
  //  DASHBOARD METRICS
  // ─────────────────────────────────────────────

  Future<int> countOverdueCommitments() async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count FROM commitments
      WHERE status = 'pending' AND due_date IS NOT NULL
      AND due_date < ?
    ''',
      [DateTime.now().toIso8601String()],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countTodayCommitments() async {
    final db = await database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count FROM commitments
      WHERE status = 'pending' AND due_date IS NOT NULL
      AND due_date >= ? AND due_date < ?
    ''',
      [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countUpcomingReminders() async {
    final db = await database;
    final now = DateTime.now();
    final weekFromNow = now.add(const Duration(days: 7));
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count FROM reminders
      WHERE status = 'pending'
      AND remind_at >= ? AND remind_at < ?
    ''',
      [now.toIso8601String(), weekFromNow.toIso8601String()],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countContacts() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM contacts');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countMeetings() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM meetings');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countOrganizations() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM organizations',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ─────────────────────────────────────────────
  //  SETTINGS (KEY-VALUE)
  // ─────────────────────────────────────────────

  Future<String?> getSetting(String key) async {
    final db = await database;
    final res = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (res.isEmpty) return null;
    return res.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ─────────────────────────────────────────────
  //  INTERACTIONS / ACTIVITY TIMELINE
  // ─────────────────────────────────────────────

  Future<int> insertInteraction(Interaction interaction) async {
    final db = await database;
    return await db.insert('interactions', interaction.toMap());
  }

  Future<List<Interaction>> getInteractions({
    int? contactId,
    int limit = 50,
  }) async {
    final db = await database;
    String query = '''
      SELECT i.*, ct.name as contact_name
      FROM interactions i
      LEFT JOIN contacts ct ON i.contact_id = ct.id
    ''';
    final args = <dynamic>[];
    if (contactId != null) {
      query += ' WHERE i.contact_id = ?';
      args.add(contactId);
    }
    query += ' ORDER BY i.timestamp DESC LIMIT ?';
    args.add(limit);

    final results = await db.rawQuery(query, args);
    return results.map((m) => Interaction.fromMap(m)).toList();
  }

  // ─────────────────────────────────────────────
  //  DATA RESTORE FROM JSON BACKUP
  // ─────────────────────────────────────────────

  Future<int> restoreDatabaseJson(Map<String, dynamic> json) async {
    final db = await database;
    int importedRecords = 0;

    await db.transaction((txn) async {
      // 1. Organizations
      if (json['organizations'] is List) {
        for (final item in json['organizations'] as List) {
          await txn.insert(
            'organizations',
            item as Map<String, dynamic>,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          importedRecords++;
        }
      }

      // 2. Contacts
      if (json['contacts'] is List) {
        for (final item in json['contacts'] as List) {
          await txn.insert(
            'contacts',
            item as Map<String, dynamic>,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          importedRecords++;
        }
      }

      // 3. Commitments
      if (json['commitments'] is List) {
        for (final item in json['commitments'] as List) {
          await txn.insert(
            'commitments',
            item as Map<String, dynamic>,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          importedRecords++;
        }
      }

      // 4. Reminders
      if (json['reminders'] is List) {
        for (final item in json['reminders'] as List) {
          await txn.insert(
            'reminders',
            item as Map<String, dynamic>,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          importedRecords++;
        }
      }

      // 5. Meetings
      if (json['meetings'] is List) {
        for (final item in json['meetings'] as List) {
          await txn.insert(
            'meetings',
            item as Map<String, dynamic>,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          importedRecords++;
        }
      }

      // 6. Action Drafts
      if (json['action_drafts'] is List) {
        for (final item in json['action_drafts'] as List) {
          await txn.insert(
            'action_drafts',
            item as Map<String, dynamic>,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          importedRecords++;
        }
      }

      // 7. Personal & Business Memories
      if (json['memories'] is List) {
        for (final item in json['memories'] as List) {
          await txn.insert(
            'memories',
            item as Map<String, dynamic>,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          importedRecords++;
        }
      }
    });

    return importedRecords;
  }

  // ─────────────────────────────────────────────
  //  ASSISTANT PERSONALIZATION PREFERENCES
  // ─────────────────────────────────────────────

  Future<AssistantSettings> getAssistantSettings() async {
    final toneStr = await getSetting('assistant_tone');
    final langStr = await getSetting('assistant_language');
    final proactivityStr = await getSetting('assistant_proactivity');
    final title = await getSetting('user_title') ?? '';
    final autoSpeakStr = await getSetting('assistant_auto_speak');
    final notifyStr = await getSetting('assistant_notifications_enabled');
    final rateStr = await getSetting('assistant_speech_rate');

    return AssistantSettings(
      tone: AssistantTone.values.firstWhere(
        (e) => e.name == toneStr,
        orElse: () => AssistantTone.executive,
      ),
      language: AssistantLanguage.values.firstWhere(
        (e) => e.name == langStr,
        orElse: () => AssistantLanguage.english,
      ),
      proactivity: ProactivityLevel.values.firstWhere(
        (e) => e.name == proactivityStr,
        orElse: () => ProactivityLevel.balanced,
      ),
      userTitle: title,
      autoSpeakResponses: autoSpeakStr == 'true',
      notificationsEnabled: notifyStr != 'false',
      speechRate: double.tryParse(rateStr ?? '') ?? 0.5,
    );
  }

  Future<void> saveAssistantSettings(AssistantSettings settings) async {
    await setSetting('assistant_tone', settings.tone.name);
    await setSetting('assistant_language', settings.language.name);
    await setSetting('assistant_proactivity', settings.proactivity.name);
    await setSetting('user_title', settings.userTitle);
    await setSetting('assistant_auto_speak', settings.autoSpeakResponses ? 'true' : 'false');
    await setSetting('assistant_notifications_enabled', settings.notificationsEnabled ? 'true' : 'false');
    await setSetting('assistant_speech_rate', settings.speechRate.toString());
  }

  // ─────────────────────────────────────────────
  //  CONTACT DEDUPLICATION & MERGE ENGINE
  // ─────────────────────────────────────────────

  /// Identifies duplicate contacts by name, email, or cleaned phone number.
  Future<List<Map<String, dynamic>>> findDuplicateContacts() async {
    final contacts = await getAllContacts();
    final duplicates = <Map<String, dynamic>>[];

    for (int i = 0; i < contacts.length; i++) {
      for (int j = i + 1; j < contacts.length; j++) {
        final c1 = contacts[i];
        final c2 = contacts[j];
        bool isDuplicate = false;
        String reason = '';

        if (c1.name.trim().toLowerCase() == c2.name.trim().toLowerCase()) {
          isDuplicate = true;
          reason = 'Identical name: "${c1.name}"';
        } else if (c1.email != null &&
            c2.email != null &&
            c1.email!.trim().toLowerCase() == c2.email!.trim().toLowerCase()) {
          isDuplicate = true;
          reason = 'Same email: ${c1.email}';
        } else if (c1.phone != null &&
            c2.phone != null &&
            c1.phone!.replaceAll(RegExp(r'\D'), '') ==
                c2.phone!.replaceAll(RegExp(r'\D'), '') &&
            c1.phone!.replaceAll(RegExp(r'\D'), '').isNotEmpty) {
          isDuplicate = true;
          reason = 'Same phone: ${c1.phone}';
        }

        if (isDuplicate) {
          duplicates.add({
            'primary': c1,
            'duplicate': c2,
            'reason': reason,
          });
        }
      }
    }
    return duplicates;
  }

  /// Merges duplicate contact into primary contact:
  /// Reassigns commitments, reminders, interactions, and action drafts to primary contact,
  /// copies over any missing fields (phone, email, notes, company, role),
  /// and deletes the duplicate contact.
  Future<void> mergeContacts(int primaryId, int duplicateId) async {
    final db = await database;
    await db.transaction((txn) async {
      final primaryRows = await txn.query('contacts', where: 'id = ?', whereArgs: [primaryId]);
      final dupRows = await txn.query('contacts', where: 'id = ?', whereArgs: [duplicateId]);
      if (primaryRows.isEmpty || dupRows.isEmpty) return;

      final primary = Contact.fromMap(primaryRows.first);
      final dup = Contact.fromMap(dupRows.first);

      // Merge missing notes
      final mergedNotes = [
        if (primary.notes != null && primary.notes!.isNotEmpty) primary.notes,
        if (dup.notes != null && dup.notes!.isNotEmpty) 'Merged Notes: ${dup.notes}',
      ].join('\n\n');

      final updatedPrimary = primary.copyWith(
        phone: (primary.phone == null || primary.phone!.isEmpty) ? dup.phone : primary.phone,
        email: (primary.email == null || primary.email!.isEmpty) ? dup.email : primary.email,
        company: (primary.company == null || primary.company!.isEmpty) ? dup.company : primary.company,
        role: (primary.role == null || primary.role!.isEmpty) ? dup.role : primary.role,
        notes: mergedNotes.isNotEmpty ? mergedNotes : null,
      );

      await txn.update('contacts', updatedPrimary.toMap(), where: 'id = ?', whereArgs: [primaryId]);

      // Reassign linked records
      await txn.rawUpdate('UPDATE commitments SET contact_id = ? WHERE contact_id = ?', [primaryId, duplicateId]);
      await txn.rawUpdate('UPDATE reminders SET contact_id = ? WHERE contact_id = ?', [primaryId, duplicateId]);
      await txn.rawUpdate('UPDATE interactions SET contact_id = ? WHERE contact_id = ?', [primaryId, duplicateId]);
      await txn.rawUpdate('UPDATE action_drafts SET contact_id = ? WHERE contact_id = ?', [primaryId, duplicateId]);

      // Delete duplicate contact
      await txn.delete('contacts', where: 'id = ?', whereArgs: [duplicateId]);
    });
  }
}
