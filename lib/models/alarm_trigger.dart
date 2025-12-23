
import '../models/patient_model.dart';
import '../models/alarm_model.dart';

class AlarmTrigger {
  final Patient patient;
  final AlarmModel alarm;
  final bool isCreator;
  final DateTime timestamp;

  AlarmTrigger({
    required this.patient,
    required this.alarm,
    required this.isCreator,
    required this.timestamp,
  });
}
