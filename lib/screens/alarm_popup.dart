import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/alarm_queue_provider.dart';
import '../providers/service_providers.dart';

class AlarmPopup extends ConsumerWidget {
  const AlarmPopup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(alarmQueueProvider);
    
    final trigger = state.activeTrigger;
    
    // FIX: When trigger becomes null (after skip/dispense), don't show a loader.
    // Show a blank blue screen while the AppLifecycleManager pops this screen.
    if (trigger == null) {
      return const Scaffold(backgroundColor: Color(0xFF1565C0)); 
    }

    final p = trigger.patient;
    final a = trigger.alarm;
    final bleConnected = ref.watch(bleIsConnectedProvider);

    IconData mealIcon = a.mealType == 'breakfast'
        ? Icons.wb_sunny
        : a.mealType == 'lunch'
            ? Icons.wb_cloudy
            : Icons.nightlight;

    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(32)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                    color: Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32))),
                child: Column(children: [
                  const Icon(Icons.medication_liquid,
                      size: 60, color: Color(0xFF1565C0)),
                  const SizedBox(height: 16),
                  Text("IT'S TIME FOR MEDICINE",
                      style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1565C0))),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF1565C0),
                        child: Text("P${p.patientNumber}",
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Text(p.name,
                          style: const TextStyle(
                              fontSize: 32, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.orange)),
                        child: Row(
                          children: [
                            Icon(mealIcon,
                                size: 16, color: Colors.deepOrange),
                            const SizedBox(width: 6),
                            Text(a.mealType.toUpperCase(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepOrange)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.purple)),
                          child: Text("SLOT ${a.medication.slotNumber}",
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple))),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text("Medication:",
                      style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 12),
                      Text(a.medication.name,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w500))
                    ],
                  ),
                  const SizedBox(height: 40),
                  Row(children: [
                    Expanded(
                        child: SizedBox(
                            height: 60,
                            child: OutlinedButton(
                                onPressed: () async {
                                  await ref.read(alarmQueueProvider.notifier).skip();
                                  // Close popup - AppLifecycleManager will handle navigation to home
                                },
                                child: const Text("SKIP")))),
                    const SizedBox(width: 20),
                    Expanded(
                        child: SizedBox(
                            height: 60,
                            child: ElevatedButton(
                                onPressed: bleConnected
                                    ? () async {
                                        await ref
                                            .read(alarmQueueProvider.notifier)
                                            .dispense(slotNumber: a.medication.slotNumber);
                                        // Close popup - AppLifecycleManager will handle navigation to home
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: bleConnected
                                        ? const Color(0xFF1565C0)
                                        : Colors.grey,
                                    foregroundColor: Colors.white),
                                child: Text(bleConnected
                                    ? "DISPENSE"
                                    : "OFFLINE")))),
                  ]),
                  if (!bleConnected)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text("Connecting to ESP Dispenser...",
                          style: TextStyle(color: Colors.red, fontSize: 12)),
                    )
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}