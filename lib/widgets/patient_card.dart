
import 'package:flutter/material.dart';
import '../models/patient_model.dart';
import '../models/medication_model.dart';

class PatientCard extends StatelessWidget {
  final Patient patient;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const PatientCard({
    super.key,
    required this.patient,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    int refillCount = patient.alarms.where((a) => a.medication.needsRefill()).length;
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: const Color(0xFFE3F2FD),
          child: Text(
            "P${patient.patientNumber}",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1565C0)
            )
          ),
        ),
        title: Text(patient.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${patient.age} yrs • ${patient.gender} • ${patient.alarms.length} Alarms"),
            Text(
              "Created by: ${patient.createdBy}",
              style: const TextStyle(fontSize: 11, color: Colors.grey)
            ),
            if (refillCount > 0)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(8)
                ),
                child: Text(
                  "⚠ $refillCount slot(s) need refill",
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.red,
                    fontWeight: FontWeight.bold
                  )
                ),
              ),
          ],
        ),
        onTap: onTap,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: onDelete
        ),
      ),
    );
  }
}
