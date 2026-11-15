import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../services/database_service.dart';
import '../services/voice_service.dart';
import '../services/notification_service.dart';
import '../models/assistant_settings.dart';
import '../models/personality_profile.dart';
import '../theme/app_haptics.dart';
import '../theme/design_tokens.dart';
import '../widgets/widgets.dart';
import 'hardware_companion_screen.dart';
import 'data_privacy_screen.dart';
import 'briefing_screen.dart';
import 'action_drafts_screen.dart';

/// Settings screen for configuring AI models, personas, voice preferences, and system parameters.
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
    AppHaptics.success();
    await AiServiceFactory.setApiKey(_apiKeyController.text);
    await AiServiceFactory.setProvider(_selectedProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedProvider.label} API key & provider saved.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter an API key first.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      );
      return;
    }

    AppHaptics.mediumImpact();
    setState(() => _isTestingConnection = true);
    try {
      final msg = await AiServiceFactory.testConnection(
        provider: _selectedProvider,
        apiKey: key,
      );
      if (mounted) {
        AppHaptics.success();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppHaptics.warning();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
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
    AppHaptics.lightImpact();
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
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text(
          'Settings & Configuration',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              children: [
                // ── AI Engine Section ──
                AppSectionHeader(title: 'AI Provider & Engine'),
                const SizedBox(height: AppSpacing.xs),

                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.offline_bolt_rounded,
                            size: 20,
                            color: _useMockMode
                                ? AppColors.primary
                                : Colors.grey,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Offline Rule Engine',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'Local heuristics without API key',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted(context),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _useMockMode,
                        activeColor: AppColors.primary,
                        onChanged: (val) async {
                          AppHaptics.lightImpact();
                          await AiServiceFactory.setMockMode(val);
                          setState(() => _useMockMode = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                if (!_useMockMode) ...[
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ACTIVE CLOUD PROVIDER',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.muted(context),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: _buildProviderSelector(
                                provider: AiProvider.gemini,
                                label: 'Google Gemini',
                                model: 'gemini-2.0-flash',
                                icon: Icons.auto_awesome_rounded,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _buildProviderSelector(
                                provider: AiProvider.groq,
                                label: 'Groq Cloud',
                                model: 'llama-3.3-70b',
                                icon: Icons.flash_on_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),

                        AppTextField(
                          controller: _apiKeyController,
                          label: '${_selectedProvider.label} API Key',
                          hintText: _selectedProvider == AiProvider.groq
                              ? 'gsk_...'
                              : 'AIzaSy...',
                          prefixIcon: Icons.key_rounded,
                          obscureText: _obscureKey,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureKey
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 18,
                            ),
                            onPressed: () =>
                                setState(() => _obscureKey = !_obscureKey),
                          ),
                          onChanged: (text) {
                            if (text.startsWith('gsk_') &&
                                _selectedProvider != AiProvider.groq) {
                              setState(
                                () => _selectedProvider = AiProvider.groq,
                              );
                              AiServiceFactory.setProvider(AiProvider.groq);
                            } else if (text.startsWith('AIza') &&
                                _selectedProvider != AiProvider.gemini) {
                              setState(
                                () => _selectedProvider = AiProvider.gemini,
                              );
                              AiServiceFactory.setProvider(AiProvider.gemini);
                            } else {
                              setState(() {});
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),

                        Row(
                          children: [
                            Expanded(
                              child: AppButton(
                                label: 'Save Key',
                                size: AppButtonSize.sm,
                                onPressed: _saveApiKey,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: AppButton(
                                label: _isTestingConnection
                                    ? 'Testing...'
                                    : 'Test Connection',
                                icon: Icons.bolt_rounded,
                                size: AppButtonSize.sm,
                                variant: AppButtonVariant.secondary,
                                loading: _isTestingConnection,
                                onPressed: _isTestingConnection
                                    ? null
                                    : _testConnection,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Keys remain encrypted strictly on your local device.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.muted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // ── Assistant Persona & Voice ──
                AppSectionHeader(title: 'Assistant Persona & Voice (Module 10)'),
                const SizedBox(height: AppSpacing.xs),

                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COMPANION PERSONALITY ARCHETYPE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.muted(context),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ...PersonalityProfile.presetProfiles.map((p) => _buildPersonaCard(p)),
                      const SizedBox(height: AppSpacing.sm),

                      // Live Voice Sample
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.subtle(context),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.subtle(context)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.record_voice_over_rounded, size: 18, color: AppColors.primary),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                _sampleSpeech(_assistantSettings.personality),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: AppSpacing.lg),

                      // Trait Dimensions Sliders
                      Text(
                        'FINE-TUNE TRAIT DIMENSIONS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.muted(context),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _buildTraitSlider(
                        label: 'Formality',
                        value: _assistantSettings.personality.formality,
                        minLabel: 'Casual',
                        maxLabel: 'Executive',
                        onChanged: (val) {
                          _updateSettings(_assistantSettings.copyWith(
                            personality: _assistantSettings.personality.copyWith(
                              id: 'custom',
                              name: 'Custom Tuned',
                              formality: val,
                            ),
                          ));
                        },
                      ),
                      _buildTraitSlider(
                        label: 'Humor & Banter',
                        value: _assistantSettings.personality.humor,
                        minLabel: 'Literal / Factual',
                        maxLabel: 'Witty / Playful',
                        onChanged: (val) {
                          _updateSettings(_assistantSettings.copyWith(
                            personality: _assistantSettings.personality.copyWith(
                              id: 'custom',
                              name: 'Custom Tuned',
                              humor: val,
                            ),
                          ));
                        },
                      ),
                      _buildTraitSlider(
                        label: 'Warmth & Empathy',
                        value: _assistantSettings.personality.warmth,
                        minLabel: 'Objective',
                        maxLabel: 'Supportive',
                        onChanged: (val) {
                          _updateSettings(_assistantSettings.copyWith(
                            personality: _assistantSettings.personality.copyWith(
                              id: 'custom',
                              name: 'Custom Tuned',
                              warmth: val,
                            ),
                          ));
                        },
                      ),
                      _buildTraitSlider(
                        label: 'Brevity',
                        value: _assistantSettings.personality.brevity,
                        minLabel: 'Detailed',
                        maxLabel: 'Crisp Bullets',
                        onChanged: (val) {
                          _updateSettings(_assistantSettings.copyWith(
                            personality: _assistantSettings.personality.copyWith(
                              id: 'custom',
                              name: 'Custom Tuned',
                              brevity: val,
                            ),
                          ));
                        },
                      ),
                      const Divider(height: AppSpacing.lg),

                      Text(
                        'PROACTIVITY LEVEL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.muted(context),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.xs,
                        children: ProactivityLevel.values.map((p) {
                          final isSel = _assistantSettings.proactivity == p;
                          return ChoiceChip(
                            label: Text(p.label),
                            selected: isSel,
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSel
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSel
                                  ? Colors.white
                                  : AppColors.foreground(context),
                            ),
                            onSelected: (_) => _updateSettings(
                              _assistantSettings.copyWith(proactivity: p),
                            ),
                          );
                        }).toList(),
                      ),
                      const Divider(height: AppSpacing.lg),

                      AppTextField(
                        controller: _userTitleController,
                        label: 'Your Executive Role / Designation',
                        hintText: 'e.g. Founder & CEO, Managing Director',
                        prefixIcon: Icons.badge_outlined,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.check_rounded, size: 18),
                          onPressed: () {
                            AppHaptics.success();
                            _updateSettings(
                              _assistantSettings.copyWith(
                                userTitle: _userTitleController.text.trim(),
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('User role saved.'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Notifications & Speech ──
                AppSectionHeader(title: 'Voice & Device Notifications'),
                const SizedBox(height: AppSpacing.xs),

                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.notifications_active_outlined,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Device Push Alerts',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'Sound & vibration when promises are due',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.muted(context),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Switch(
                            value: _assistantSettings.notificationsEnabled,
                            activeColor: AppColors.primary,
                            onChanged: (val) {
                              _updateSettings(
                                _assistantSettings.copyWith(
                                  notificationsEnabled: val,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppButton(
                        label: 'Send Test Push Notification',
                        icon: Icons.notifications_rounded,
                        variant: AppButtonVariant.tonal,
                        size: AppButtonSize.sm,
                        fullWidth: true,
                        onPressed: () async {
                          AppHaptics.lightImpact();
                          await NotificationService().showTestNotification();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Test alert sent! Check your notification tray.',
                                ),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      const Divider(height: AppSpacing.lg),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.record_voice_over_outlined,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Auto-Speak AI Responses',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'Read chat answers aloud automatically',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.muted(context),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Switch(
                            value: _assistantSettings.autoSpeakResponses,
                            activeColor: AppColors.primary,
                            onChanged: (val) {
                              _updateSettings(
                                _assistantSettings.copyWith(
                                  autoSpeakResponses: val,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Text(
                            'Speed: ${_assistantSettings.speechRate.toStringAsFixed(1)}x',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: _assistantSettings.speechRate,
                              min: 0.3,
                              max: 1.0,
                              divisions: 7,
                              activeColor: AppColors.primary,
                              label:
                                  '${_assistantSettings.speechRate.toStringAsFixed(1)}x',
                              onChanged: (val) => _updateSettings(
                                _assistantSettings.copyWith(speechRate: val),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'Test Assistant Voice',
                              icon: Icons.volume_up_rounded,
                              size: AppButtonSize.sm,
                              variant: AppButtonVariant.secondary,
                              onPressed: () {
                                AppHaptics.lightImpact();
                                VoiceService().speak(
                                  'Hello! I am RemembrAI, your personal AI companion. Your system is operational and ready.',
                                );
                              },
                            ),
                          ),
                          ValueListenableBuilder<TtsState>(
                            valueListenable: VoiceService().ttsState,
                            builder: (context, state, _) {
                              if (state == TtsState.playing) {
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    left: AppSpacing.xs,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.stop_circle_rounded,
                                      color: AppColors.error,
                                    ),
                                    onPressed: () => VoiceService().stop(),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Advanced Tools ──
                AppSectionHeader(title: 'Utilities & Hardware Companion'),
                const SizedBox(height: AppSpacing.xs),

                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      AppListRow(
                        leading: const Icon(
                          Icons.watch_outlined,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        title: 'Wearable Companion Simulator',
                        subtitle:
                            'Simulate hardware pin, wristband & haptic pulses',
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: Colors.grey,
                        ),
                        onTap: () {
                          AppHaptics.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HardwareCompanionScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      AppListRow(
                        leading: const Icon(
                          Icons.security_outlined,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        title: 'Data Privacy & Local Backup',
                        subtitle:
                            'Export complete JSON backup or wipe local memory',
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: Colors.grey,
                        ),
                        onTap: () {
                          AppHaptics.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DataPrivacyScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      AppListRow(
                        leading: const Icon(
                          Icons.auto_stories_outlined,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        title: 'Executive Briefing Engine',
                        subtitle: 'Generate executive daily memos or dossiers',
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: Colors.grey,
                        ),
                        onTap: () {
                          AppHaptics.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BriefingScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Version Stamp
                Center(
                  child: Text(
                    'RemembrAI v0.1.0 · Personal AI Companion',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.muted(context),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
    );
  }

  Widget _buildProviderSelector({
    required AiProvider provider,
    required String label,
    required String model,
    required IconData icon,
  }) {
    final isSelected = _selectedProvider == provider;
    return InkWell(
      onTap: () async {
        AppHaptics.lightImpact();
        setState(() => _selectedProvider = provider);
        await AiServiceFactory.setProvider(provider);
      },
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.subtle(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border(context),
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.muted(context),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.foreground(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              model,
              style: TextStyle(fontSize: 10, color: AppColors.muted(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonaCard(PersonalityProfile profile) {
    final isSelected = _assistantSettings.personality.id == profile.id;
    return InkWell(
      onTap: () {
        AppHaptics.selectionClick();
        _updateSettings(_assistantSettings.copyWith(
          personality: profile,
          tone: profile.id == 'chiefOfStaff'
              ? AssistantTone.executive
              : (profile.id == 'casualPartner'
                  ? AssistantTone.conversational
                  : (profile.id == 'calmMentor'
                      ? AssistantTone.analytical
                      : AssistantTone.companion)),
        ));
      },
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: isSelected ? AppColors.primary : AppColors.muted(context),
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: AppColors.foreground(context),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    profile.tagline,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.muted(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sampleSpeech(PersonalityProfile p) {
    switch (p.id) {
      case 'chiefOfStaff':
        return '“Ready. 3 commitments tracked. 0 overdue. Awaiting your directive.”';
      case 'casualPartner':
        return '“Hey! What’s happening? Ready to crush today’s follow-ups with you.”';
      case 'calmMentor':
        return '“Peace to your day. Let’s take a calm look at what is on your schedule.”';
      default:
        return '“Hello! Always right here beside you. How can I help you move forward today?”';
    }
  }

  Widget _buildTraitSlider({
    required String label,
    required double value,
    required String minLabel,
    required String maxLabel,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                '${value.toStringAsFixed(1)} / 5.0',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: value,
              min: 1.0,
              max: 5.0,
              divisions: 8,
              activeColor: AppColors.primary,
              onChanged: onChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  minLabel,
                  style: TextStyle(fontSize: 10, color: AppColors.muted(context)),
                ),
                Text(
                  maxLabel,
                  style: TextStyle(fontSize: 10, color: AppColors.muted(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
