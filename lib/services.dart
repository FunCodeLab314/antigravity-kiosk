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
    if (data['lastActionAt'] != null) { // Unified timestamp field
      actionTime = (data['lastActionAt'] as Timestamp).toDate();
    } 
    // Fallback for older data
    else if (data['lastSkippedAt'] != null) {
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
  bool isActive;
  List<Medication> medications;

  AlarmModel({
    this.id,
    required this.timeOfDay,
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
  String slotNumber;
  String gender;
  List<AlarmModel> alarms;

  Patient({
    this.id,
    required this.name,
    required this.age,
    required this.slotNumber,
    required this.gender,
    required this.alarms,
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
      slotNumber: data['slotNumber']?.toString() ?? '0',
      gender: data['gender'] ?? 'N/A',
      alarms: alarms,
    );
  }
}

// ================== DATABASE SERVICE ==================

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- 1. Fetch All Data ---
  Stream<List<Patient>> getPatients() {
    return _db
        .collection('patients')
        .orderBy('slotNumber')
        .snapshots()
        .asyncMap((snapshot) async {
          List<Patient> patients = [];
          for (var doc in snapshot.docs) {
            final pData = doc.data();
            final alarmSnaps = await doc.reference.collection('alarms').get();
            List<AlarmModel> alarms = [];

            for (var aDoc in alarmSnaps.docs) {
              final aData = aDoc.data();
              final medSnaps = await aDoc.reference
                  .collection('medications')
                  .get();
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
    String slot,
    String gender,
    List<AlarmModel> alarms,
  ) async {
    DocumentReference pRef = await _db.collection('patients').add({
      'name': name,
      'age': age,
      'slotNumber': slot,
      'gender': gender,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    for (var alarm in alarms) {
      DocumentReference aRef = await pRef.collection('alarms').add({
        'timeOfDay': alarm.timeOfDay,
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
    String slot,
    String gender,
    List<AlarmModel> newAlarms,
  ) async {
    final pRef = _db.collection('patients').doc(patient.id);

    await pRef.update({
      'name': name,
      'age': age,
      'slotNumber': slot,
      'gender': gender,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Simple strategy: delete old alarms and re-add new ones
    final oldAlarms = await pRef.collection('alarms').get();
    for (var doc in oldAlarms.docs) {
      final meds = await doc.reference.collection('medications').get();
      for (var m in meds.docs) await m.reference.delete();
      await doc.reference.delete();
    }

    for (var alarm in newAlarms) {
      DocumentReference aRef = await pRef.collection('alarms').add({
        'timeOfDay': alarm.timeOfDay,
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

  // --- 4. Delete Data ---
  Future<void> deletePatient(String id) async {
    await _db.collection('patients').doc(id).delete();
  }

  // --- 5. Record Action (History + Status Update) ---
  Future<void> _recordAction(
    String patientId,
    String alarmId,
    List<Medication> meds,
    String status,
  ) async {
    final now = DateTime.now();
    
    // 1. Update Status in current Alarm (for Dashboard Graph)
    for (var med in meds) {
      if (med.id != null) {
        await _db
            .collection('patients')
            .doc(patientId)
            .collection('alarms')
            .doc(alarmId)
            .collection('medications')
            .doc(med.id)
            .update({
              'status': status,
              'lastActionAt': FieldValue.serverTimestamp(), // Use server timestamp
            });
      }
    }

    // 2. Add to History Collection (For Daily Reports)
    // Structure: patients/{id}/history/{auto_id}
    final historyRef = _db.collection('patients').doc(patientId).collection('history');
    
    for (var med in meds) {
      await historyRef.add({
        'medicationName': med.name,
        'status': status, // 'taken' or 'skipped'
        'actionTime': FieldValue.serverTimestamp(),
        'date': DateFormat('yyyy-MM-dd').format(now), // For easy filtering
      });
    }
  }

  Future<void> markSkipped(String pId, String aId, List<Medication> meds) async {
    await _recordAction(pId, aId, meds, 'skipped');
  }

  Future<void> markTaken(String pId, String aId, List<Medication> meds) async {
    await _recordAction(pId, aId, meds, 'taken');
  }

  // --- 6. PDF Generation (Updated for Date Range) ---
  Future<void> generateReport(
    List<Patient> patients,
    BuildContext context,
    DateTime selectedDate,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final String dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final String displayDate = DateFormat('MMMM d, yyyy').format(selectedDate);
    final String fileName = 'PillPal_Report_$dateStr.pdf';

    pw.Widget _buildCell(String text, {bool isHeader = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: isHeader ? 10 : 9,
            fontWeight: isHeader ? pw.FontWeight.bold : null,
          ),
        ),
      );
    }

    try {
      final pdf = pw.Document();
      
      // We need to fetch history data for each patient for the selected date
      List<List<String>> historyRows = [];

      for (var p in patients) {
        // Query History for this patient & date
        final historySnap = await _db
            .collection('patients')
            .doc(p.id)
            .collection('history')
            .where('date', isEqualTo: dateStr)
            .get();

        if (historySnap.docs.isNotEmpty) {
          for (var doc in historySnap.docs) {
            final data = doc.data();
            String time = "Unknown";
            if (data['actionTime'] != null) {
              time = DateFormat('HH:mm').format((data['actionTime'] as Timestamp).toDate());
            }
            
            historyRows.add([
              p.name,
              p.slotNumber,
              data['medicationName'] ?? '-',
              time,
              data['status'].toString().toUpperCase(),
            ]);
          }
        } else {
           // If no history, check if they had alarms pending (Optional)
           // For now, just show they had no actions recorded
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('PillPal Daily Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('1565C0'))),
                    pw.Text(displayDate, style: const pw.TextStyle(fontSize: 14)),
                  ]
                )
              ),
              pw.SizedBox(height: 20),
              
              if (historyRows.isEmpty)
                pw.Center(child: pw.Text("No medication activity recorded for this date."))
              else
                pw.Table.fromTextArray(
                  headers: ['Patient Name', 'Slot', 'Medication', 'Time', 'Status'],
                  data: historyRows,
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('1565C0')),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellAlignments: {
                    1: pw.Alignment.center,
                    3: pw.Alignment.center,
                    4: pw.Alignment.center,
                  }
                ),
                
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text("Total Patients Monitored: ${patients.length}", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            ];
          },
        ),
      );

      // Save File
      String path;
      if (Platform.isAndroid) {
        final directory = await getExternalStorageDirectory();
        path = directory?.path ?? "";
        if (path.contains("Android")) {
            path = path.split("Android")[0] + "Download";
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        path = directory.path;
      }
      
      final file = File('$path/$fileName');
      if (!await Directory(path).exists()) await Directory(path).create(recursive: true);
      await file.writeAsBytes(await pdf.save());

      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text("Report saved: $fileName"),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () => OpenFilex.open(file.path),
            ),
          ),
        );
      }
    } catch (e) {
      print("PDF Error: $e");
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }
}