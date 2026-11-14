import 'package:flutter/services.dart';

/// Centralized Haptic Feedback helper.
/// Provides platform-appropriate tactile response.
/// Can be globally enabled or disabled according to user preferences.
class AppHaptics {
  AppHaptics._();

  static bool enabled = true;

  /// Light impact for frequent micro-interactions (toggles, chips, tabs)
  static Future<void> lightImpact() async {
    if (!enabled) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Medium impact for confirmations and card selections
  static Future<void> mediumImpact() async {
    if (!enabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Success feedback for task completion and commitment approvals
  static Future<void> success() async {
    if (!enabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Warning / destructive feedback for deletes or cancellations
  static Future<void> warning() async {
    if (!enabled) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Selection click for pickers or list scrolling
  static Future<void> selectionClick() async {
    if (!enabled) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
