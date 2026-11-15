import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/device_event_bus.dart';
import '../theme/app_haptics.dart';
import '../theme/design_tokens.dart';
import '../widgets/widgets.dart';
import 'ai_capture_sheet.dart';

/// Hardware Companion & Wearable Simulator Screen.
/// Proves the 'One Platform, Multiple Interfaces' architecture.
class HardwareCompanionScreen extends StatefulWidget {
  const HardwareCompanionScreen({super.key});

  @override
  State<HardwareCompanionScreen> createState() =>
      _HardwareCompanionScreenState();
}

class _HardwareCompanionScreenState extends State<HardwareCompanionScreen> {
  final _bus = DeviceEventBus();
  StreamSubscription<CompanionDeviceEvent>? _subscription;

  CompanionDeviceEvent? _activeDisplayEvent;
  final bool _isDeviceConnected = true;

  @override
  void initState() {
    super.initState();
    if (_bus.history.isNotEmpty) {
      _activeDisplayEvent = _bus.history.first;
    }
    _subscription = _bus.events.listen((event) {
      if (mounted) {
        setState(() {
          _activeDisplayEvent = event;
        });
        AppHaptics.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📳 [Hardware Haptic Alert] ${event.title}'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _triggerTestHardwareEvent() {
    AppHaptics.mediumImpact();
    _bus.dispatch(
      CompanionDeviceEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: CompanionEventType.commitmentDetected,
        title: 'New Promise Detected',
        summary: 'Send quotation to Rahim by tomorrow 3 PM',
        requiresHaptic: true,
      ),
    );
  }

  void _simulateWearableVoiceCapture() {
    AppHaptics.lightImpact();
    _bus.dispatch(
      CompanionDeviceEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: CompanionEventType.commitmentDetected,
        title: 'Voice Memo Captured via Pin',
        summary: 'Transcribed from companion microphone',
        requiresHaptic: false,
      ),
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AiCaptureSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('h:mm a');

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text('Wearable & Hardware Simulator', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxl),
        children: [
          // Architectural Banner
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.watch_outlined, size: 22, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'One Platform, Multiple Interfaces',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'This simulator demonstrates the event abstraction between the RemembrAI core engine and future wearable wristbands, smart watches, or portable AI companions.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Wearable Hardware Mockup Display
          Center(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: const Color(0xFF0C0D0E),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.grey.shade800, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Status bar on wearable
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        timeFormat.format(DateTime.now()),
                        style: const TextStyle(
                          color: Color(0xFF22C55E),
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Icon(
                        _isDeviceConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                        color: _isDeviceConnected ? const Color(0xFF38BDF8) : const Color(0xFFEF4444),
                        size: 14,
                      ),
                    ],
                  ),

                  // OLED Screen Content
                  if (_activeDisplayEvent == null)
                    const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_moon_outlined, color: Colors.white38, size: 36),
                        SizedBox(height: 8),
                        Text(
                          'RemembrAI Companion\nStandby',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _activeDisplayEvent!.type.label.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFFFBBF24),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _activeDisplayEvent!.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _activeDisplayEvent!.summary,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),

                  // Bottom indicator
                  Container(
                    width: 32,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Simulate Haptic Alert',
                  icon: Icons.vibration_rounded,
                  variant: AppButtonVariant.tonal,
                  size: AppButtonSize.sm,
                  onPressed: _triggerTestHardwareEvent,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: AppButton(
                  label: 'Simulate Voice Pin',
                  icon: Icons.mic_rounded,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.sm,
                  onPressed: _simulateWearableVoiceCapture,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          AppSectionHeader(
            title: 'Device Event Stream Log',
            count: _bus.history.length,
          ),
          const SizedBox(height: AppSpacing.xs),

          if (_bus.history.isEmpty)
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'No events broadcast yet.',
                style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
              ),
            )
          else
            ..._bus.history.map((ev) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: AppListRow(
                    leading: const Icon(Icons.sensors_rounded, size: 18, color: AppColors.primary),
                    title: ev.title,
                    subtitle: '${ev.type.label} · ${ev.summary}',
                    trailing: Text(
                      timeFormat.format(ev.timestamp),
                      style: TextStyle(fontSize: 11, color: AppColors.muted(context)),
                    ),
                    onTap: () {
                      AppHaptics.lightImpact();
                      setState(() => _activeDisplayEvent = ev);
                    },
                  ),
                )),
        ],
      ),
    );
  }
}
