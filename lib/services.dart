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
  String status;
  DateTime? lastActionAt;

  Medication({
    this.id,
    required this.name,
    this.status = 'pending',
    this.lastActionAt,
  });

  factory Medication.fromMap(Map<String, dynamic> data, String id) {
    DateTime? actionTime;
    if (data['lastSkippedAt'] != null) {
      actionTime = DateTime.tryParse(data['lastSkippedAt']);
    } else if (data['lastTakenAt'] != null) {
      actionTime = DateTime.tryParse(data['lastTakenAt']);
    }

    return Medication(
      id: id,
      name: data['name'] ?? '',
      status: data['status'] ?? 'pending',
      lastActionAt: actionTime,
    );
  }
  Map<String, dynamic> toJson() => {'name': name, 'status': status};
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
      'lastUpdatedBy': 'KioskAdmin',
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

  // --- 5. Mark Skipped ---
  Future<void> markSkipped(
    String patientId,
    String alarmId,
    List<Medication> meds,
  ) async {
    final now = DateTime.now().toIso8601String();
    for (var med in meds) {
      if (med.id != null) {
        await _db
            .collection('patients')
            .doc(patientId)
            .collection('alarms')
            .doc(alarmId)
            .collection('medications')
            .doc(med.id)
            .update({'status': 'skipped', 'lastSkippedAt': now});
      }
    }
  }

  // --- 6. PDF Generation (UPDATED FOR 5 MEDS) ---
  Future<void> generateReport(
    List<Patient> patients,
    BuildContext context,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final now = DateTime.now();
    final String dateStr = DateFormat('yyyy-MM-dd').format(now);
    final String displayDate = DateFormat('MMMM d, yyyy').format(now);
    final String fileName = 'PillPal_Report_${dateStr}_to_$dateStr.pdf';

    pw.Widget _buildCell(
      String text, {
      bool isHeader = false,
      pw.Alignment alignment = pw.Alignment.centerLeft,
    }) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(4), // Reduced padding slightly
        alignment: alignment,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: isHeader ? 9 : 8, // Smaller font to fit 5 meds
            fontWeight: isHeader ? pw.FontWeight.bold : null,
            color: PdfColors.black,
          ),
        ),
      );
    }

    try {
      final pdf = pw.Document();

      final summaryHeaders = ['Slot', 'Name', 'Age', 'Gender', 'Alarms'];
      final summaryData = patients
          .map(
            (p) => [
              p.slotNumber,
              p.name,
              p.age.toString(),
              p.gender,
              p.alarms.length.toString(),
            ],
          )
          .toList();

      List<pw.Widget> detailedWidgets = [];

      for (var p in patients) {
        detailedWidgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 15, bottom: 5),
            child: pw.Text(
              "Slot ${p.slotNumber}: ${p.name} - Detailed Alarms",
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('6A1B9A'),
              ),
            ),
          ),
        );

        if (p.alarms.isEmpty) {
          detailedWidgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 10, bottom: 10),
              child: pw.Text(
                "No alarms set for this patient.",
                style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
              ),
            ),
          );
          continue;
        }

        final alarmTableRows = <pw.TableRow>[
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              _buildCell("Time", isHeader: true),
              _buildCell("Meds 1", isHeader: true),
              _buildCell("Meds 2", isHeader: true),
              _buildCell("Meds 3", isHeader: true),
              _buildCell("Meds 4", isHeader: true), // New Column
              _buildCell("Meds 5", isHeader: true), // New Column
              _buildCell("Last Status", isHeader: true),
            ],
          ),
        ];

        for (var alarm in p.alarms) {
          String m1 = "—", m2 = "—", m3 = "—", m4 = "—", m5 = "—";
          String lastStatus = "Pending";

          if (alarm.medications.isNotEmpty) {
            if (alarm.medications.length > 0) m1 = alarm.medications[0].name;
            if (alarm.medications.length > 1) m2 = alarm.medications[1].name;
            if (alarm.medications.length > 2) m3 = alarm.medications[2].name;
            if (alarm.medications.length > 3) m4 = alarm.medications[3].name;
            if (alarm.medications.length > 4) m5 = alarm.medications[4].name;

            // Check status of first med (representative of the alarm group)
            final firstMed = alarm.medications[0];
            if (firstMed.lastActionAt != null) {
              lastStatus = DateFormat(
                'MM/dd HH:mm',
              ).format(firstMed.lastActionAt!);
              if (firstMed.status == 'skipped') lastStatus += " (Skip)";
            }
          }

          alarmTableRows.add(
            pw.TableRow(
              children: [
                _buildCell(alarm.timeOfDay),
                _buildCell(m1),
                _buildCell(m2),
                _buildCell(m3),
                _buildCell(m4),
                _buildCell(m5),
                _buildCell(lastStatus),
              ],
            ),
          );
        }

        detailedWidgets.add(
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.2), // Time
              1: const pw.FlexColumnWidth(2), // Med 1
              2: const pw.FlexColumnWidth(2), // Med 2
              3: const pw.FlexColumnWidth(2), // Med 3
              4: const pw.FlexColumnWidth(2), // Med 4
              5: const pw.FlexColumnWidth(2), // Med 5
              6: const pw.FlexColumnWidth(2.5), // Status
            },
            children: alarmTableRows,
          ),
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PillPal Patient Report',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('6A1B9A'),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Report generated: $displayDate',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                "Patient Summary",
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Table.fromTextArray(
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey100,
                ),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headers: summaryHeaders,
                data: summaryData,
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.center,
                },
              ),
              pw.SizedBox(height: 25),
              pw.Text(
                "Detailed Alarm Logs",
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              ...detailedWidgets,
            ];
          },
        ),
      );

      String path;
      if (Platform.isAndroid) {
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          String newPath = directory.path.split("Android")[0];
          path = "$newPath/Download";
        } else {
          path = "/storage/emulated/0/Download";
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        path = directory.path;
      }

      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final file = File('$path/$fileName');
      await file.writeAsBytes(await pdf.save());

      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text("Report saved to $path"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () => OpenFilex.open(file.path),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text("Error generating PDF: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
