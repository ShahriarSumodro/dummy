import 'package:flutter/material.dart';

/// App-wide theme configuration using Material 3.
class AppTheme {
  AppTheme._();

  // Brand color — a calm, professional blue-teal.
  static const _seed = Color(0xFF2E7D6F);

  static final light = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: _seed,
    brightness: Brightness.light,
    fontFamily: 'Roboto',
  );

  static final dark = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: _seed,
    brightness: Brightness.dark,
    fontFamily: 'Roboto',
  );
}
