/// The current status of a reminder.
enum ReminderStatus {
  pending('Pending'),
  snoozed('Snoozed'),
  completed('Done'),
  cancelled('Cancelled');

  final String label;
  const ReminderStatus(this.label);
}

/// Data model for a Reminder.
///
/// Reminders can be standalone or linked to a commitment and/or contact.
class Reminder {
  final int? id;
  final String title;
  final String? notes;
  final int? commitmentId;
  final int? contactId;
  final DateTime remindAt;
  final bool isRecurring;
  final String? recurringRule; // 'daily', 'weekly', 'monthly'
  final ReminderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Not stored in DB — populated by joins.
  final String? contactName;
  final String? commitmentTitle;

  Reminder({
    this.id,
    required this.title,
    this.notes,
    this.commitmentId,
    this.contactId,
    required this.remindAt,
    this.isRecurring = false,
    this.recurringRule,
    this.status = ReminderStatus.pending,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.contactName,
    this.commitmentTitle,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'] as int?,
      title: map['title'] as String,
      notes: map['notes'] as String?,
      commitmentId: map['commitment_id'] as int?,
      contactId: map['contact_id'] as int?,
      remindAt: DateTime.parse(map['remind_at'] as String),
      isRecurring: (map['is_recurring'] as int?) == 1,
      recurringRule: map['recurring_rule'] as String?,
      status: ReminderStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ReminderStatus.pending,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      contactName: map['contact_name'] as String?,
      commitmentTitle: map['commitment_title'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'notes': notes,
      'commitment_id': commitmentId,
      'contact_id': contactId,
      'remind_at': remindAt.toIso8601String(),
      'is_recurring': isRecurring ? 1 : 0,
      'recurring_rule': recurringRule,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Reminder copyWith({
    int? id,
    String? title,
    String? notes,
    int? commitmentId,
    int? contactId,
    DateTime? remindAt,
    bool? isRecurring,
    String? recurringRule,
    ReminderStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? contactName,
    String? commitmentTitle,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      commitmentId: commitmentId ?? this.commitmentId,
      contactId: contactId ?? this.contactId,
      remindAt: remindAt ?? this.remindAt,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringRule: recurringRule ?? this.recurringRule,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      contactName: contactName ?? this.contactName,
      commitmentTitle: commitmentTitle ?? this.commitmentTitle,
    );
  }

  /// Whether this reminder is past its remind time.
  bool get isPastDue {
    if (status == ReminderStatus.completed ||
        status == ReminderStatus.cancelled) {
      return false;
    }
    return DateTime.now().isAfter(remindAt);
  }
}
