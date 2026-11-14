import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Clean initials / monogram avatar with muted tinted background.
class AppAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color? backgroundColor;
  final Color? textColor;

  const AppAvatar({
    super.key,
    required this.name,
    this.size = 38.0,
    this.backgroundColor,
    this.textColor,
  });

  String _getInitials(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = backgroundColor ??
        (isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle);
    final fg = textColor ??
        (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);
    final border = isDark ? AppColors.darkHairline : AppColors.lightHairline;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        _getInitials(name),
        style: TextStyle(
          color: fg,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
