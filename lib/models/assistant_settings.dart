/// Assistant tone setting.
enum AssistantTone {
  executive('Executive', 'Crisp, high-signal, decision-focused bullet points'),
  conversational('Conversational', 'Warm, helpful executive co-pilot'),
  analytical('Analytical', 'Detailed, structured, risk-aware breakdown');

  final String label;
  final String description;
  const AssistantTone(this.label, this.description);
}

/// Preferred communication language for RemembrAI responses.
enum AssistantLanguage {
  english('English', 'Respond strictly in English'),
  bangla('বাংলা', 'বাংলা ভাষায় সম্পূর্ণ উত্তর দিন'),
  banglish('Banglish', 'Natural conversational Bengali written in English script');

  final String label;
  final String description;
  const AssistantLanguage(this.label, this.description);
}

/// Proactivity level of AI memory suggestions.
enum ProactivityLevel {
  minimal('Strict / Minimal', 'Answer only what is asked without unrequested reminders'),
  balanced('Balanced', 'Answer questions and highlight related overdue commitments'),
  high('Highly Proactive', 'Proactively surface relationship stale warnings and upcoming deadlines');

  final String label;
  final String description;
  const ProactivityLevel(this.label, this.description);
}

/// Holds personalization preferences for the AI Assistant.
class AssistantSettings {
  final AssistantTone tone;
  final AssistantLanguage language;
  final ProactivityLevel proactivity;
  final String userTitle; // e.g. 'CEO', 'Director', 'Founder', or empty
  final bool autoSpeakResponses;
  final bool notificationsEnabled;
  final double speechRate;

  const AssistantSettings({
    this.tone = AssistantTone.executive,
    this.language = AssistantLanguage.english,
    this.proactivity = ProactivityLevel.balanced,
    this.userTitle = '',
    this.autoSpeakResponses = false,
    this.notificationsEnabled = true,
    this.speechRate = 0.5,
  });

  static const ProactivityLevel _defaultProactivity = ProactivityLevel.balanced;
  const AssistantSettings.defaults()
      : tone = AssistantTone.executive,
        language = AssistantLanguage.english,
        proactivity = _defaultProactivity,
        userTitle = '',
        autoSpeakResponses = false,
        notificationsEnabled = true,
        speechRate = 0.5;

  AssistantSettings copyWith({
    AssistantTone? tone,
    AssistantLanguage? language,
    ProactivityLevel? proactivity,
    String? userTitle,
    bool? autoSpeakResponses,
    bool? notificationsEnabled,
    double? speechRate,
  }) {
    return AssistantSettings(
      tone: tone ?? this.tone,
      language: language ?? this.language,
      proactivity: proactivity ?? this.proactivity,
      userTitle: userTitle ?? this.userTitle,
      autoSpeakResponses: autoSpeakResponses ?? this.autoSpeakResponses,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      speechRate: speechRate ?? this.speechRate,
    );
  }

  /// System prompt instructions derived from these settings.
  String toSystemPromptAddition() {
    final buffer = StringBuffer();
    buffer.writeln('\n[ASSISTANT PERSONALIZATION DIRECTIVES]');
    
    // Tone
    switch (tone) {
      case AssistantTone.executive:
        buffer.writeln('- TONE: Ultra-crisp, executive summary style. Prioritize actionable facts, names, numbers, and deadlines. Avoid filler.');
        break;
      case AssistantTone.conversational:
        buffer.writeln('- TONE: Warm, polished executive co-pilot. Polite and engaging.');
        break;
      case AssistantTone.analytical:
        buffer.writeln('- TONE: Analytical, structured, thorough. Categorize observations and assess commitment risks.');
        break;
    }

    // Language
    switch (language) {
      case AssistantLanguage.english:
        buffer.writeln('- LANGUAGE: Standard Professional English.');
        break;
      case AssistantLanguage.bangla:
        buffer.writeln('- LANGUAGE: বাংলা (Bengali). সমস্ত উত্তর শুদ্ধ ও সাবলীল প্রফেশনাল বাংলায় দিন।');
        break;
      case AssistantLanguage.banglish:
        buffer.writeln('- LANGUAGE: Banglish (Bengali spoken language written phonetically in English/Latin letters, e.g. "Apnar Tanvir bhai er shathe meeting ache").');
        break;
    }

    // Proactivity
    switch (proactivity) {
      case ProactivityLevel.minimal:
        buffer.writeln('- PROACTIVITY: Answer strictly what the user asked. Do not add unsolicited follow-ups.');
        break;
      case ProactivityLevel.balanced:
        buffer.writeln('- PROACTIVITY: If relevant overdue promises or meetings relate to the question, briefly note them at the end.');
        break;
      case ProactivityLevel.high:
        buffer.writeln('- PROACTIVITY: Proactively highlight urgent deadlines, uncontacted key people, and suggest concrete next steps.');
        break;
    }

    if (userTitle.trim().isNotEmpty) {
      buffer.writeln('- USER ROLE: The user is addressed as ${userTitle.trim()}. Tailor strategic recommendations to this role.');
    }

    return buffer.toString();
  }
}
