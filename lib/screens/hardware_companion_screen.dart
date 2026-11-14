import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/device_event_bus.dart';
import 'ai_capture_sheet.dart';

/// Hardware Companion & Wearable Simulator Screen.
/// Proves the 'One Platform, Multiple Interfaces' architecture (Master Prompt Section 3).
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📳 [Hardware Haptic Alert] ${event.title}'),
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
      builder: (_) => const AiCaptureSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wearable & Hardware Simulator'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Architectural explanation
          Card(
            elevation: 0,
            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.watch_outlined, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'One Platform, Multiple Interfaces',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This simulator demonstrates the event abstraction between the RemembrAI core engine and future wearable wristbands, smart watches, or portable AI pins.',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Wearable Hardware Mockup Display
          Center(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.grey.shade800, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 16,
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
                          color: Colors.greenAccent,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Icon(
                        _isDeviceConnected
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth_disabled,
                        color: _isDeviceConnected
                            ? Colors.blueAccent
                            : Colors.redAccent,
                        size: 14,
                      ),
                    ],
                  ),

                  // OLED Screen Content
                  if (_activeDisplayEvent == null)
                    const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_moon_outlined,
                            color: Colors.white38, size: 36),
                        SizedBox(height: 8),
                        Text(
                          'RemembrAI Pin\nStandby',
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
                            color: Colors.amberAccent,
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
          const SizedBox(height: 20),

          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _triggerTestHardwareEvent,
                icon: const Icon(Icons.vibration),
                label: const Text('Simulate Haptic Alert'),
              ),
              FilledButton.icon(
                onPressed: _simulateWearableVoiceCapture,
                icon: const Icon(Icons.mic),
                label: const Text('Simulate Voice Dictation'),
              ),
            ],
          ),
          const Divider(height: 36),

          Text('Device Event Stream Log',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              )),
          const SizedBox(height: 8),

          if (_bus.history.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No events broadcast yet.'),
            )
          else
            ..._bus.history.map((ev) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.sensors, size: 18),
                  title: Text(ev.title),
                  subtitle: Text('${ev.type.label} · ${ev.summary}'),
                  trailing: Text(
                    timeFormat.format(ev.timestamp),
                    style: theme.textTheme.bodySmall,
                  ),
                  onTap: () => setState(() => _activeDisplayEvent = ev),
                )),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
