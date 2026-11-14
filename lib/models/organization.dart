/// Data model for an Organization / Company.
class Organization {
  final int? id;
  final String name;
  final String? industry;
  final String? website;
  final String? address;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Populated by joins
  final int contactCount;
  final int activeCommitmentCount;

  Organization({
    this.id,
    required this.name,
    this.industry,
    this.website,
    this.address,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.contactCount = 0,
    this.activeCommitmentCount = 0,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Organization.fromMap(Map<String, dynamic> map) {
    return Organization(
      id: map['id'] as int?,
      name: map['name'] as String,
      industry: map['industry'] as String?,
      website: map['website'] as String?,
      address: map['address'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      contactCount: (map['contact_count'] as num?)?.toInt() ?? 0,
      activeCommitmentCount:
          (map['active_commitment_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'industry': industry,
      'website': website,
      'address': address,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Organization copyWith({
    int? id,
    String? name,
    String? industry,
    String? website,
    String? address,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? contactCount,
    int? activeCommitmentCount,
  }) {
    return Organization(
      id: id ?? this.id,
      name: name ?? this.name,
      industry: industry ?? this.industry,
      website: website ?? this.website,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      contactCount: contactCount ?? this.contactCount,
      activeCommitmentCount:
          activeCommitmentCount ?? this.activeCommitmentCount,
    );
  }

  String get initials {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'O';
  }
}
