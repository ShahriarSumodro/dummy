import 'dart:async';

/// Supported hardware / companion interface event types.
enum CompanionEventType {
  reminderDue('Reminder Due', 'Trigger sound & haptic alert'),
  commitmentDetected('Commitment Detected', 'Display compact confirmation prompt'),
  briefingReady('Briefing Ready', 'Notify user to check executive dossier'),
  actionApprovalRequired('Action Approval Required', 'Display single-tap approval prompt');

  final String label;
  final String description;
  const CompanionEventType(this.label, this.description);
}

/// A structured event dispatched from the core assistant engine to interfaces.
class CompanionDeviceEvent {
  final String id;
  final CompanionEventType type;
  final String title;
  final String summary;
  final DateTime timestamp;
  final bool requiresHaptic;

  CompanionDeviceEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.summary,
    DateTime? timestamp,
    this.requiresHaptic = true,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// The Device Event Bus: Decouples the assistant logic from physical interfaces.
/// Wearables, portable strap devices, or mobile UI subscribe to this stream.
class DeviceEventBus {
  static final DeviceEventBus _instance = DeviceEventBus._internal();
  factory DeviceEventBus() => _instance;
  DeviceEventBus._internal();

  final _controller = StreamController<CompanionDeviceEvent>.broadcast();
  final List<CompanionDeviceEvent> _eventHistory = [];

  Stream<CompanionDeviceEvent> get events => _controller.stream;
  List<CompanionDeviceEvent> get history => List.unmodifiable(_eventHistory);

  void dispatch(CompanionDeviceEvent event) {
    _eventHistory.insert(0, event);
    if (_eventHistory.length > 50) {
      _eventHistory.removeLast();
    }
    _controller.add(event);
  }
}
