import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/commitment.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  Function(String?)? onNotificationTapped;

  static const String channelIdReminders = 'dummy_reminders';
  static const String channelNameReminders = 'Commitments & Reminders';
  static const String channelDescReminders =
      'Notifications for upcoming commitments, deliverables, and promises.';

  static const String channelIdBriefing = 'dummy_briefings';
  static const String channelNameBriefing = 'Daily Intelligence Briefings';
  static const String channelDescBriefing =
      'Morning agenda, pending follow-ups, and relationship health summaries.';

  Future<void> initialize({Function(String?)? onSelectNotification}) async {
    if (_initialized) return;
    onNotificationTapped = onSelectNotification;

    try {
      tz.initializeTimeZones();
    } catch (e) {
      debugPrint('Timezone initialization error: $e');
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification tapped: ${response.payload}');
          if (onNotificationTapped != null) {
            onNotificationTapped!(response.payload);
          }
        },
      );

      // Create Notification Channels for Android
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        // Request runtime permission for Android 13+ (API 33+)
        if (Platform.isAndroid) {
          await androidImplementation.requestNotificationsPermission();
        }

        const AndroidNotificationChannel remindersChannel =
            AndroidNotificationChannel(
          channelIdReminders,
          channelNameReminders,
          description: channelDescReminders,
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        );

        const AndroidNotificationChannel briefingChannel =
            AndroidNotificationChannel(
          channelIdBriefing,
          channelNameBriefing,
          description: channelDescBriefing,
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        );

        await androidImplementation.createNotificationChannel(remindersChannel);
        await androidImplementation.createNotificationChannel(briefingChannel);
      }

      _initialized = true;
      debugPrint('NotificationService initialized successfully.');
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  /// Show an immediate push notification
  Future<void> showNotification({
    int id = 0,
    required String title,
    required String body,
    String? payload,
    String channelId = channelIdReminders,
    String channelName = channelNameReminders,
  }) async {
    if (!_initialized) await initialize();

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.max,
      priority: Priority.high,
      ticker: title,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(body),
    );

    final NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    try {
      await _notificationsPlugin.show(
        id,
        title,
        body,
        platformDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }

  /// Schedule a notification at a specific date and time
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_initialized) await initialize();

    // If date is in the past, do not schedule
    if (scheduledDate.isBefore(DateTime.now())) return;

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      channelIdReminders,
      channelNameReminders,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(body),
    );

    final NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    try {
      final tz.TZDateTime tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint('Reminder scheduled for $tzDate (ID: $id)');
    } catch (e) {
      debugPrint('Error scheduling reminder: $e');
    }
  }

  /// Schedule a reminder specifically for a business commitment
  Future<void> scheduleCommitmentNotification(Commitment commitment) async {
    if (commitment.id == null || commitment.dueDate == null) return;
    if (commitment.status == CommitmentStatus.completed) {
      await cancelReminder(commitment.id!);
      return;
    }

    final dueDate = commitment.dueDate!;
    final now = DateTime.now();

    // If due date is already passed, alert if today, else ignore
    if (dueDate.isBefore(now)) return;

    var cleanTitle = commitment.title.trim();
    cleanTitle = cleanTitle.replaceAll(
      RegExp(r"^(i have got|i have|i've|i got)\s+(a\s+)?", caseSensitive: false),
      '',
    );
    cleanTitle = cleanTitle.replaceAll(
      RegExp(r"^(i will|i'll|i promise to|i promised to|i promised|i need to|i have to)\s+", caseSensitive: false),
      '',
    );
    if (cleanTitle.isNotEmpty) {
      cleanTitle = cleanTitle[0].toUpperCase() + cleanTitle.substring(1);
    }

    final title = 'Reminder: $cleanTitle';
    final body = commitment.contactName != null
        ? 'You have a commitment with ${commitment.contactName}: $cleanTitle.'
        : 'You have a commitment scheduled: $cleanTitle.';

    await scheduleReminder(
      id: commitment.id!,
      title: title,
      body: body,
      scheduledDate: dueDate,
      payload: 'commitment:${commitment.id}',
    );
  }

  /// Cancel a specific reminder
  Future<void> cancelReminder(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
    } catch (e) {
      debugPrint('Error canceling notification $id: $e');
    }
  }

  /// Cancel all scheduled reminders
  Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('Error canceling all notifications: $e');
    }
  }

  /// Push an instant test notification so the user can verify it working on their device right away
  Future<void> showTestNotification() async {
    await showNotification(
      id: 9999,
      title: '🔔 Dummy. Active',
      body: 'Push notifications are connected! Your business commitments & follow-ups will alert you right on schedule.',
      payload: 'test_notification',
    );
  }
}
