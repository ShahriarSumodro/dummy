import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../services/database_service.dart';
import '../services/voice_service.dart';
import '../services/notification_service.dart';
import '../models/assistant_settings.dart';
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

                // ── Assistant Persona ──
                AppSectionHeader(title: 'Assistant Persona & Voice'),
                const SizedBox(height: AppSpacing.xs),

                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RESPONSE TONE',
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
                        children: AssistantTone.values.map((t) {
                          final isSel = _assistantSettings.tone == t;
                          return ChoiceChip(
                            label: Text(t.label),
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
                              _assistantSettings.copyWith(tone: t),
                            ),
                          );
                        }).toList(),
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
                                  'Hello! I am Dummy., your personal business memory assistant. Your system is operational and ready.',
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
                    'Dummy. v0.1.0 · Personal Executive Memory Assistant',
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
}
