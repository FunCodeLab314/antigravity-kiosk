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
          radius: 40,
          showTitle: false
        )
      ];
    } else {
      sections = [
        PieChartSectionData(
          value: takenCount.toDouble(), 
          color: const Color(0xFF4CAF50), 
          radius: 40, 
          showTitle: false
        ),
        PieChartSectionData(
          value: skippedCount.toDouble(), 
          color: const Color(0xFFFF9800), 
          radius: 40, 
          showTitle: false
        ),
        PieChartSectionData(
          value: pendingCount.toDouble(), 
          color: Colors.grey[300], 
          radius: 35, 
          showTitle: false
        ),
      ];
    }

    return Column(
      children: [
        // Refill Alert (if needed)
        if (refillNeeded > 0) ...[
          GestureDetector(
            onTap: onViewRefill,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red[50]!, Colors.red[100]!],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red[300]!, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded, 
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Refill Alert",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "$refillNeeded slot(s) need refill",
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "VIEW",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        
        // Chart Section
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Chart
              SizedBox(
                height: 180,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: isEmpty ? 0 : 2,
                    centerSpaceRadius: 45,
                    sections: sections,
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Horizontal Legend Below Chart
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCompactLegendItem(
                    const Color(0xFF4CAF50), 
                    "Taken", 
                    takenCount
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey[300],
                  ),
                  _buildCompactLegendItem(
                    const Color(0xFFFF9800), 
                    "Skipped", 
                    skippedCount
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey[300],
                  ),
                  _buildCompactLegendItem(
                    Colors.grey[400]!, 
                    "Pending", 
                    pendingCount
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Quick Stats Cards
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.medical_services_rounded,
                title: "Total Meds",
                value: "${takenCount + skippedCount + pendingCount}",
                color: const Color(0xFF1565C0),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.inventory_2_rounded,
                title: "Active Slots",
                value: "${patients.fold<int>(0, (sum, p) => sum + p.alarms.length)}",
                color: const Color(0xFF7B1FA2),
                gradient: const LinearGradient(
                  colors: [Color(0xFF7B1FA2), Color(0xFFBA68C8)],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactLegendItem(Color color, String label, int count) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required Gradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}