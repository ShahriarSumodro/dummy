import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

class AppAvatarSize {
  AppAvatarSize._();
  static const double sm = 28.0;
  static const double md = 38.0;
  static const double lg = 48.0;
  static const double xl = 64.0;
}

/// Clean initials / monogram avatar with muted tinted background.
class AppAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color? backgroundColor;
  final Color? textColor;

  const AppAvatar({
    super.key,
    required this.name,
    this.size = AppAvatarSize.md,
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
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
