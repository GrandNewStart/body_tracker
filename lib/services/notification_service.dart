import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/app_config.dart';
import '../l10n/app_strings.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static const int _fixedTimeReminderId = 1001;
  static const int _lateReminderId = 1002;

  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (e) {
      debugPrint('NotificationService: Failed to configure local timezone: $e');
    }
  }

  Future<void> init() async {
    await _configureLocalTimeZone();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    try {
      await _notificationsPlugin.initialize(settings: initSettings);

      // Request permission on Android 13+
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();

      // Request permission on iOS
      final iosImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('Notification initialization error: $e');
    }
  }

  Future<void> updateSchedules(AppConfig config, bool hasRecordedToday) async {
    final strings = AppStrings(config.language);

    try {
      await _configureLocalTimeZone();

      // 1. Fixed time capture notification
      if (config.mode == 'fixed_time_capture') {
        await _scheduleDailyNotification(
          id: _fixedTimeReminderId,
          title: strings.reminderFixedTimeTitle,
          body: strings.reminderFixedTimeBody,
          hour: config.captureHour,
          minute: config.captureMinute,
        );
      } else {
        await _notificationsPlugin.cancel(id: _fixedTimeReminderId);
      }

      // 2. Late day reminder (1 hour before day passes -> 23:00)
      if (!hasRecordedToday) {
        await _scheduleDailyNotification(
          id: _lateReminderId,
          title: strings.reminderLateTitle,
          body: strings.reminderLateBody,
          hour: 23,
          minute: 0,
        );
      } else {
        await _notificationsPlugin.cancel(id: _lateReminderId);
      }
    } catch (e) {
      debugPrint('Error scheduling notifications: $e');
    }
  }

  Future<void> _scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'body_tracker_reminders',
      'Body Tracker Reminders',
      channelDescription: 'Reminders to take daily body transformation photos',
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
