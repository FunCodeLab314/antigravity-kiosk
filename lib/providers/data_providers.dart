import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Required for User type
import '../models/patient_model.dart';
import '../services/mqtt_service.dart';
import '../utils/enums.dart';
import 'service_providers.dart';
import 'auth_providers.dart'; // Required for authStateProvider

part 'data_providers.g.dart';

@riverpod
Stream<List<Patient>> patients(PatientsRef ref) {
  final service = ref.watch(firestoreServiceProvider);
  return service.getPatients();
}

@riverpod
List<Patient> patientsList(PatientsListRef ref) {
  // Useful for synchronous access in widgets that don't want to handle loading states explicitly
  return ref.watch(patientsProvider).value ?? [];
}

@riverpod
Stream<MqttConnectionStatus> mqttStatus(MqttStatusRef ref) {
  final service = ref.watch(mqttServiceProvider);
  return service.statusStream;
}

@riverpod
bool mqttIsConnected(MqttIsConnectedRef ref) {
  final status = ref.watch(mqttStatusProvider).value;
  return status == MqttConnectionStatus.connected;
}

/// Synchronization provider to bridge Firestore data, Auth, AlarmService, and Notifications
@riverpod
void patientAlarmSync(PatientAlarmSyncRef ref) {
  final alarmService = ref.watch(alarmServiceProvider);
  final notifService = ref.watch(notificationServiceProvider); // <--- Added Notification Service
  final patientsAsync = ref.watch(patientsProvider);
  
  // 1. WATCH THE AUTH STATE
  final authState = ref.watch(authStateProvider);

  String? currentUid;

  // 2. Update the User ID in the service whenever it changes
  authState.whenData((user) {
    currentUid = user?.uid;
    alarmService.setCurrentUser(user?.uid);
  });

  // 3. Update the Patients List & Schedule Notifications whenever data changes
  patientsAsync.when(
    data: (patients) {
      // A. Update the internal AlarmService (for the in-app popup)
      alarmService.updatePatients(patients);
      alarmService.startMonitoring();

      // B. Schedule the OS-level notifications (for background alerts/sound)
      // This ensures alarms work even if the app is closed or screen is off.
      notifService.scheduleAllPatientAlarms(patients, currentUid);
    },
    loading: () {
      // Optional: Handle loading state if necessary
    },
    error: (err, stack) {
      print("Error loading patients for alarms: $err");
    },
  );
}