import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ================== DATA MODELS ==================

class Medication {
  String? id;
  String name;
  String status; // 'pending', 'taken', 'skipped'
  DateTime? lastActionAt;

  Medication({
    this.id,
    required this.name,
    this.status = 'pending',
    this.lastActionAt,
  });

  factory Medication.fromMap(Map<String, dynamic> data, String id) {
    DateTime? actionTime;
    if (data['lastActionAt'] != null) {
      actionTime = (data['lastActionAt'] as Timestamp).toDate();
    } else if (data['lastSkippedAt'] != null) {
      actionTime = DateTime.tryParse(data['lastSkippedAt'].toString());
    } else if (data['lastTakenAt'] != null) {
      actionTime = DateTime.tryParse(data['lastTakenAt'].toString());
    }

    return Medication(
      id: id,
      name: data['name'] ?? '',
      status: data['status'] ?? 'pending',
      lastActionAt: actionTime,
    );
  }
}

class AlarmModel {
  String? id;
  String timeOfDay;
  String type; // 'Breakfast', 'Lunch', 'Dinner'
  String? slotNumber; // SPECIFIC slot for this alarm (e.g., "1")
  bool isActive;
  List<Medication> medications;

  AlarmModel({
    this.id,
    required this.timeOfDay,
    this.type = 'Breakfast',
    this.slotNumber,
    this.isActive = true,
    required this.medications,
  });

  factory AlarmModel.fromMap(
    Map<String, dynamic> data,
    String id,
    List<Medication> meds,
  ) {
    return AlarmModel(
      id: id,
      timeOfDay: data['timeOfDay'] ?? "00:00",
      type: data['type'] ?? 'Breakfast',
      slotNumber: data['slotNumber'], // Load specific slot from DB
      isActive: data['isActive'] ?? true,
      medications: meds,
    );
  }

  int get hour => int.parse(timeOfDay.split(':')[0]);
  int get minute => int.parse(timeOfDay.split(':')[1]);
}

class Patient {
  String? id;
  String name;
  int age;
  int patientNumber; // 1 to 8
  String gender;
  String createdBy; // Admin Name
  List<AlarmModel> alarms;
  Map<String, int> slotInventory; 

  Patient({
    this.id,
    required this.name,
    required this.age,
    required this.patientNumber,
    required this.gender,
    required this.createdBy,
    required this.alarms,
    required this.slotInventory,
  });

  factory Patient.fromMap(
    Map<String, dynamic> data,
    String id,
    List<AlarmModel> alarms,
  ) {
    return Patient(
      id: id,
      name: data['name'] ?? 'Unknown',
      age: data['age'] ?? 0,
      patientNumber: data['patientNumber'] ?? 0,
      gender: data['gender'] ?? 'N/A',
      createdBy: data['createdBy'] ?? 'Unknown',
      slotInventory: Map<String, int>.from(data['slotInventory'] ?? {}),
      alarms: alarms,
    );
  }
  
  String get assignedSlots {
    List<String> slots = [];
    if (patientNumber <= 4) {
      slots = [patientNumber.toString(), (patientNumber + 4).toString(), (patientNumber + 8).toString()];
    } else {
      slots = [(patientNumber + 8).toString(), (patientNumber + 12).toString(), (patientNumber + 16).toString()];
    }
    return slots.join(', ');
  }
}

class HistoryRecord {
  final String patientName;
  final int patientNumber;
  final String medicationName;
  final String status;
  final String adminName;
  final DateTime actionTime;
  final String slot;
  final String mealType; // Breakfast/Lunch/Dinner

  HistoryRecord({
    required this.patientName,
    required this.patientNumber,
    required this.medicationName,
    required this.status,
    required this.adminName,
    required this.actionTime,
    required this.slot,
    required this.mealType,
  });
}

// ================== DATABASE SERVICE ==================

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Helper: Slot Calculation ---
  // Calculates specific slot based on Patient Number + Meal Type
  String _calculateSlot(int pNum, String type) {
    if (pNum <= 4) {
      if (type == 'Breakfast') return pNum.toString();
      if (type == 'Lunch') return (pNum + 4).toString();
      if (type == 'Dinner') return (pNum + 8).toString();
    } else {
      if (type == 'Breakfast') return (pNum + 8).toString();
      if (type == 'Lunch') return (pNum + 12).toString();
      if (type == 'Dinner') return (pNum + 16).toString();
    }
    return "0";
  }

  // --- 1. Fetch All Data ---
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
          final meds = medSnaps.docs
              .map((m) => Medication.fromMap(m.data(), m.id))
              .toList();
          alarms.add(AlarmModel.fromMap(aData, aDoc.id, meds));
        }
        patients.add(Patient.fromMap(pData, doc.id, alarms));
      }
      return patients;
    });
  }

  // --- 2. Add Data ---
  Future<void> addPatient(
    String name,
    int age,
    String gender,
    String adminName,
    List<AlarmModel> alarms,
  ) async {
    final snapshot = await _db.collection('patients').get();
    Set<int> usedNumbers = snapshot.docs.map((d) => d.data()['patientNumber'] as int).toSet();
    
    int nextNum = -1;
    for (int i = 1; i <= 8; i++) {
      if (!usedNumbers.contains(i)) {
        nextNum = i;
        break;
      }
    }

    if (nextNum == -1) {
      throw Exception("Max 8 patients reached. Delete a patient to add a new one.");
    }

    // Init Inventory
    List<String> mySlots = [];
    if (nextNum <= 4) {
      mySlots = [nextNum.toString(), (nextNum + 4).toString(), (nextNum + 8).toString()];
    } else {
      mySlots = [(nextNum + 8).toString(), (nextNum + 12).toString(), (nextNum + 16).toString()];
    }

    Map<String, int> initialInventory = {
      mySlots[0]: 3, mySlots[1]: 3, mySlots[2]: 3,
    };

    DocumentReference pRef = await _db.collection('patients').add({
      'name': name,
      'age': age,
      'patientNumber': nextNum,
      'gender': gender,
      'createdBy': adminName,
      'slotInventory': initialInventory,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    for (var alarm in alarms) {
      // CALC & SAVE SLOT NUMBER IN ALARM
      String specificSlot = _calculateSlot(nextNum, alarm.type);
      
      DocumentReference aRef = await pRef.collection('alarms').add({
        'timeOfDay': alarm.timeOfDay,
        'type': alarm.type,
        'slotNumber': specificSlot, // <--- SAVED TO DB
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      for (var med in alarm.medications) {
        await aRef.collection('medications').add({
          'name': med.name,
          'status': 'pending',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  // --- 3. Update Data ---
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

    final oldAlarms = await pRef.collection('alarms').get();
    for (var doc in oldAlarms.docs) {
      final meds = await doc.reference.collection('medications').get();
      for (var m in meds.docs) await m.reference.delete();
      await doc.reference.delete();
    }

    for (var alarm in newAlarms) {
      // CALC SLOT BASED ON EXISTING PATIENT NUMBER
      String specificSlot = _calculateSlot(patient.patientNumber, alarm.type);

      DocumentReference aRef = await pRef.collection('alarms').add({
        'timeOfDay': alarm.timeOfDay,
        'type': alarm.type,
        'slotNumber': specificSlot, // <--- SAVED TO DB
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      for (var med in alarm.medications) {
        await aRef.collection('medications').add({
          'name': med.name,
          'status': 'pending',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  Future<void> deletePatient(String id) async {
    // Delete subcollections first
    final pRef = _db.collection('patients').doc(id);
    final alarms = await pRef.collection('alarms').get();
    for(var a in alarms.docs) {
       final meds = await a.reference.collection('medications').get();
       for(var m in meds.docs) await m.reference.delete();
       await a.reference.delete();
    }
    final history = await pRef.collection('history').get();
    for(var h in history.docs) await h.reference.delete();
    
    await pRef.delete();
  }

  Future<void> refillSlot(String patientId, String slotNumber) async {
    await _db.collection('patients').doc(patientId).update({
      'slotInventory.$slotNumber': 3,
    });
  }

  // --- Action Recording ---
  Future<void> markTaken(String pId, String aId, List<Medication> meds) async {
    final pRef = _db.collection('patients').doc(pId);
    final pSnap = await pRef.get();
    final pData = pSnap.data();

    final aSnap = await pRef.collection('alarms').doc(aId).get();
    final aData = aSnap.data();
    String type = aData?['type'] ?? 'Breakfast';
    int pNum = pData?['patientNumber'] ?? 0;
    
    // Use stored slot if available, else calc
    String targetSlot = aData?['slotNumber'] ?? _calculateSlot(pNum, type);

    if (pData != null && pData['slotInventory'] != null) {
      Map<String, dynamic> inv = pData['slotInventory'];
      int current = inv[targetSlot] ?? 0;
      if (current > 0) {
        await pRef.update({'slotInventory.$targetSlot': current - 1});
      }
    }

    await _recordAction(pId, aId, meds, 'taken', targetSlot, type, pData?['createdBy'] ?? 'Unknown');
  }

  Future<void> markSkipped(String pId, String aId, List<Medication> meds) async {
     // Retrieve type/slot for history even if skipped
    final pRef = _db.collection('patients').doc(pId);
    final pSnap = await pRef.get();
    final aSnap = await pRef.collection('alarms').doc(aId).get();
    String type = aSnap.data()?['type'] ?? 'Breakfast';
    int pNum = pSnap.data()?['patientNumber'] ?? 0;
    String targetSlot = aSnap.data()?['slotNumber'] ?? _calculateSlot(pNum, type);

    await _recordAction(pId, aId, meds, 'skipped', targetSlot, type, 'N/A');
  }

  Future<void> _recordAction(
    String patientId,
    String alarmId,
    List<Medication> meds,
    String status,
    String slotUsed,
    String mealType,
    String adminName,
  ) async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final timeStr = DateFormat('HH:mm').format(now);

    final alarmRef = _db.collection('patients').doc(patientId).collection('alarms').doc(alarmId);
    final medsSnapshot = await alarmRef.collection('medications').get();
    
    for (var medDoc in medsSnapshot.docs) {
      if (meds.any((m) => m.name == medDoc['name'])) {
        await medDoc.reference.update({
          'status': status,
          'lastActionAt': FieldValue.serverTimestamp(),
        });
      }
    }

    final historyRef = _db.collection('patients').doc(patientId).collection('history');
    for (var med in meds) {
      await historyRef.add({
        'medicationName': med.name,
        'status': status,
        'actionTime': FieldValue.serverTimestamp(),
        'date': dateStr,
        'time': timeStr,
        'slot': slotUsed,
        'mealType': mealType, // <--- SAVED TO HISTORY
        'adminName': adminName, 
        'alarmId': alarmId,
      });
    }
  }

  Future<List<HistoryRecord>> getHistory(DateTime? date) async {
    List<HistoryRecord> records = [];
    String? targetDateStr = date != null ? DateFormat('yyyy-MM-dd').format(date) : null;

    final patientsSnap = await _db.collection('patients').get();
    
    for (var pDoc in patientsSnap.docs) {
      final pData = pDoc.data();
      Query historyQuery = pDoc.reference.collection('history');
      
      if (targetDateStr != null) {
        historyQuery = historyQuery.where('date', isEqualTo: targetDateStr);
      }

      final historySnap = await historyQuery.get();
      for (var hDoc in historySnap.docs) {
        final hData = hDoc.data() as Map<String, dynamic>;
        records.add(HistoryRecord(
          patientName: pData['name'],
          patientNumber: pData['patientNumber'],
          medicationName: hData['medicationName'] ?? '-',
          status: hData['status'] ?? 'UNKNOWN',
          adminName: hData['adminName'] ?? pData['createdBy'] ?? 'Unknown',
          slot: hData['slot'] ?? '-',
          mealType: hData['mealType'] ?? '-', // <--- RETRIEVED FROM HISTORY
          actionTime: (hData['actionTime'] as Timestamp).toDate(),
        ));
      }
    }
    return records;
  }

  Future<void> generatePdfReport(
    List<HistoryRecord> records,
    BuildContext context,
    DateTime date,
  ) async {
    final pdf = pw.Document();
    final String dateStr = DateFormat('MMMM d, yyyy').format(date);
    
    List<List<String>> tableData = records.map((r) => [
      r.patientName,
      r.patientNumber.toString(),
      r.medicationName,
      r.mealType, // <--- ADDED TO PDF
      r.slot,
      DateFormat('HH:mm').format(r.actionTime),
      r.status.toUpperCase(),
      r.adminName,
    ]).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Daily Medication Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('1565C0'))),
              pw.Text(dateStr),
            ])),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Patient', 'No.', 'Medication', 'Meal', 'Slot', 'Time', 'Status', 'Admin'],
              data: tableData,
              headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('1565C0')),
              headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
            ),
             pw.SizedBox(height: 20),
             pw.Text("Generated by PillPal System", style: const pw.TextStyle(color: PdfColors.grey)),
          ];
        },
      ),
    );

    String path;
    if (Platform.isAndroid) {
      final directory = await getExternalStorageDirectory();
      path = directory?.path ?? "";
      if (path.contains("Android")) path = path.split("Android")[0] + "Download";
    } else {
      final directory = await getApplicationDocumentsDirectory();
      path = directory.path;
    }
    final file = File('$path/PillPal_Report_${DateFormat('yyyyMMdd').format(date)}.pdf');
    if (!await Directory(path).exists()) await Directory(path).create(recursive: true);
    await file.writeAsBytes(await pdf.save());

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved to $path"), action: SnackBarAction(label: 'Open', onPressed: () => OpenFilex.open(file.path))));
    }
  }
}