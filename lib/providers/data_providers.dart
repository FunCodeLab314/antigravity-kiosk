
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/patient_model.dart';
import '../utils/enums.dart';
import 'service_providers.dart';

part 'data_providers.g.dart';

@riverpod
Stream<List<Patient>> patients(PatientsRef ref) {
  final service = ref.watch(firestoreServiceProvider);
  return service.getPatients();
}

@riverpod
List<Patient> patientsList(PatientsListRef ref) {
  // Useful for synchronous access in widgets that don't want to handle loading states explicitly
  // or just want the last value. 
  // Make sure to handle AsyncValue in UI effectively.
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
