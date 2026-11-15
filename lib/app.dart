import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/shell_screen.dart';

class RemembrAIApp extends StatelessWidget {
  const RemembrAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RemembrAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const ShellScreen(),
    );
  }
}

typedef DummyApp = RemembrAIApp;
