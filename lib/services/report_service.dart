
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:intl/intl.dart';
import '../models/history_record.dart';

class ReportService {
  Future<void> generateHistoryReport(
    BuildContext context,
    List<HistoryRecord> records,
    String sortBy,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final String fileName = 'PillPal_History_${DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now())}.pdf';

    try {
      final pdf = pw.Document();
      
      List<List<String>> tableRows = records.map((r) {
        return [
          'P${r.patientNumber}',
          r.patientName,
          '${r.age}',
          r.gender,
          r.medicationName,
          r.mealType.toUpperCase(),
          'Slot ${r.slotNumber}',
          DateFormat('MMM dd, HH:mm').format(r.actionTime),
          r.status.toUpperCase(),
          r.adminName,
        ];
      }).toList();

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
                      'PillPal Medication History',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('1565C0')
                      )
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Sorted by: ${sortBy.replaceAll('_', ' ').toUpperCase()}',
                      style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)
                    ),
                    pw.Text(
                      'Generated: ${DateFormat('MMMM dd, yyyy HH:mm').format(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)
                    ),
                  ]
                )
              ),
              pw.SizedBox(height: 20),
              
              if (tableRows.isEmpty)
                pw.Center(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(40),
                    child: pw.Text(
                      "No records found.",
                      style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey600)
                    )
                  )
                )
              else
                pw.Table.fromTextArray(
                  headers: ['P#', 'Patient', 'Age', 'Gender', 'Medication', 'Meal', 'Slot', 'Time', 'Status', 'Admin'],
                  data: tableRows,
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    fontSize: 9
                  ),
                  headerDecoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('1565C0')
                  ),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellStyle: const pw.TextStyle(fontSize: 8),
                ),
                
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.Text(
                "Total Records: ${records.length}",
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)
              ),
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
      if (!await Directory(path).exists()) {
        await Directory(path).create(recursive: true);
      }
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
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.red
          )
        );
      }
    }
  }
}
