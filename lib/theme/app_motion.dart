import 'package:flutter/material.dart';
import 'app_haptics.dart';

/// Centralized Motion specifications and reusable interaction widgets.
class AppMotion {
  AppMotion._();

  // Durations
  static const Duration micro = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration entrance = Duration(milliseconds: 320);
  static const Duration sheet = Duration(milliseconds: 350);

  // Standard smooth easing curves
  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeInOut = Curves.easeInOutCubic;
}

/// Reusable Pressable widget that scales down to 0.97 on press with haptic feedback.
/// Used on interactive cards, buttons, and custom controls.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double targetScale;
  final bool enableHaptics;
  final HitTestBehavior behavior;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.targetScale = 0.97,
    this.enableHaptics = true,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.micro,
      reverseDuration: AppMotion.micro,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.targetScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppMotion.easeOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    _controller.forward();
    if (widget.enableHaptics) {
      AppHaptics.lightImpact();
    }
  }

  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null && widget.onLongPress == null) {
      return widget.child;
    }

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress != null
          ? () {
              if (widget.enableHaptics) AppHaptics.mediumImpact();
              widget.onLongPress!();
            }
          : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
