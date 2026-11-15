import 'package:flutter/material.dart';
import 'app.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'services/voice_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Guarantee single database initialization at startup
  try {
    await DatabaseService().database;
  } catch (e) {
    debugPrint('Database init exception: $e');
  }

  // Initialize device push notifications & voice speech engine
  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('Notification init exception: $e');
  }

  try {
    await VoiceService().initialize();
  } catch (e) {
    debugPrint('Voice init exception: $e');
  }

  runApp(const DummyApp());
}
