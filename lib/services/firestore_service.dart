
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/patient_model.dart';
import '../models/alarm_model.dart';
import '../models/medication_model.dart';
import '../models/history_record.dart';

import '../models/notification_item.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- NOTIFICATION METHODS ---
  // Keeping this for generic notifications, though NotificationService handles local ones.
  // This is for Firestore 'notifications' collection (likely for admin panel sync etc).
  
  Future<void> saveNotification({
    required String title,
    required String body,
    required String type, // 'medication', 'refill', 'info'
    String? patientId,
    int? patientNumber,
    String? creatorUid,
  }) async {
    try {
      await _db.collection('notifications').add({
        'title': title,
        'body': body,
        'type': type,
        'patientId': patientId,
        'patientNumber': patientNumber,
        'creatorUid': creatorUid,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      print("Error saving notification: $e");
    }
  }

  // --- PATIENT METHODS ---

  Future<int?> getNextAvailablePatientNumber() async {
    final snapshot = await _db.collection('patients').get();
    Set<int> usedNumbers = snapshot.docs
        .map((doc) => doc.data()['patientNumber'] as int? ?? 0)
        .toSet();

    for (int i = 1; i <= 8; i++) {
      if (!usedNumbers.contains(i)) return i;
    }
    return null; // All 8 slots taken
  }

  Stream<List<Patient>> getPatients() {
    return _db
        .collection('patients')
        .orderBy('patientNumber')
        .snapshots()
        .asyncMap((snapshot) async {
          List<Patient> patients = [];
          for (var doc in snapshot.docs) {
            final pData = doc.data();
            final alarmSnaps = await doc.reference.collection('alarms').get();
            List<AlarmModel> alarms = [];

            for (var aDoc in alarmSnaps.docs) {
              final aData = aDoc.data();
              final medSnaps = await aDoc.reference.collection('medications').get();
              
              if (medSnaps.docs.isNotEmpty) {
                final medData = medSnaps.docs.first.data();
                final med = Medication.fromMap(medData, medSnaps.docs.first.id);
                alarms.add(AlarmModel.fromMap(aData, aDoc.id, med));
              }
            }
            patients.add(Patient.fromMap(pData, doc.id, alarms));
          }
          return patients;
        });
  }

  // --- HISTORY METHODS ---

  Future<void> _recordAction(
    Patient patient,
    AlarmModel alarm,
    String status,
  ) async {
    try {
      final now = DateTime.now();
      
      // Update medication status and reduce box count if taken
      final alarmRef = _db
          .collection('patients')
          .doc(patient.id)
          .collection('alarms')
          .doc(alarm.id);
      
      final medsSnapshot = await alarmRef.collection('medications').get();
      
      for (var medDoc in medsSnapshot.docs) {
        int currentBoxes = medDoc.data()['remainingBoxes'] ?? 3;
        
        Map<String, dynamic> updateData = {
          'status': status,
          'lastActionAt': FieldValue.serverTimestamp(),
        };

        // Reduce box count if taken
        if (status == 'taken' && currentBoxes > 0) {
          updateData['remainingBoxes'] = currentBoxes - 1;
        }

        await medDoc.reference.update(updateData);
      }

      // Add to history collection
      await _db.collection('history').add({
        'patientId': patient.id,
        'patientName': patient.name,
        'patientNumber': patient.patientNumber,
        'age': patient.age,
        'gender': patient.gender,
        'medicationName': alarm.medication.name,
        'mealType': alarm.mealType,
        'slotNumber': alarm.medication.slotNumber,
        'status': status,
        'actionTime': FieldValue.serverTimestamp(),
        'adminName': patient.createdBy,
        'adminUid': patient.createdByUid,
        'date': DateFormat('yyyy-MM-dd').format(now),
      });
      
    } catch (e) {
      print("❌ Error recording action: $e");
      rethrow;
    }
  }

  Future<void> markSkipped(Patient patient, AlarmModel alarm) async {
    await _recordAction(patient, alarm, 'skipped');
  }

  Future<void> markTaken(Patient patient, AlarmModel alarm) async {
    await _recordAction(patient, alarm, 'taken');
  }

  Future<List<HistoryRecord>> getHistory({
    DateTime? startDate,
    DateTime? endDate,
    String sortBy = 'actionTime',
  }) async {
    Query query = _db.collection('history');

    if (startDate != null) {
      String dateStr = DateFormat('yyyy-MM-dd').format(startDate);
      query = query.where('date', isGreaterThanOrEqualTo: dateStr);
    }

    if (endDate != null) {
      String dateStr = DateFormat('yyyy-MM-dd').format(endDate);
      query = query.where('date', isLessThanOrEqualTo: dateStr);
    }

    final snapshot = await query.get();
    List<HistoryRecord> records = snapshot.docs
        .map((doc) => HistoryRecord.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();

    // Sort in memory
    records.sort((a, b) {
      switch (sortBy) {
        case 'patientName':
          return a.patientName.compareTo(b.patientName);
        case 'patientNumber':
          return a.patientNumber.compareTo(b.patientNumber);
        case 'adminName':
          return a.adminName.compareTo(b.adminName);
        default:
          return b.actionTime.compareTo(a.actionTime);
      }
    });

    return records;
  }

  // --- NOTIFICATION CRUD ---

  Stream<List<NotificationItem>> getNotificationsStream() {
    return _db
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => NotificationItem.fromDocument(doc)).toList();
    });
  }

  Future<void> markNotificationAsRead(String id) async {
    await _db.collection('notifications').doc(id).update({'isRead': true});
  }

  Future<void> clearAllNotifications() async {
    final batch = _db.batch();
    final docs = await _db.collection('notifications').get();
    for (var doc in docs.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // --- CRUD METHODS ---

  Future<void> addPatient(
    String name,
    int age,
    int patientNumber,
    String gender,
    String adminName,
    String adminUid,
    List<AlarmModel> alarms,
  ) async {
    DocumentReference pRef = await _db.collection('patients').add({
      'name': name,
      'age': age,
      'patientNumber': patientNumber,
      'gender': gender,
      'createdBy': adminName,
      'createdByUid': adminUid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    for (var alarm in alarms) {
      DocumentReference aRef = await pRef.collection('alarms').add({
        'timeOfDay': alarm.timeOfDay,
        'mealType': alarm.mealType,
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await aRef.collection('medications').add(alarm.medication.toMap());
    }
  }

  Future<void> updatePatient(
    Patient patient,
    String name,
    int age,
    String gender,
    List<AlarmModel> newAlarms,
  ) async {
    final pRef = _db.collection('patients').doc(patient.id);

    await pRef.update({
      'name': name,
      'age': age,
      'gender': gender,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Delete old alarms
    final oldAlarms = await pRef.collection('alarms').get();
    for (var doc in oldAlarms.docs) {
      final meds = await doc.reference.collection('medications').get();
      for (var m in meds.docs) await m.reference.delete();
      await doc.reference.delete();
    }

    // Add new alarms
    for (var alarm in newAlarms) {
      DocumentReference aRef = await pRef.collection('alarms').add({
        'timeOfDay': alarm.timeOfDay,
        'mealType': alarm.mealType,
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await aRef.collection('medications').add(alarm.medication.toMap());
    }
  }

  Future<void> deletePatient(String id) async {
    await _db.collection('patients').doc(id).delete();
  }

  Future<void> refillSlot(String patientId, String alarmId, int boxCount) async {
    final medSnapshot = await _db
        .collection('patients')
        .doc(patientId)
        .collection('alarms')
        .doc(alarmId)
        .collection('medications')
        .get();

    for (var doc in medSnapshot.docs) {
      await doc.reference.update({
        'remainingBoxes': boxCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
