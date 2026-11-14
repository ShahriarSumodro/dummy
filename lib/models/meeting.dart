import 'dart:convert';

/// Data model for a Meeting or Conversation session.
class Meeting {
  final int? id;
  final String title;
  final DateTime meetingDate;
  final String? location;
  final String? rawNotes;
  final String? summary;
  final List<String> decisions;
  final List<String> actionItems;
  final int? organizationId;
  final List<int> attendeeContactIds;
  final bool isProcessed;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined display fields
  final String? organizationName;
  final List<String> attendeeNames;

  Meeting({
    this.id,
    required this.title,
    required this.meetingDate,
    this.location,
    this.rawNotes,
    this.summary,
    this.decisions = const [],
    this.actionItems = const [],
    this.organizationId,
    this.attendeeContactIds = const [],
    this.isProcessed = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.organizationName,
    this.attendeeNames = const [],
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Meeting.fromMap(Map<String, dynamic> map) {
    List<String> parsedDecisions = [];
    if (map['decisions'] != null && map['decisions'].toString().isNotEmpty) {
      try {
        parsedDecisions = List<String>.from(jsonDecode(map['decisions'] as String));
      } catch (_) {
        parsedDecisions = (map['decisions'] as String)
            .split('\n')
            .where((s) => s.trim().isNotEmpty)
            .toList();
      }
    }

    List<String> parsedActionItems = [];
    if (map['action_items'] != null && map['action_items'].toString().isNotEmpty) {
      try {
        parsedActionItems =
            List<String>.from(jsonDecode(map['action_items'] as String));
      } catch (_) {
        parsedActionItems = (map['action_items'] as String)
            .split('\n')
            .where((s) => s.trim().isNotEmpty)
            .toList();
      }
    }

    List<int> parsedAttendeeIds = [];
    if (map['attendee_ids'] != null && map['attendee_ids'].toString().isNotEmpty) {
      try {
        parsedAttendeeIds =
            List<int>.from(jsonDecode(map['attendee_ids'] as String));
      } catch (_) {}
    }

    return Meeting(
      id: map['id'] as int?,
      title: map['title'] as String,
      meetingDate: DateTime.parse(map['meeting_date'] as String),
      location: map['location'] as String?,
      rawNotes: map['raw_notes'] as String?,
      summary: map['summary'] as String?,
      decisions: parsedDecisions,
      actionItems: parsedActionItems,
      organizationId: map['organization_id'] as int?,
      attendeeContactIds: parsedAttendeeIds,
      isProcessed: (map['is_processed'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      organizationName: map['organization_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'meeting_date': meetingDate.toIso8601String(),
      'location': location,
      'raw_notes': rawNotes,
      'summary': summary,
      'decisions': jsonEncode(decisions),
      'action_items': jsonEncode(actionItems),
      'organization_id': organizationId,
      'attendee_ids': jsonEncode(attendeeContactIds),
      'is_processed': isProcessed ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Meeting copyWith({
    int? id,
    String? title,
    DateTime? meetingDate,
    String? location,
    String? rawNotes,
    String? summary,
    List<String>? decisions,
    List<String>? actionItems,
    int? organizationId,
    List<int>? attendeeContactIds,
    bool? isProcessed,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? organizationName,
    List<String>? attendeeNames,
  }) {
    return Meeting(
      id: id ?? this.id,
      title: title ?? this.title,
      meetingDate: meetingDate ?? this.meetingDate,
      location: location ?? this.location,
      rawNotes: rawNotes ?? this.rawNotes,
      summary: summary ?? this.summary,
      decisions: decisions ?? this.decisions,
      actionItems: actionItems ?? this.actionItems,
      organizationId: organizationId ?? this.organizationId,
      attendeeContactIds: attendeeContactIds ?? this.attendeeContactIds,
      isProcessed: isProcessed ?? this.isProcessed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      organizationName: organizationName ?? this.organizationName,
      attendeeNames: attendeeNames ?? this.attendeeNames,
    );
  }
}
