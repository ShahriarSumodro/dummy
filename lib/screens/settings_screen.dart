import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../services/database_service.dart';
import '../services/voice_service.dart';
import '../services/notification_service.dart';
import '../models/assistant_settings.dart';
import 'hardware_companion_screen.dart';
import 'data_privacy_screen.dart';
import 'briefing_screen.dart';
import 'action_drafts_screen.dart';

/// Settings screen for configuring AI models and preferences.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = DatabaseService();
  final _apiKeyController = TextEditingController();
  final _userTitleController = TextEditingController();
  AssistantSettings _assistantSettings = const AssistantSettings();
  AiProvider _selectedProvider = AiProvider.gemini;
  bool _useMockMode = false;
  bool _obscureKey = true;
  bool _loading = true;
  bool _isTestingConnection = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final apiKey = await AiServiceFactory.getApiKey();
    final mock = await AiServiceFactory.isMockMode();
    final provider = await AiServiceFactory.getProvider();
    final settings = await _db.getAssistantSettings();
    if (mounted) {
      setState(() {
        _apiKeyController.text = apiKey ?? '';
        _useMockMode = mock;
        _selectedProvider = provider;
        _assistantSettings = settings;
        _userTitleController.text = settings.userTitle;
        _loading = false;
      });
      await VoiceService().setLanguage(settings.language.name);
      await VoiceService().setRate(settings.speechRate);
    }
  }

  Future<void> _saveApiKey() async {
    await AiServiceFactory.setApiKey(_apiKeyController.text);
    await AiServiceFactory.setProvider(_selectedProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedProvider.label} API key & provider saved.'),
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an API key first.')),
      );
      return;
    }

    setState(() => _isTestingConnection = true);
    try {
      final msg = await AiServiceFactory.testConnection(
        provider: _selectedProvider,
        apiKey: key,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.green.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTestingConnection = false);
      }
    }
  }

  Future<void> _updateSettings(AssistantSettings updated) async {
    setState(() => _assistantSettings = updated);
    await _db.saveAssistantSettings(updated);
    await VoiceService().setLanguage(updated.language.name);
    await VoiceService().setRate(updated.speechRate);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _userTitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & AI Configuration'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // AI Engine Section
                Text(
                  'AI Provider',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                SwitchListTile(
                  title: const Text('Use Offline / Simulated AI'),
                  subtitle: const Text(
                    'Extracts memories locally with built-in heuristic rules without requiring an API key or internet.',
                  ),
                  value: _useMockMode,
                  onChanged: (val) async {
                    await AiServiceFactory.setMockMode(val);
                    setState(() => _useMockMode = val);
                  },
                ),
                const Divider(height: 32),

                // Multi-Provider AI Section
                if (!_useMockMode) ...[
                  Text(
                    'Active AI Provider',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  SegmentedButton<AiProvider>(
                    segments: const [
                      ButtonSegment(
                        value: AiProvider.gemini,
                        label: Text('Google Gemini'),
                        icon: Icon(Icons.auto_awesome),
                      ),
                      ButtonSegment(
                        value: AiProvider.groq,
                        label: Text('Groq Cloud'),
                        icon: Icon(Icons.flash_on),
                      ),
                    ],
                    selected: {_selectedProvider},
                    onSelectionChanged: (val) async {
                      final p = val.first;
                      setState(() => _selectedProvider = p);
                      await AiServiceFactory.setProvider(p);
                    },
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _selectedProvider == AiProvider.groq
                              ? Icons.speed
                              : Icons.psychology,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedProvider == AiProvider.groq
                                ? 'Groq LPU: Uses "llama-3.3-70b-versatile" for sub-second inference. Free at console.groq.com (Key starts with "gsk_")'
                                : 'Google Gemini: Uses "gemini-2.0-flash" with 1M token context. 100% free tier at aistudio.google.com (15 RPM, no credit card required).',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _apiKeyController,
                    obscureText: _obscureKey,
                    decoration: InputDecoration(
                      labelText: '${_selectedProvider.label} API Key',
                      hintText: _selectedProvider == AiProvider.groq
                          ? 'gsk_...'
                          : 'AIzaSy...',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureKey ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _obscureKey = !_obscureKey);
                        },
                      ),
                    ),
                    onChanged: (text) {
                      if (text.startsWith('gsk_') &&
                          _selectedProvider != AiProvider.groq) {
                        setState(() => _selectedProvider = AiProvider.groq);
                        AiServiceFactory.setProvider(AiProvider.groq);
                      } else if (text.startsWith('AIza') &&
                          _selectedProvider != AiProvider.gemini) {
                        setState(() => _selectedProvider = AiProvider.gemini);
                        AiServiceFactory.setProvider(AiProvider.gemini);
                      } else {
                        setState(() {});
                      }
                    },
                  ),
                  if (_selectedProvider == AiProvider.groq &&
                      _apiKeyController.text.isNotEmpty &&
                      !_apiKeyController.text.startsWith('gsk_')) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.shade700, width: 0.8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.amber.shade900),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Groq keys start with "gsk_". Create a free key at console.groq.com/keys',
                              style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_selectedProvider == AiProvider.gemini &&
                      _apiKeyController.text.isNotEmpty &&
                      !_apiKeyController.text.startsWith('AIza')) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.shade700, width: 0.8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.amber.shade900),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Gemini keys start with "AIzaSy...". Create a free key at aistudio.google.com',
                              style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      FilledButton.tonal(
                        onPressed: _saveApiKey,
                        child: const Text('Save Configuration'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed:
                            _isTestingConnection ? null : _testConnection,
                        icon: _isTestingConnection
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.bolt, size: 16),
                        label: const Text('Test Connection'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Keys are stored strictly in local device storage and are never uploaded to any third-party server.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const Divider(height: 32),
                ],

                // Assistant Persona & Personalization
                Text(
                  'Assistant Persona & Personalization',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tailor how RemembrAI synthesizes your memories and drafts responses.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                // Tone
                Text('Response Tone', style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                SegmentedButton<AssistantTone>(
                  segments: AssistantTone.values
                      .map((t) => ButtonSegment(
                            value: t,
                            label: Text(t.label, style: const TextStyle(fontSize: 11)),
                          ))
                      .toList(),
                  selected: {_assistantSettings.tone},
                  onSelectionChanged: (val) {
                    _updateSettings(_assistantSettings.copyWith(tone: val.first));
                  },
                ),
                const SizedBox(height: 16),

                // Language
                Text('Primary Communication Language', style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                SegmentedButton<AssistantLanguage>(
                  segments: AssistantLanguage.values
                      .map((l) => ButtonSegment(
                            value: l,
                            label: Text(l.label, style: const TextStyle(fontSize: 11)),
                          ))
                      .toList(),
                  selected: {_assistantSettings.language},
                  onSelectionChanged: (val) {
                    _updateSettings(_assistantSettings.copyWith(language: val.first));
                  },
                ),
                const SizedBox(height: 16),

                // Proactivity
                Text('Proactivity Level', style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                SegmentedButton<ProactivityLevel>(
                  segments: ProactivityLevel.values
                      .map((p) => ButtonSegment(
                            value: p,
                            label: Text(p.label, style: const TextStyle(fontSize: 10)),
                          ))
                      .toList(),
                  selected: {_assistantSettings.proactivity},
                  onSelectionChanged: (val) {
                    _updateSettings(_assistantSettings.copyWith(proactivity: val.first));
                  },
                ),
                const SizedBox(height: 16),

                // User Title / Executive Role
                TextField(
                  controller: _userTitleController,
                  decoration: InputDecoration(
                    labelText: 'Your Role / Designation (optional)',
                    hintText: 'e.g. Founder & CEO, Managing Director',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check),
                      onPressed: () {
                        _updateSettings(_assistantSettings.copyWith(
                          userTitle: _userTitleController.text.trim(),
                        ));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('User role saved.')),
                        );
                      },
                    ),
                  ),
                  onSubmitted: (val) {
                    _updateSettings(_assistantSettings.copyWith(
                      userTitle: val.trim(),
                    ));
                  },
                ),
                const Divider(height: 32),

                // Push Notifications & Proactive Alerts
                Text(
                  'Push Notifications & Proactive Alerts',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Get alerted on your phone when business promises, follow-ups, and meetings reach their deadline.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable Device Notifications'),
                  subtitle: const Text('Sound & vibration alerts when commitments are due'),
                  value: _assistantSettings.notificationsEnabled,
                  onChanged: (val) {
                    _updateSettings(_assistantSettings.copyWith(notificationsEnabled: val));
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await NotificationService().showTestNotification();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Test notification sent! Check your device notification bar.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.notifications_active_outlined, size: 18),
                  label: const Text('Send Test Push Notification'),
                ),
                const Divider(height: 32),

                // Voice & Speech Synthesis (TTS)
                Text(
                  'Voice & Speech Synthesis (TTS)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Have RemembrAI speak out loud so you can listen hands-free on the go.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-Speak AI Responses'),
                  subtitle: const Text('Automatically read answers aloud in the chat assistant'),
                  value: _assistantSettings.autoSpeakResponses,
                  onChanged: (val) {
                    _updateSettings(_assistantSettings.copyWith(autoSpeakResponses: val));
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Voice Speed: ${_assistantSettings.speechRate.toStringAsFixed(1)}x',
                      style: theme.textTheme.bodySmall,
                    ),
                    Expanded(
                      child: Slider(
                        value: _assistantSettings.speechRate,
                        min: 0.3,
                        max: 1.0,
                        divisions: 7,
                        label: '${_assistantSettings.speechRate.toStringAsFixed(1)}x',
                        onChanged: (val) {
                          _updateSettings(_assistantSettings.copyWith(speechRate: val));
                        },
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        VoiceService().speak(
                          'Hello! I am RemembrAI, your personal business memory assistant. Your Groq artificial intelligence is connected and speaking with you.',
                        );
                      },
                      icon: const Icon(Icons.record_voice_over_outlined, size: 18),
                      label: const Text('Test Assistant Voice'),
                    ),
                    ValueListenableBuilder<TtsState>(
                      valueListenable: VoiceService().ttsState,
                      builder: (context, state, _) {
                        if (state == TtsState.playing) {
                          return TextButton.icon(
                            onPressed: () => VoiceService().stop(),
                            icon: const Icon(Icons.stop_circle, color: Colors.red),
                            label: const Text('Stop Voice', style: TextStyle(color: Colors.red)),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
                const Divider(height: 32),

                // Advanced & Companion Tools
                Text(
                  'Interfaces & Hardware',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.watch_outlined),
                  title: const Text('Wearable & Hardware Companion'),
                  subtitle: const Text('Simulate companion pin, wristband & haptics'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HardwareCompanionScreen(),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.security_outlined),
                  title: const Text('Data Privacy, Security & Backup'),
                  subtitle: const Text('Export JSON backup or manage local retention'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DataPrivacyScreen(),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.drafts_outlined),
                  title: const Text('Action & Follow-Up Drafts'),
                  subtitle: const Text('Review prepared communications'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ActionDraftsScreen(),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.auto_stories_outlined),
                  title: const Text('Executive Briefing Engine'),
                  subtitle: const Text('Generate daily memos or contact dossiers'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BriefingScreen(),
                    ),
                  ),
                ),
                const Divider(height: 32),

                // App Info
                Text(
                  'About RemembrAI',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const ListTile(
                  leading: Icon(Icons.psychology_outlined),
                  title: Text('RemembrAI v0.1.0'),
                  subtitle: Text('Personal Business Memory & Execution Assistant'),
                ),
              ],
            ),
    );
  }
}
