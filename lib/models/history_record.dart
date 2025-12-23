
import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryRecord {
  String? id;
  String patientId;
  String patientName;
  int patientNumber;
  int age;
  String gender;
  String medicationName;
  String mealType;
  int slotNumber;
  String status; // 'taken' or 'skipped'
  DateTime actionTime;
  String adminName;
  String adminUid;

  HistoryRecord({
    this.id,
    required this.patientId,
    required this.patientName,
    required this.patientNumber,
    required this.age,
    required this.gender,
    required this.medicationName,
    required this.mealType,
    required this.slotNumber,
    required this.status,
    required this.actionTime,
    required this.adminName,
    required this.adminUid,
  });

  factory HistoryRecord.fromMap(Map<String, dynamic> data, String id) {
    return HistoryRecord(
      id: id,
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'] ?? '',
      patientNumber: data['patientNumber'] ?? 0,
      age: data['age'] ?? 0,
      gender: data['gender'] ?? '',
      medicationName: data['medicationName'] ?? '',
      mealType: data['mealType'] ?? '',
      slotNumber: data['slotNumber'] ?? 0,
      status: data['status'] ?? '',
      actionTime: (data['actionTime'] as Timestamp).toDate(),
      adminName: data['adminName'] ?? '',
      adminUid: data['adminUid'] ?? '',
    );
  }
}
