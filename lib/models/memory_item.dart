/// Categories for personal and business memories (Module 2).
enum MemoryCategory {
  fact('Important Fact', 'Facts about work, life, or context'),
  preference('Personal Preference', 'Likes, dislikes, or personal habits'),
  project('Work & Project', 'Project context, status, or milestones'),
  experience('Life Experience', 'Key life events, stories, or achievements'),
  goal('Goal & Routine', 'Personal or professional goals and routines'),
  decision('Agreed Decision', 'Decisions reached during discussions'),
  workingHabit('Working Habit', 'Schedules, working hours, and methods'),
  relationship('Relationship Context', 'Context about family, friends, or network');

  final String label;
  final String description;
  const MemoryCategory(this.label, this.description);

  static MemoryCategory fromString(String? val) {
    if (val == null) return MemoryCategory.fact;
    for (final c in MemoryCategory.values) {
      if (c.name.toLowerCase() == val.toLowerCase() ||
          c.label.toLowerCase() == val.toLowerCase()) {
        return c;
      }
    }
    return MemoryCategory.fact;
  }
}

/// A persistent, structured memory record in the Personal Memory Engine.
class MemoryItem {
  final int? id;
  final MemoryCategory category;
  final String content;
  final int? contactId;
  final String? contactName; // Populated by joins
  final String source; // e.g. "user_stated", "extracted_meeting", "captured_note"
  final double confidence; // 0.0 - 1.0
  final bool isVerified; // Confirmed by user vs pending review
  final DateTime createdAt;
  final DateTime updatedAt;

  MemoryItem({
    this.id,
    this.category = MemoryCategory.fact,
    required this.content,
    this.contactId,
    this.contactName,
    this.source = 'user_stated',
    this.confidence = 1.0,
    this.isVerified = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  MemoryItem copyWith({
    int? id,
    MemoryCategory? category,
    String? content,
    int? contactId,
    String? contactName,
    String? source,
    double? confidence,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MemoryItem(
      id: id ?? this.id,
      category: category ?? this.category,
      content: content ?? this.content,
      contactId: contactId ?? this.contactId,
      contactName: contactName ?? this.contactName,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'category': category.name,
      'content': content,
      'contact_id': contactId,
      'source': source,
      'confidence': confidence,
      'is_verified': isVerified ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory MemoryItem.fromMap(Map<String, dynamic> map) {
    return MemoryItem(
      id: map['id'] as int?,
      category: MemoryCategory.fromString(map['category'] as String?),
      content: map['content'] as String? ?? '',
      contactId: map['contact_id'] as int?,
      contactName: map['contact_name'] as String?,
      source: map['source'] as String? ?? 'user_stated',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
      isVerified: (map['is_verified'] as int? ?? 1) == 1,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
