
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';

class Medication {
  String? id;
  String name;
  String mealType; // Keeping as String for Firestore compatibility, but logic should use Enum
  int slotNumber; // Physical slot number (1-24)
  String status; // 'pending', 'taken', 'skipped'
  DateTime? lastActionAt;
  int remainingBoxes; // 0-3 boxes per slot

  Medication({
    this.id,
    required this.name,
    required this.mealType,
    required this.slotNumber,
    this.status = 'pending',
    this.lastActionAt,
    this.remainingBoxes = AppConstants.defaultMedicationBoxes,
  });

  factory Medication.fromMap(Map<String, dynamic> data, String id) {
    DateTime? actionTime;
    if (data['lastActionAt'] != null) {
      actionTime = (data['lastActionAt'] as Timestamp).toDate();
    }

    return Medication(
      id: id,
      name: data['name'] ?? '',
      mealType: data['mealType'] ?? 'breakfast',
      slotNumber: data['slotNumber'] ?? 1,
      status: data['status'] ?? 'pending',
      lastActionAt: actionTime,
      remainingBoxes: data['remainingBoxes'] ?? AppConstants.defaultMedicationBoxes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'mealType': mealType,
      'slotNumber': slotNumber,
      'status': status,
      'remainingBoxes': remainingBoxes,
      'lastActionAt': lastActionAt != null ? Timestamp.fromDate(lastActionAt!) : null,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  bool needsRefill() => remainingBoxes <= AppConstants.medicationRefillThreshold;
}
