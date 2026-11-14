/// The type of commitment — who made the promise and what kind.
enum CommitmentType {
  /// Something the user promised to do for someone.
  promiseMade('Promise Made', 'I will...'),

  /// Something someone else promised to do for the user.
  promiseReceived('Promise Received', 'They will...'),

  /// A follow-up the user needs to do.
  followUp('Follow-up', 'I need to follow up...'),

  /// A general task.
  task('Task', 'I need to...');

  final String label;
  final String hint;
  const CommitmentType(this.label, this.hint);
}

/// The current status of a commitment.
enum CommitmentStatus {
  pending('Pending'),
  completed('Completed'),
  overdue('Overdue'),
  cancelled('Cancelled');

  final String label;
  const CommitmentStatus(this.label);
}

/// Data model for a Commitment (promise, request, follow-up, or task).
///
/// This is the core of the product — tracking what the user owes others
/// and what others owe the user.
class Commitment {
  final int? id;
  final String title;
  final String? description;
  final int? contactId;
  final CommitmentType type;
  final CommitmentStatus status;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Not stored in DB — populated by joins.
  final String? contactName;

  Commitment({
    this.id,
    required this.title,
    this.description,
    this.contactId,
    this.type = CommitmentType.task,
    this.status = CommitmentStatus.pending,
    this.dueDate,
    this.completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.contactName,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Commitment.fromMap(Map<String, dynamic> map) {
    return Commitment(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String?,
      contactId: map['contact_id'] as int?,
      type: CommitmentType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => CommitmentType.task,
      ),
      status: CommitmentStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => CommitmentStatus.pending,
      ),
      dueDate: map['due_date'] != null
          ? DateTime.parse(map['due_date'] as String)
          : null,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      contactName: map['contact_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'contact_id': contactId,
      'type': type.name,
      'status': status.name,
      'due_date': dueDate?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Commitment copyWith({
    int? id,
    String? title,
    String? description,
    int? contactId,
    CommitmentType? type,
    CommitmentStatus? status,
    DateTime? dueDate,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? contactName,
  }) {
    return Commitment(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      contactId: contactId ?? this.contactId,
      type: type ?? this.type,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      contactName: contactName ?? this.contactName,
    );
  }

  /// Whether this commitment is past its due date.
  bool get isOverdue {
    if (dueDate == null) {
      return false;
    }
    if (status == CommitmentStatus.completed ||
        status == CommitmentStatus.cancelled) {
      return false;
    }
    return DateTime.now().isAfter(dueDate!);
  }
}
