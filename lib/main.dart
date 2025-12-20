import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';

import 'firebase_options.dart';
import 'services.dart';
import 'auth_screens.dart';
import 'dashboard.dart';
import 'welcome_screen.dart'; // Import the new screen

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const PillPalApp());
}

class PillPalApp extends StatelessWidget {
  const PillPalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => KioskState(),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'PillPal Kiosk',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF5F9FF),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0),
            primary: const Color(0xFF1565C0),
            secondary: const Color(0xFF64B5F6),
            background: const Color(0xFFF5F9FF),
          ),
          textTheme: GoogleFonts.poppinsTextTheme(),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.white,
          ),

          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
            ),
          ),
        ),
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasData) {
              return const DashboardScreen();
            }
            // Changed: Show WelcomeScreen first instead of direct AuthScreen
            return const WelcomeScreen(); 
          },
        ),
        routes: {
          '/kiosk': (_) => const KioskModeScreen(),
          '/alarm': (_) => const AlarmPopup(),
        },
      ),
    );
  }
}

// ================== KIOSK STATE ==================
class KioskState extends ChangeNotifier {
  final FirestoreService _db = FirestoreService();
  List<Patient> patients = [];

  // MQTT Config
  late MqttServerClient _client;
  String mqttStatus = "Disconnected";
  final String _topicCmd = 'pillpal/device001/cmd';

  // Alarm Logic
  DateTime now = DateTime.now();
  int _lastTriggeredMinute = -1;
  bool isAlarmActive = false;
  Patient? activePatient;
  AlarmModel? activeAlarm;

  // Audio Player
  final AudioPlayer _audioPlayer = AudioPlayer();

  KioskState() {
    _db.getPatients().listen((data) {
      patients = data;
      notifyListeners();
    });

    Timer.periodic(const Duration(seconds: 1), (_) {
      now = DateTime.now();
      _checkAlarms();
      notifyListeners();
    });

    _connectMqtt();

    // Preload audio
    _audioPlayer.setSource(AssetSource('alarm_sound.mp3'));
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
  }

  void _checkAlarms() {
    if (isAlarmActive || now.minute == _lastTriggeredMinute) return;

    for (var p in patients) {
      for (var a in p.alarms) {
        if (!a.isActive) continue;
        if (a.hour == now.hour && a.minute == now.minute) {
          _lastTriggeredMinute = now.minute;
          _trigger(p, a);
          return;
        }
      }
    }
  }

  void _trigger(Patient p, AlarmModel a) async {
    activePatient = p;
    activeAlarm = a;
    isAlarmActive = true;
    notifyListeners();

    try {
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.resume();
    } catch (e) {
      print("Error playing sound: $e");
    }

    navigatorKey.currentState?.pushNamed('/alarm');
  }

  void dispense(BuildContext context) async {
    // 1. Check if MQTT is connected
    if (mqttStatus != "Connected") {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Connection Error"),
          content: const Text(
            "Cannot dispense! The Kiosk is disconnected from the machine (ESP32).\n\nPlease check your internet connection.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return; // Stop here, don't close alarm yet
    }

    // 2. Proceed if connected
    if (activePatient != null && activeAlarm != null) {
      final msg = jsonEncode({
        'command': 'DISPENSE',
        'slot': activePatient!.slotNumber,
      });
      final builder = MqttClientPayloadBuilder();
      builder.addString(msg);
      _client.publishMessage(_topicCmd, MqttQos.atLeastOnce, builder.payload!);

      // --- ADDED: Mark as Taken in Database for Graph ---
      await _db.markTaken(
        activePatient!.id!,
        activeAlarm!.id!,
        activeAlarm!.medications,
      );
    }
    _close();
  }

  void skip() {
    if (activePatient != null && activeAlarm != null) {
      _db.markSkipped(
        activePatient!.id!,
        activeAlarm!.id!,
        activeAlarm!.medications,
      );
    }
    _close();
  }

  void _close() async {
    await _audioPlayer.stop();
    isAlarmActive = false;
    activePatient = null;
    activeAlarm = null;
    notifyListeners();
    navigatorKey.currentState?.pop();
  }

  Future<void> _connectMqtt() async {
    _client = MqttServerClient.withPort(
      'b18466311acb443e9753aae2266143d3.s1.eu.hivemq.cloud',
      'PillPal_Kiosk',
      8883,
    );
    _client.secure = true;
    _client.securityContext = SecurityContext.defaultContext;
    _client.logging(on: false);
    _client.keepAlivePeriod = 20;

    try {
      mqttStatus = "Connecting...";
      notifyListeners();
      await _client.connect('pillpal_device', 'SecurePass123!');
      mqttStatus = "Connected";
    } catch (e) {
      mqttStatus = "Error: $e";
      _client.disconnect();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

// ================== SCREEN: KIOSK MODE ==================
class KioskModeScreen extends StatelessWidget {
  const KioskModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<KioskState>(
      builder: (context, state, _) {
        bool isConnected = state.mqttStatus == "Connected";
        return Scaffold(
          backgroundColor: const Color(0xFF1565C0),
          body: Stack(
            children: [
              Positioned(
                top: -50,
                right: -50,
                child: CircleAvatar(
                  radius: 100,
                  backgroundColor: Colors.white.withOpacity(0.1),
                ),
              ),
              Positioned(
                bottom: -50,
                left: -50,
                child: CircleAvatar(
                  radius: 100,
                  backgroundColor: Colors.white.withOpacity(0.1),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isConnected
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isConnected
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.wifi,
                                  color: isConnected
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isConnected ? "ONLINE" : "OFFLINE",
                                  style: TextStyle(
                                    color: isConnected
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 800),
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: child,
                                );
                              },
                              child: Text(
                                DateFormat('HH:mm').format(state.now),
                                style: GoogleFonts.rubik(
                                  fontSize: 120,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                  letterSpacing: -2,
                                ),
                              ),
                            ),
                            Text(
                              DateFormat(
                                'EEEE, MMM dd, yyyy',
                              ).format(state.now),
                              style: const TextStyle(
                                fontSize: 24,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 60),
                            Container(
                              padding: const EdgeInsets.all(24),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 40,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.people_outline,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${state.patients.length}",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Text(
                                        "Active Patients",
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    ],
                                  ),
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
      },
    );
  }
}

// ================== SCREEN: ALARM POPUP (REDESIGNED) ==================
class AlarmPopup extends StatelessWidget {
  const AlarmPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<KioskState>(
      builder: (context, state, _) {
        final p = state.activePatient;
        final a = state.activeAlarm;
        if (p == null || a == null) return const Scaffold();

        return Scaffold(
          backgroundColor: const Color(0xFF1565C0),
          body: Center(
            child: SingleChildScrollView(
              child: Container(
                margin: const EdgeInsets.all(24),
                constraints: const BoxConstraints(maxWidth: 500),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(32),
                          topRight: Radius.circular(32),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.medication_liquid,
                            size: 60,
                            color: Color(0xFF1565C0),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "IT'S TIME FOR MEDICINE",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1565C0),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Text(
                            p.name,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.orange),
                            ),
                            child: Text(
                              "TRAY SLOT: ${p.slotNumber}",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          const Divider(),
                          const SizedBox(height: 16),

                          // --- UPDATED: DISPLAY MEDICATIONS ---
                          const Text(
                            "Medications Due:",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...a.medications.map(
                            (m) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      m.name,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // ------------------------------------
                          const SizedBox(height: 40),
                          // Buttons
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 60,
                                  child: OutlinedButton(
                                    onPressed: () => state.skip(),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Colors.grey,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const FittedBox(
                                      child: Text(
                                        "SKIP",
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: SizedBox(
                                  height: 60,
                                  child: ElevatedButton(
                                    // Pass context to show dialog
                                    onPressed: () => state.dispense(context),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1565C0),
                                      foregroundColor: Colors.white,
                                      elevation: 5,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const FittedBox(
                                      child: Text(
                                        "DISPENSE",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}