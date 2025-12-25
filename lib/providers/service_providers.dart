
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/firestore_service.dart';
import '../services/mqtt_service.dart';
import '../services/notification_service.dart';
import '../services/audio_service.dart';
import '../services/alarm_service.dart';
import '../services/report_service.dart';
import '../services/ble_service.dart';

part 'service_providers.g.dart';

@Riverpod(keepAlive: true)
FirestoreService firestoreService(FirestoreServiceRef ref) {
  return FirestoreService();
}

@Riverpod(keepAlive: true)
ReportService reportService(ReportServiceRef ref) {
  return ReportService();
}

@Riverpod(keepAlive: true)
MqttService mqttService(MqttServiceRef ref) {
  final service = MqttService();
  ref.onDispose(service.dispose);
  return service;
}

@Riverpod(keepAlive: true)
NotificationService notificationService(NotificationServiceRef ref) {
  // NotificationService needs initialization, which we can do here or in main.
  // Ideally initialization is async, so we might want a FutureProvider for init state,
  // but the service instance itself can be sync.
  return NotificationService();
}

@Riverpod(keepAlive: true)
AudioService audioService(AudioServiceRef ref) {
  final service = AudioService();
  ref.onDispose(service.dispose);
  return service;
}

@Riverpod(keepAlive: true)
AlarmService alarmService(AlarmServiceRef ref) {
  final service = AlarmService();
  ref.onDispose(service.dispose);
  return service;
}

@Riverpod(keepAlive: true)
BleService bleService(BleServiceRef ref) {
  final service = BleService();
  ref.onDispose(service.dispose);
  return service;
}

/// Stream provider for BLE connection state
@Riverpod(keepAlive: true)
Stream<bool> bleConnectionState(BleConnectionStateRef ref) {
  final bleService = ref.watch(bleServiceProvider);
  return bleService.onConnectionStateChanged;
}

/// Simple provider to check if BLE is currently connected
@Riverpod(keepAlive: true)
bool bleIsConnected(BleIsConnectedRef ref) {
  final bleService = ref.watch(bleServiceProvider);
  return bleService.isConnected;
}
