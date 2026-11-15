import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/shell_screen.dart';

class DummyApp extends StatelessWidget {
  const DummyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dummy.',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const ShellScreen(),
    );
  }
}
