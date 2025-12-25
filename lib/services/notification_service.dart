import 'dart:convert';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:logger/logger.dart';
import '../models/alarm_model.dart';
import '../models/patient_model.dart';
import '../utils/constants.dart';
import '../utils/enums.dart';
import 'dart:typed_data'; 

class NotificationService {
  final Logger _logger = Logger();
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Helper to check if app was launched by notification
  Future<String?> getLaunchPayload() async {
    final details = await _flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    if (details != null && details.didNotificationLaunchApp) {
      return details.notificationResponse?.payload;
    }
    return null;
  }

  Future<void> initialize(
      void Function(NotificationResponse)? onDidReceiveNotificationResponse) async {
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    await _requestPermissions();
    await _createNotificationChannel();
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      description: AppConstants.notificationChannelDesc,
      importance: Importance.max, // Critical for Heads-up
      playSound: true,
      sound: RawResourceAndroidNotificationSound('alarm_sound'), 
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final androidImplementation =
          _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
    }
  }

  Future<void> scheduleAllPatientAlarms(List<Patient> patients, String? currentAdminUid) async {
    await cancelAll();
    for (var p in patients) {
      bool isCreator = (currentAdminUid != null && p.createdByUid == currentAdminUid);
      for (var alarm in p.alarms) {
        if (alarm.isActive) {
          await scheduleDailyAlarm(patient: p, alarm: alarm, isCreator: isCreator);
        }
      }
    }
    _logger.i("Scheduled alarms for ${patients.length} patients");
  }

  Future<void> scheduleDailyAlarm({
    required Patient patient,
    required AlarmModel alarm,
    required bool isCreator,
  }) async {
    // Generate ID
    final int notificationId = (patient.id.hashCode ^ alarm.id.hashCode) & 0x7FFFFFFF;
    
    final title = "💊 Time for Medication!";
    final body = "${patient.name} - ${alarm.medication.name}";

    final androidDetails = AndroidNotificationDetails(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      channelDescription: AppConstants.notificationChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('alarm_sound'),
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
    );

    final details = NotificationDetails(android: androidDetails);

    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        title,
        body,
        _nextInstanceOfTime(alarm.hour, alarm.minute),
        details,
        androidScheduleMode: AndroidScheduleMode.alarmClock, // Critical for background
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: jsonEncode({
          'type': 'alarm',
          'patientId': patient.id,
          'alarmId': alarm.id,
          'isCreator': isCreator,
          'patientName': patient.name,
          'medicationName': alarm.medication.name,
        }),
      );
      _logger.i("✅ Notification scheduled for ${patient.name} at ${alarm.hour}:${alarm.minute.toString().padLeft(2, '0')}");
    } catch (e) {
      _logger.e("Error scheduling notification: $e");
    }
  }

  // Helper for Time calculation
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
  
  Future<void> cancelAll() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Schedule a one-off test notification after [delaySeconds].
  /// Useful to validate OS-level delivery when app is backgrounded/terminated.
  Future<void> showTestNotification({int delaySeconds = 5}) async {
    final int notificationId = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;
    final title = "🔔 PillPal Test Notification";
    final body = "This is a test notification scheduled in $delaySeconds seconds.";

    final androidDetails = AndroidNotificationDetails(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      channelDescription: AppConstants.notificationChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('alarm_sound'),
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );

    final details = NotificationDetails(android: androidDetails);

    final scheduled = tz.TZDateTime.now(tz.local).add(Duration(seconds: delaySeconds));

    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        title,
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: jsonEncode({'type': 'test'}),
      );
      _logger.i('✅ Test notification scheduled for ${scheduled.toLocal()}');
    } catch (e) {
      _logger.e('Error scheduling test notification: $e');
    }
  }

  /// Show an immediate test notification (only while app process is alive).
  Future<void> showImmediateTestNotification() async {
    final int notificationId = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;
    final title = "🔔 PillPal Immediate Test";
    final body = "Immediate test notification (foreground process).";

    final androidDetails = AndroidNotificationDetails(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      channelDescription: AppConstants.notificationChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('alarm_sound'),
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );

    try {
      await _flutterLocalNotificationsPlugin.show(
        notificationId,
        title,
        body,
        NotificationDetails(android: androidDetails),
        payload: jsonEncode({'type': 'immediate_test'}),
      );
      _logger.i('✅ Immediate test notification shown');
    } catch (e) {
      _logger.e('Error showing immediate test notification: $e');
    }
  }

  /// Show an immediate test notification with custom alarm data
  Future<void> showTestNotificationWithData({
    required String title,
    required String body,
    required String patientName,
    required String medicationName,
    required String alarmTime,
  }) async {
    final int notificationId = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;

    final androidDetails = AndroidNotificationDetails(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      channelDescription: AppConstants.notificationChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('alarm_sound'),
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
    );

    try {
      await _flutterLocalNotificationsPlugin.show(
        notificationId,
        title,
        body,
        NotificationDetails(android: androidDetails),
        payload: jsonEncode({
          'type': 'test',
          'patientName': patientName,
          'medicationName': medicationName,
          'alarmTime': alarmTime,
        }),
      );
      _logger.i('✅ Test notification shown: $patientName - $medicationName at $alarmTime');
    } catch (e) {
      _logger.e('Error showing test notification with data: $e');
    }
  }
}