/// Data model for a Contact (person the user interacts with).
///
/// Contacts are the foundation of the memory system — every commitment,
/// reminder, and conversation links back to a person.
class Contact {
  final int? id;
  final String name;
  final String? phone;
  final String? email;
  final String? company;
  final String? role;
  final String? notes;
  final int cadenceDays;
  final DateTime createdAt;
  final DateTime updatedAt;

  Contact({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.company,
    this.role,
    this.notes,
    this.cadenceDays = 30,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Create a Contact from a database row.
  factory Contact.fromMap(Map<String, dynamic> map) {
    return Contact(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      company: map['company'] as String?,
      role: map['role'] as String?,
      notes: map['notes'] as String?,
      cadenceDays: (map['cadence_days'] as int?) ?? 30,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Convert to a database row.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'company': company,
      'role': role,
      'notes': notes,
      'cadence_days': cadenceDays,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create a copy with updated fields.
  Contact copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? company,
    String? role,
    String? notes,
    int? cadenceDays,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      company: company ?? this.company,
      role: role ?? this.role,
      notes: notes ?? this.notes,
      cadenceDays: cadenceDays ?? this.cadenceDays,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Whether this contact has exceeded their cadence interval since last update.
  bool get isDueForTouchpoint {
    final days = DateTime.now().difference(updatedAt).inDays;
    return days >= cadenceDays;
  }

  /// Display-friendly subtitle (company + role, or phone, or email).
  String get subtitle {
    final parts = <String>[];
    if (role != null && role!.isNotEmpty) parts.add(role!);
    if (company != null && company!.isNotEmpty) parts.add(company!);
    if (parts.isNotEmpty) return parts.join(' · ');
    if (phone != null && phone!.isNotEmpty) return phone!;
    if (email != null && email!.isNotEmpty) return email!;
    return '';
  }

  /// First letter of name for avatar.
  String get initials {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
