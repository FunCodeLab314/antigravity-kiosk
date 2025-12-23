
import 'package:cloud_firestore/cloud_firestore.dart';
import 'alarm_model.dart';
import 'slot_mapping.dart';

class Patient {
  String? id;
  String name;
  int age;
  int patientNumber; // 1-8
  String gender;
  String createdBy; // Admin/Nurse name
  String createdByUid; // Admin/Nurse UID
  DateTime? createdAt;
  List<AlarmModel> alarms;

  Patient({
    this.id,
    required this.name,
    required this.age,
    required this.patientNumber,
    required this.gender,
    required this.createdBy,
    required this.createdByUid,
    this.createdAt,
    required this.alarms,
  });

  factory Patient.fromMap(
    Map<String, dynamic> data,
    String id,
    List<AlarmModel> alarms,
  ) {
    DateTime? created;
    if (data['createdAt'] != null) {
      created = (data['createdAt'] as Timestamp).toDate();
    }

    return Patient(
      id: id,
      name: data['name'] ?? 'Unknown',
      age: data['age'] ?? 0,
      patientNumber: data['patientNumber'] ?? 1,
      gender: data['gender'] ?? 'N/A',
      createdBy: data['createdBy'] ?? 'Unknown',
      createdByUid: data['createdByUid'] ?? '',
      createdAt: created,
      alarms: alarms,
    );
  }

  List<int> get assignedSlots => SlotMapping.getSlotsForPatient(patientNumber);
}
