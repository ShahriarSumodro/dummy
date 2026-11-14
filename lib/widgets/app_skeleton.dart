import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Shimmer skeleton block used for loading states instead of spinners.
class AppSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const AppSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = AppRadius.input,
  });

  factory AppSkeleton.card({double height = 80}) => AppSkeleton(
        width: double.infinity,
        height: height,
        borderRadius: AppRadius.card,
      );

  factory AppSkeleton.row() => const AppSkeleton(
        width: double.infinity,
        height: 56,
        borderRadius: AppRadius.input,
      );

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final baseColor =
        isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: baseColor.withValues(alpha: _animation.value),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: (isDark ? AppColors.darkHairline : AppColors.lightHairline)
                .withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
    );
  }
}
