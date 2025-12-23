
class AppConstants {
  // MQTT
  static const String mqttBroker = 'b18466311acb443e9753aae2266143d3.s1.eu.hivemq.cloud';
  static const int mqttPort = 8883;
  static const String mqttClientIdentifier = 'PillPal_Kiosk';
  static const String mqttUsername = 'pillpal_device';
  static const String mqttPassword = 'SecurePass123!';
  static const String mqttTopicCmd = 'pillpal/device001/cmd';
  static const int mqttKeepAlive = 20;

  // Notification Channels
  static const String notificationChannelId = 'alarm_channel';
  static const String notificationChannelName = 'Medication Alarm';
  static const String notificationChannelDesc = 'Medication reminders';

  // Limits
  static const int maxPatients = 8;
  static const int medicationRefillThreshold = 1;
  static const int defaultMedicationBoxes = 3;

  // Assets
  static const String alarmSoundPath = 'alarm_sound.mp3';
}
