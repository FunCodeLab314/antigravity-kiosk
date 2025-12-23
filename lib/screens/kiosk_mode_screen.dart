
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/data_providers.dart';
import '../widgets/clock_widget.dart';

class KioskModeScreen extends ConsumerWidget {
  const KioskModeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mqttConnected = ref.watch(mqttIsConnectedProvider);
    final patientCount = ref.watch(patientsListProvider).length;

    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: Stack(
        children: [
          // Background Decorations
          Positioned(
              top: -50,
              right: -50,
              child: CircleAvatar(
                  radius: 100,
                  backgroundColor: Colors.white.withOpacity(0.1))),
          Positioned(
              bottom: -50,
              left: -50,
              child: CircleAvatar(
                  radius: 100,
                  backgroundColor: Colors.white.withOpacity(0.1))),
          
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white),
                          onPressed: () => Navigator.pop(context)),
                      const Spacer(),
                      // MQTT Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: mqttConnected
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: mqttConnected
                                  ? Colors.greenAccent
                                  : Colors.redAccent),
                        ),
                        child: Row(children: [
                          Icon(Icons.wifi,
                              color: mqttConnected
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              size: 16),
                          const SizedBox(width: 8),
                          Text(
                              mqttConnected
                                  ? "ONLINE"
                                  : "OFFLINE",
                              style: TextStyle(
                                  color: mqttConnected
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ]),
                      ),
                    ],
                  ),
                ),
                
                // Main Content
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const ClockWidget(), // Optimized Clock
                        const SizedBox(height: 60),
                        
                        // Active Patients Count
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white24)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.people_outline,
                                  color: Colors.white, size: 30),
                              const SizedBox(width: 16),
                              Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text("$patientCount / 8",
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold)),
                                    const Text("Active Patients",
                                        style: TextStyle(
                                            color: Colors.white70)),
                                  ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
