
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/patient_model.dart';
import '../providers/service_providers.dart';

class RefillPage extends ConsumerWidget {
  final List<Patient> patients;

  const RefillPage({super.key, required this.patients});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Collect all medications that need refill
    List<Map<String, dynamic>> refillItems = [];
    
    for (var p in patients) {
      for (var a in p.alarms) {
        if (a.medication.remainingBoxes <= 1) {
          refillItems.add({
            'patient': p,
            'alarm': a,
            'medication': a.medication,
          });
        }
      }
    }

    if (refillItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text("All stocks are sufficient!", style: TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        )
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: refillItems.length,
      itemBuilder: (context, index) {
        final item = refillItems[index];
        final p = item['patient'];
        final a = item['alarm'];
        final m = item['medication'];
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12)
                  ),
                  child: const Icon(Icons.medication, color: Colors.red),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Slot ${m.slotNumber}: ${m.name}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text("Patient: ${p.name} (P${p.patientNumber})"),
                      const SizedBox(height: 4),
                      Text(
                        "${m.remainingBoxes} boxes remaining",
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    _showRefillDialog(context, ref, p, a, m.remainingBoxes);
                  },
                  child: const Text("Refill"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRefillDialog(BuildContext context, WidgetRef ref, Patient p, dynamic a, int currentBoxes) {
    int boxes = 3;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Refill Slot"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("How many boxes are you adding?"),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle),
                    onPressed: boxes > 1 ? () => setState(() => boxes--) : null,
                  ),
                  Text("$boxes", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle),
                    onPressed: boxes < 5 ? () => setState(() => boxes++) : null,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(firestoreServiceProvider).refillSlot(p.id!, a.id!, boxes);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Refilled successfully"), backgroundColor: Colors.green)
                );
              },
              child: const Text("Confirm Refill"),
            ),
          ],
        ),
      ),
    );
  }
}
