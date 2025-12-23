
import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:logger/logger.dart';
import '../models/alarm_model.dart';
import '../models/patient_model.dart';
import '../utils/constants.dart';
import '../utils/enums.dart';

class NotificationService {
  final Logger _logger = Logger();
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Simple incremental ID for one-off notifications
  int _notificationIdCounter = 1000;

  Future<void> initialize(
      void Function(NotificationResponse)? onDidReceiveNotificationResponse) async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS/macOS settings can be added here
    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final androidImplementation =
          _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  // Generate a deterministic ID based on patient and alarm IDs
  int _generateAlarmId(String patientId, String alarmId) {
    // Combine strings and take hashcode. logical XOR to mix bits.
    return (patientId.hashCode ^ alarmId.hashCode) & 0x7FFFFFFF;
  }

  Future<void> scheduleDailyAlarm({
    required Patient patient,
    required AlarmModel alarm,
    required bool isCreator,
  }) async {
    final int notificationId = _generateAlarmId(patient.id!, alarm.id!);
    
    // Check if we should really schedule (optimization could be done here if we tracked state)
    // For now, let's just schedule it using the deterministic ID which will update if exists
    
    final title = isCreator
        ? "💊 Time for Medication!"
        : "💊 Patient Medication Alert";
    final body =
        "${patient.name} - ${alarm.medication.name} (${alarm.mealType.toUpperCase()})";

    final androidDetails = AndroidNotificationDetails(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      channelDescription: AppConstants.notificationChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    final details = NotificationDetails(android: androidDetails);

    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        title,
        body,
        _nextInstanceOfTime(alarm.hour, alarm.minute),
        details,
        androidAllowWhileIdle: true,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: jsonEncode({
          'type': 'alarm',
          'patientId': patient.id,
          'alarmId': alarm.id,
          'isCreator': isCreator,
        }),
      );
      _logger.d("Scheduled alarm $notificationId for ${patient.name} at ${alarm.timeOfDay}");
    } catch (e) {
      _logger.e("Error scheduling notification: $e");
    }
  }

  Future<void> cancelAlarm(String patientId, String alarmId) async {
    final int notificationId = _generateAlarmId(patientId, alarmId);
    await _flutterLocalNotificationsPlugin.cancel(notificationId);
    _logger.d("Cancelled alarm $notificationId");
  }

  Future<void> cancelAll() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
    _logger.i("Cancelled all notifications");
  }

  Future<void> showImmediateNotification({
    required String title,
    required String body,
    String? payload,
    NotificationType type = NotificationType.medication,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      channelDescription: AppConstants.notificationChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    final details = NotificationDetails(android: androidDetails);

    await _flutterLocalNotificationsPlugin.show(
      _notificationIdCounter++,
      title,
      body,
      details,
      payload: payload,
    );
  }
}
