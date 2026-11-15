/// Represents a structured personality profile for Dummy. (Module 10 & Section 6).
///
/// Modulates conversational tone, humor, formality, brevity, and proactivity
/// WITHOUT altering stored personal memory, permissions, or core business logic.
class PersonalityProfile {
  final String id;
  final String name;
  final String tagline;
  final String description;

  /// Formality level: 1.0 (very casual / slang) to 5.0 (strictly formal executive).
  final double formality;

  /// Humor level: 1.0 (purely literal / factual) to 5.0 (playful banter / witty).
  final double humor;

  /// Warmth level: 1.0 (cool / transactional) to 5.0 (supportive / empathetic).
  final double warmth;

  /// Brevity level: 1.0 (explanatory / detailed) to 5.0 (ultra-crisp bullet points).
  final double brevity;

  /// Proactivity level: 1.0 (reactive / on-demand) to 5.0 (highly proactive nudges).
  final double proactivity;

  const PersonalityProfile({
    required this.id,
    required this.name,
    required this.tagline,
    required this.description,
    this.formality = 3.0,
    this.humor = 3.0,
    this.warmth = 4.0,
    this.brevity = 3.0,
    this.proactivity = 3.0,
  });

  /// Pre-configured Archetypes (Master Spec Module 10)
  static const companion = PersonalityProfile(
    id: 'companion',
    name: 'Dummy. Companion',
    tagline: 'Warm, thoughtful, dependable follow-through',
    description:
        'The default companion voice. Balances natural camaraderie and wit with executive dependability.',
    formality: 3.0,
    humor: 3.5,
    warmth: 4.5,
    brevity: 3.0,
    proactivity: 3.5,
  );

  static const chiefOfStaff = PersonalityProfile(
    id: 'chiefOfStaff',
    name: 'Executive Chief of Staff',
    tagline: 'Crisp, structured, decision-focused',
    description:
        'High-velocity professional style. Prioritizes deadlines, deliverables, and actionable takeaways with zero fluff.',
    formality: 5.0,
    humor: 1.0,
    warmth: 2.0,
    brevity: 5.0,
    proactivity: 4.0,
  );

  static const casualPartner = PersonalityProfile(
    id: 'casualPartner',
    name: 'Casual Creative Partner',
    tagline: 'Witty, relaxed, late-night camaraderie',
    description:
        'Relaxed and energetic co-pilot. Great for brainstorming, casual banter, and late-night desk sessions.',
    formality: 1.5,
    humor: 4.5,
    warmth: 5.0,
    brevity: 2.5,
    proactivity: 3.0,
  );

  static const calmMentor = PersonalityProfile(
    id: 'calmMentor',
    name: 'Calm Mentor',
    tagline: 'Reflective, patient, insightful advisor',
    description:
        'Patient, grounded presence that listens carefully, asks thoughtful questions, and maintains perspective.',
    formality: 3.0,
    humor: 2.0,
    warmth: 5.0,
    brevity: 2.5,
    proactivity: 2.5,
  );

  static List<PersonalityProfile> get presetProfiles => [
        companion,
        chiefOfStaff,
        casualPartner,
        calmMentor,
      ];

  static PersonalityProfile fromId(String id) {
    for (final p in presetProfiles) {
      if (p.id.toLowerCase() == id.toLowerCase()) return p;
    }
    return companion;
  }

  PersonalityProfile copyWith({
    String? id,
    String? name,
    String? tagline,
    String? description,
    double? formality,
    double? humor,
    double? warmth,
    double? brevity,
    double? proactivity,
  }) {
    return PersonalityProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      tagline: tagline ?? this.tagline,
      description: description ?? this.description,
      formality: formality ?? this.formality,
      humor: humor ?? this.humor,
      warmth: warmth ?? this.warmth,
      brevity: brevity ?? this.brevity,
      proactivity: proactivity ?? this.proactivity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'tagline': tagline,
      'description': description,
      'formality': formality,
      'humor': humor,
      'warmth': warmth,
      'brevity': brevity,
      'proactivity': proactivity,
    };
  }

  factory PersonalityProfile.fromMap(Map<String, dynamic> map) {
    return PersonalityProfile(
      id: map['id'] as String? ?? 'companion',
      name: map['name'] as String? ?? 'Dummy. Companion',
      tagline: map['tagline'] as String? ?? '',
      description: map['description'] as String? ?? '',
      formality: (map['formality'] as num?)?.toDouble() ?? 3.0,
      humor: (map['humor'] as num?)?.toDouble() ?? 3.0,
      warmth: (map['warmth'] as num?)?.toDouble() ?? 4.0,
      brevity: (map['brevity'] as num?)?.toDouble() ?? 3.0,
      proactivity: (map['proactivity'] as num?)?.toDouble() ?? 3.0,
    );
  }

  /// System prompt instructions to modulate LLM generation.
  String toPromptDirectives() {
    final buffer = StringBuffer();
    buffer.writeln('[PERSONALITY PROFILE: $name]');
    buffer.writeln('- Trait Dimensions (1 to 5 scale):');
    buffer.writeln('  * Formality (${formality.toStringAsFixed(1)}/5.0): ${formality >= 4.0 ? "Formal, professional, executive register." : (formality <= 2.0 ? "Casual, relaxed, natural conversational register." : "Balanced, approachable, professional yet friendly.")}');
    buffer.writeln('  * Humor (${humor.toStringAsFixed(1)}/5.0): ${humor >= 4.0 ? "Witty, playful, welcomes light jokes and friendly banter." : (humor <= 2.0 ? "Factual, serious, minimal or no joking." : "Warm, light-hearted when appropriate, serious when dealing with commitments.")}');
    buffer.writeln('  * Warmth (${warmth.toStringAsFixed(1)}/5.0): ${warmth >= 4.0 ? "Deeply empathetic, encouraging, thoughtful companion." : (warmth <= 2.0 ? "Direct, transactional, objective." : "Polite, supportive, attentive.")}');
    buffer.writeln('  * Brevity (${brevity.toStringAsFixed(1)}/5.0): ${brevity >= 4.0 ? "Ultra-crisp bullet points, high-signal, zero fluff." : (brevity <= 2.0 ? "Conversational, explanatory, comfortable with narrative." : "Concise, structured, clear paragraphs.")}');
    buffer.writeln('  * Proactivity (${proactivity.toStringAsFixed(1)}/5.0): ${proactivity >= 4.0 ? "Proactively flag upcoming commitments, stale touchpoints, and suggest next steps." : (proactivity <= 2.0 ? "Strictly answer what is asked without unsolicited suggestions." : "Balanced; offer suggestions only when directly relevant.")}');
    buffer.writeln('- Core Identity: $tagline.');
    return buffer.toString();
  }
}
