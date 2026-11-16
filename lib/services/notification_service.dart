/* import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static final List<Map<String, String>> _messages = [
    {
      'title': 'Час для думок ✍️',
      'body': 'Запишіть свої ідеї та думки, поки вони не забулися!',
    },
    {
      'title': 'Збережіть момент 📸',
      'body': 'Записуйте спогади і прикріплюйте фото до своїх нотаток.',
    },
    {
      'title': 'Як проходить день? 🌤️',
      'body': 'Розкажіть у нотатках, що цікавого сьогодні трапилося.',
    },
    {
      'title': 'Маленька нотатка — велика ідея 💡',
      'body': 'Є щось важливе в голові? Занотуйте це прямо зараз.',
    },
    {
      'title': 'Підсумки дня 🌙',
      'body': 'Запишіть 3 хороші речі, які сталися з вами сьогодні.',
    },
  ];

  static Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  static Future<void> scheduleDailyReminders() async {
    await _notifications.cancelAll();

    await _scheduleAtTime(id: 1, hour: 13, minute: 30);

    await _scheduleAtTime(id: 2, hour: 20, minute: 00);
  }

  static Future<void> _scheduleAtTime({
    required int id,
    required int hour,
    required int minute,
  }) async {
    final random = Random();
    final message = _messages[random.nextInt(_messages.length)];

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
      'daily_notes_channel',
      'Щоденні нагадування',
      channelDescription: 'Нагадування зробити нотатку протягом дня',
      importance: Importance.high,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notifications.zonedSchedule(
      id,
      message['title'],
      message['body'],
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents:
          DateTimeComponents.time, // Повторювати щодня в цей час
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
*/
