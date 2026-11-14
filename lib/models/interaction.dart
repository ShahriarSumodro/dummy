/// Type of interaction or audit event.
enum InteractionType {
  note('Note / Memory'),
  call('Phone Call'),
  meeting('Meeting'),
  commitmentCreated('Commitment Created'),
  commitmentCompleted('Commitment Completed'),
  draftSent('Message Sent'),
  reminderFired('Reminder Triggered');

  final String label;
  const InteractionType(this.label);
}

/// An interaction or audit log entry connecting an activity to a person or commitment.
class Interaction {
  final int? id;
  final InteractionType type;
  final String title;
  final String? notes;
  final int? contactId;
  final int? commitmentId;
  final int? meetingId;
  final DateTime timestamp;

  // Joined display fields
  final String? contactName;

  Interaction({
    this.id,
    required this.type,
    required this.title,
    this.notes,
    this.contactId,
    this.commitmentId,
    this.meetingId,
    DateTime? timestamp,
    this.contactName,
  }) : timestamp = timestamp ?? DateTime.now();

  factory Interaction.fromMap(Map<String, dynamic> map) {
    return Interaction(
      id: map['id'] as int?,
      type: InteractionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => InteractionType.note,
      ),
      title: map['title'] as String,
      notes: map['notes'] as String?,
      contactId: map['contact_id'] as int?,
      commitmentId: map['commitment_id'] as int?,
      meetingId: map['meeting_id'] as int?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      contactName: map['contact_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'type': type.name,
      'title': title,
      'notes': notes,
      'contact_id': contactId,
      'commitment_id': commitmentId,
      'meeting_id': meetingId,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
