import 'contact.dart';
import 'commitment.dart';

/// An individual contact parsed from natural language.
class ExtractedContact {
  String name;
  String? company;
  String? role;
  String? phone;
  String? email;
  String? notes;
  int? matchedExistingContactId;
  bool isSelected;

  // Multi-participant conversation disentanglement fields
  String? placeholderTag; // e.g. "Person A", "Speaker 1"
  bool isUnresolved; // true if name/identity was not explicitly confirmed
  String? detectedContext; // What they said or their role in the discussion
  String? relationship; // Relationship to user (e.g. "Client", "Colleague")

  ExtractedContact({
    required this.name,
    this.company,
    this.role,
    this.phone,
    this.email,
    this.notes,
    this.matchedExistingContactId,
    this.isSelected = true,
    this.placeholderTag,
    this.isUnresolved = false,
    this.detectedContext,
    this.relationship,
  });

  bool get isPlaceholder {
    if (isUnresolved) return true;
    final lower = name.trim().toLowerCase();
    return lower.startsWith('person ') ||
        lower.startsWith('speaker ') ||
        lower.startsWith('participant ') ||
        lower == 'someone' ||
        lower == 'unknown';
  }

  factory ExtractedContact.fromJson(Map<String, dynamic> json) {
    final rawName = json['name'] as String? ?? 'Unknown';
    final isPlaceholderName = rawName.toLowerCase().startsWith('person ') ||
        rawName.toLowerCase().startsWith('speaker ') ||
        rawName.toLowerCase().startsWith('participant ') ||
        rawName.toLowerCase() == 'unknown';

    return ExtractedContact(
      name: rawName,
      company: json['company'] as String?,
      role: json['role'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      notes: json['notes'] as String?,
      placeholderTag: json['placeholder_tag'] as String? ?? (isPlaceholderName ? rawName : null),
      isUnresolved: json['is_unresolved'] as bool? ?? isPlaceholderName,
      detectedContext: json['detected_context'] as String? ?? json['notes'] as String?,
      relationship: json['relationship'] as String?,
    );
  }

  Contact toContact() {
    final combinedNotes = [
      if (notes != null && notes!.isNotEmpty) notes,
      if (relationship != null && relationship!.isNotEmpty) 'Relationship: $relationship',
      if (detectedContext != null && detectedContext!.isNotEmpty) 'Context: $detectedContext',
    ].join(' • ');

    return Contact(
      id: matchedExistingContactId,
      name: name,
      company: company,
      role: role,
      phone: phone,
      email: email,
      notes: combinedNotes.isNotEmpty ? combinedNotes : null,
    );
  }
}

/// An individual commitment parsed from natural language.
class ExtractedCommitment {
  String title;
  String? description;
  CommitmentType type;
  DateTime? dueDate;
  String? contactName;
  int? matchedContactId;
  double confidence;
  String? sourceExcerpt;
  bool isSelected;

  ExtractedCommitment({
    required this.title,
    this.description,
    this.type = CommitmentType.task,
    this.dueDate,
    this.contactName,
    this.matchedContactId,
    this.confidence = 0.9,
    this.sourceExcerpt,
    this.isSelected = true,
  });

  String get confidenceLabel {
    final pct = (confidence * 100).toInt();
    if (confidence >= 0.85) return 'High ($pct%)';
    if (confidence >= 0.65) return 'Medium ($pct%)';
    return 'Verify ($pct%)';
  }

  /// Renames an attributed contact from a placeholder (e.g. "Person A") to a real name ("Raju")
  void renameContact(String oldName, String newName, {int? newContactId}) {
    if (contactName != null &&
        contactName!.trim().toLowerCase() == oldName.trim().toLowerCase()) {
      contactName = newName;
      if (newContactId != null) matchedContactId = newContactId;
    }
    // Also rephrase mentions inside the title and description
    title = title.replaceAll(RegExp(RegExp.escape(oldName), caseSensitive: false), newName);
    if (description != null) {
      description = description!.replaceAll(RegExp(RegExp.escape(oldName), caseSensitive: false), newName);
    }
  }

  factory ExtractedCommitment.fromJson(
    Map<String, dynamic> json, {
    DateTime? referenceTime,
  }) {
    final typeStr = (json['type'] as String? ?? 'task').toLowerCase();
    final type = switch (typeStr) {
      'promisemade' || 'promise_made' => CommitmentType.promiseMade,
      'promisereceived' || 'promise_received' => CommitmentType.promiseReceived,
      'followup' || 'follow_up' => CommitmentType.followUp,
      _ => CommitmentType.task,
    };

    DateTime? parsedDate;
    if (json['due_date'] != null) {
      parsedDate = DateTime.tryParse(json['due_date'] as String);
    }

    return ExtractedCommitment(
      title: json['title'] as String? ?? 'Untitled Commitment',
      description: json['description'] as String?,
      type: type,
      dueDate: parsedDate,
      contactName: json['contact_name'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.85,
      sourceExcerpt: json['source_excerpt'] as String?,
    );
  }
}

/// An individual reminder parsed from natural language.
class ExtractedReminder {
  String title;
  DateTime remindAt;
  bool isRecurring;
  String? recurringRule;
  double confidence;
  String? sourceExcerpt;
  bool isSelected;

  ExtractedReminder({
    required this.title,
    required this.remindAt,
    this.isRecurring = false,
    this.recurringRule,
    this.confidence = 0.9,
    this.sourceExcerpt,
    this.isSelected = true,
  });

  String get confidenceLabel {
    final pct = (confidence * 100).toInt();
    if (confidence >= 0.85) return 'High ($pct%)';
    if (confidence >= 0.65) return 'Medium ($pct%)';
    return 'Verify ($pct%)';
  }

  factory ExtractedReminder.fromJson(Map<String, dynamic> json) {
    DateTime parsedTime = DateTime.now().add(const Duration(hours: 1));
    if (json['remind_at'] != null) {
      final parsed = DateTime.tryParse(json['remind_at'] as String);
      if (parsed != null) parsedTime = parsed;
    }

    return ExtractedReminder(
      title: json['title'] as String? ?? 'Reminder',
      remindAt: parsedTime,
      isRecurring: json['is_recurring'] as bool? ?? false,
      recurringRule: json['recurring_rule'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.85,
      sourceExcerpt: json['source_excerpt'] as String?,
    );
  }
}

/// A personal or business memory fact parsed from conversation (Module 2).
class ExtractedMemory {
  String content;
  String category;
  String? contactName;
  int? matchedContactId;
  double confidence;
  String? sourceExcerpt;
  bool isSelected;

  ExtractedMemory({
    required this.content,
    this.category = 'fact',
    this.contactName,
    this.matchedContactId,
    this.confidence = 0.9,
    this.sourceExcerpt,
    this.isSelected = true,
  });

  factory ExtractedMemory.fromJson(Map<String, dynamic> json) {
    return ExtractedMemory(
      content: json['content'] as String? ?? json['text'] as String? ?? '',
      category: json['category'] as String? ?? 'fact',
      contactName: json['contact_name'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.9,
      sourceExcerpt: json['source_excerpt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'category': category,
      if (contactName != null) 'contact_name': contactName,
      'confidence': confidence,
      if (sourceExcerpt != null) 'source_excerpt': sourceExcerpt,
    };
  }
}

/// Complete extraction payload returned by an AI provider.
class AiExtractionResult {
  final String rawInput;
  final String summary;
  final List<ExtractedContact> contacts;
  final List<ExtractedCommitment> commitments;
  final List<ExtractedReminder> reminders;
  final List<ExtractedMemory> memories;

  AiExtractionResult({
    required this.rawInput,
    required this.summary,
    required this.contacts,
    required this.commitments,
    required this.reminders,
    List<ExtractedMemory>? memories,
  }) : memories = memories ?? [];

  bool get isEmpty =>
      contacts.isEmpty && commitments.isEmpty && reminders.isEmpty && memories.isEmpty;

  bool get hasUnresolvedParticipants => contacts.any((c) => c.isPlaceholder);

  List<ExtractedContact> get unresolvedParticipants =>
      contacts.where((c) => c.isPlaceholder).toList();

  /// Renames an unresolved participant across all extracted contacts, commitments, and reminders
  void renameParticipant(String oldPlaceholder, String newName, {String? role, String? company, String? relationship}) {
    for (final c in contacts) {
      if (c.name.trim().toLowerCase() == oldPlaceholder.trim().toLowerCase() ||
          c.placeholderTag?.trim().toLowerCase() == oldPlaceholder.trim().toLowerCase()) {
        c.name = newName;
        c.isUnresolved = false;
        if (role != null && role.isNotEmpty) c.role = role;
        if (company != null && company.isNotEmpty) c.company = company;
        if (relationship != null && relationship.isNotEmpty) c.relationship = relationship;
      }
    }

    for (final cm in commitments) {
      cm.renameContact(oldPlaceholder, newName);
    }

    for (final rm in reminders) {
      rm.title = rm.title.replaceAll(RegExp(RegExp.escape(oldPlaceholder), caseSensitive: false), newName);
    }

    for (final mem in memories) {
      if (mem.contactName != null &&
          mem.contactName!.trim().toLowerCase() == oldPlaceholder.trim().toLowerCase()) {
        mem.contactName = newName;
      }
    }
  }
}
