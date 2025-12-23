
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/patient_model.dart';
import '../models/medication_model.dart';

class DashboardStats extends StatelessWidget {
  final List<Patient> patients;
  final String adminName;
  final Function() onViewRefill;

  const DashboardStats({
    super.key,
    required this.patients,
    required this.adminName,
    required this.onViewRefill,
  });

  @override
  Widget build(BuildContext context) {
    int totalPatients = patients.length;
    int skippedCount = 0;
    int takenCount = 0;
    int pendingCount = 0;
    int refillNeeded = 0;

    for (var p in patients) {
      for (var a in p.alarms) {
        if (a.medication.status == 'skipped') skippedCount++;
        else if (a.medication.status == 'taken') takenCount++;
        else pendingCount++;
        
        if (a.medication.needsRefill()) refillNeeded++;
      }
    }

    bool isEmpty = (skippedCount == 0 && takenCount == 0 && pendingCount == 0);

    List<PieChartSectionData> sections;
    if (isEmpty) {
      sections = [
        PieChartSectionData(
          value: 1,
          color: Colors.grey[300],
          radius: 30,
          showTitle: false
        )
      ];
    } else {
      sections = [
        PieChartSectionData(value: takenCount.toDouble(), color: Colors.green, radius: 30, showTitle: false),
        PieChartSectionData(value: skippedCount.toDouble(), color: Colors.orange, radius: 30, showTitle: false),
        PieChartSectionData(value: pendingCount.toDouble(), color: Colors.grey[300], radius: 25, showTitle: false),
      ];
    }

    return SingleChildScrollView(child: Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Overview",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF64B5F6)]
              ),
              borderRadius: BorderRadius.circular(20)
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Welcome back,",
                  style: TextStyle(color: Colors.white70, fontSize: 16)
                ),
                Text(
                  adminName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold
                  )
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12)
                      ),
                      child: const Icon(Icons.people, color: Colors.white)
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$totalPatients / 8",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold
                          )
                        ),
                        const Text(
                          "Patients",
                          style: TextStyle(color: Colors.white70)
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          if (refillNeeded > 0) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onViewRefill,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red[300]!)
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "$refillNeeded slot(s) need refill",
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold
                        )
                      ),
                    ),
                    const Text("VIEW", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 30),
          const Text(
            "Medication Status",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: isEmpty ? 0 : 2,
                      centerSpaceRadius: 40,
                      sections: sections,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendItem(Colors.green, "Taken ($takenCount)"),
                    const SizedBox(height: 10),
                    _buildLegendItem(Colors.orange, "Skipped ($skippedCount)"),
                    const SizedBox(height: 10),
                    _buildLegendItem(Colors.grey[300]!, "Pending ($pendingCount)"),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        CircleAvatar(radius: 6, backgroundColor: color),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}
