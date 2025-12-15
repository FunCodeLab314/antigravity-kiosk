import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 🚀 CHANGED: Locked to Portrait mode
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(const PillPalApp());
  });
}

class PillPalApp extends StatelessWidget {
  const PillPalApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 🚀 CHANGED: Blue and White Typography
    final baseTextStyle = GoogleFonts.montserrat(
      textStyle: const TextStyle(color: Color(0xFF1565C0)), // Dark Blue
    );

    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'PillPal',
        theme: ThemeData(
          // 🚀 CHANGED: White Background, Blue Primary
          scaffoldBackgroundColor: Colors.white,
          primaryColor: const Color(0xFF2196F3), // Blue
          colorScheme: ColorScheme.fromSwatch().copyWith(
            primary: const Color(0xFF2196F3),
            secondary: const Color(0xFF64B5F6), // Light Blue
            surface: Colors.white,
          ),
          textTheme: TextTheme(
            bodyLarge: baseTextStyle.copyWith(fontSize: 18),
            headlineLarge: baseTextStyle.copyWith(
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
            headlineMedium: baseTextStyle.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
            labelLarge: GoogleFonts.montserrat(
              textStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0), // Dark Blue Button
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              elevation: 4,
            ),
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (_) => const TitleScreen(),
          '/refill': (_) => const RefillPage(),
          '/instructions': (_) => const AppInstructionsPage(),
          '/clock': (_) => const ClockScreen(),
          '/alarm': (_) => const AlarmScreen(),
        },
      ),
    );
  }
}

// -------------------- Models (Same as before) --------------------
class Medication {
  String name;
  Medication({required this.name});
  factory Medication.fromFirestore(Map<String, dynamic> data) {
    return Medication(name: data['name'] ?? 'Unknown Med');
  }
}

class AlarmModel {
  String id;
  int hour;
  int minute;
  bool isActive;
  List<Medication> meds;

  AlarmModel({
    required this.id,
    required this.hour,
    required this.minute,
    required this.isActive,
    required this.meds,
  });

  factory AlarmModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
    List<Medication> meds,
  ) {
    final timeString = data['timeOfDay'] as String? ?? "00:00";
    final parts = timeString.split(':');
    final h = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    return AlarmModel(
      id: id,
      hour: h,
      minute: m,
      isActive: data['isActive'] ?? true,
      meds: meds,
    );
  }
}

class Patient {
  String id;
  String name;
  int age;
  int slotNumber;
  List<AlarmModel> alarms;

  Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.slotNumber,
    required this.alarms,
  });

  factory Patient.fromFirestore(
    String id,
    Map<String, dynamic> data,
    List<AlarmModel> alarms,
  ) {
    int slot = 0;
    if (data['slotNumber'] is int) {
      slot = data['slotNumber'];
    } else if (data['slotNumber'] is String) {
      slot = int.tryParse(data['slotNumber']) ?? 0;
    }

    return Patient(
      id: id,
      name: data['name'] ?? 'Unknown',
      age: data['age'] ?? 0,
      slotNumber: slot,
      alarms: alarms,
    );
  }
}

// -------------------- App State (Same Logic, Just Logic) --------------------
class AppState extends ChangeNotifier {
  List<Patient> patients = [];
  bool isAlarmActive = false;
  String mqttStatus = 'disconnected';
  DateTime now = DateTime.now();
  Patient? activePatient;
  AlarmModel? activeAlarm;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final String _host = 'b18466311acb443e9753aae2266143d3.s1.eu.hivemq.cloud';
  final int _port = 8883;
  final String _username = 'pillpal_device';
  final String _password = 'SecurePass123!';
  final String _clientId = 'PillPal_Flutter_Kiosk';
  final String _topicCmd = 'pillpal/device001/cmd';
  final String _topicStatus = 'pillpal/device001/status';

  late MqttServerClient _client;
  Timer? _clockTimer;
  StreamSubscription? _patientSubscription;

  AppState() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      now = DateTime.now();
      notifyListeners();
      _checkAlarms();
    });

    Future.microtask(() {
      _connectMqtt();
      _listenToFirestore();
    });
  }

  int get patientCount => patients.length;

  void _listenToFirestore() {
    print("Starting Firestore Listener...");
    _patientSubscription = _firestore.collection('patients').snapshots().listen(
      (snapshot) async {
        List<Patient> newPatients = [];
        for (var doc in snapshot.docs) {
          final pData = doc.data();
          final alarmSnapshot = await doc.reference.collection('alarms').get();
          List<AlarmModel> pAlarms = [];

          for (var alarmDoc in alarmSnapshot.docs) {
            final aData = alarmDoc.data();
            final medSnapshot = await alarmDoc.reference
                .collection('medications')
                .get();
            List<Medication> pMeds = medSnapshot.docs
                .map((mDoc) => Medication.fromFirestore(mDoc.data()))
                .toList();
            pAlarms.add(AlarmModel.fromFirestore(alarmDoc.id, aData, pMeds));
          }
          newPatients.add(Patient.fromFirestore(doc.id, pData, pAlarms));
        }
        patients = newPatients;
        notifyListeners();
      },
      onError: (e) => print("Firestore Error: $e"),
    );
  }

  Future<void> _connectMqtt() async {
    _client = MqttServerClient.withPort(_host, _clientId, _port);
    _client.logging(on: false);
    _client.keepAlivePeriod = 20;
    _client.secure = true;
    _client.securityContext = SecurityContext.defaultContext;
    _client.onDisconnected = _onDisconnected;
    _client.onConnected = _onConnected;

    final connMess = MqttConnectMessage()
        .withClientIdentifier(_clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    _client.connectionMessage = connMess;

    try {
      mqttStatus = 'connecting...';
      notifyListeners();
      await _client.connect(_username, _password);
    } catch (e) {
      print('MQTT Error: $e');
      _client.disconnect();
    }
  }

  void _onConnected() {
    mqttStatus = 'connected';
    _client.subscribe(_topicStatus, MqttQos.atLeastOnce);
    notifyListeners();
  }

  void _onDisconnected() {
    mqttStatus = 'disconnected';
    notifyListeners();
  }

  void _checkAlarms() {
    if (isAlarmActive) return;
    for (final p in patients) {
      for (final a in p.alarms) {
        if (!a.isActive) continue;
        if (a.hour == now.hour && a.minute == now.minute && now.second == 0) {
          _triggerAlarm(p, a);
          return;
        }
      }
    }
  }

  void _triggerAlarm(Patient p, AlarmModel a) {
    activePatient = p;
    activeAlarm = a;
    isAlarmActive = true;
    notifyListeners();
    navigatorKey.currentState?.pushNamed('/alarm');
  }

  void dispenseMedicine() {
    if (activePatient == null || activeAlarm == null) return;
    final msg = jsonEncode({
      'command': 'DISPENSE',
      'slot': activePatient!.slotNumber,
    });
    final builder = MqttClientPayloadBuilder();
    builder.addString(msg);
    _client.publishMessage(_topicCmd, MqttQos.atLeastOnce, builder.payload!);

    activeAlarm!.isActive = false;
    isAlarmActive = false;
    activePatient = null;
    activeAlarm = null;
    notifyListeners();
    navigatorKey.currentState?.popUntil(
      (route) => route.settings.name == '/clock',
    );
  }

  void stopAlarm() {
    final msg = jsonEncode({'command': 'STOP'});
    final builder = MqttClientPayloadBuilder();
    builder.addString(msg);
    _client.publishMessage(_topicCmd, MqttQos.atLeastOnce, builder.payload!);

    isAlarmActive = false;
    activePatient = null;
    activeAlarm = null;
    notifyListeners();
    navigatorKey.currentState?.popUntil(
      (route) => route.settings.name == '/clock',
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _patientSubscription?.cancel();
    super.dispose();
  }
}

// -------------------- UI Screens (Updated for Blue/White Portrait) --------------------

class TitleScreen extends StatelessWidget {
  const TitleScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // 🚀 CHANGED: Layout adjusted for Portrait
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Icon(
                Icons.medical_services_rounded,
                size: 100,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                'PillPal',
                textAlign: TextAlign.center,
                style: textTheme.headlineLarge?.copyWith(
                  fontSize: 60,
                  color: const Color(0xFF1565C0), // Dark Blue
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'SMART MEDICINE DISPENSER',
                textAlign: TextAlign.center,
                style: textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFF64B5F6), // Lighter Blue
                  fontSize: 20,
                  letterSpacing: 2.0,
                ),
              ),
              const Spacer(flex: 3),
              // 🚀 CHANGED: Buttons stacked vertically for portrait
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/refill'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1565C0),
                  side: const BorderSide(color: Color(0xFF1565C0), width: 2),
                ),
                child: const Text('REFILL INSTRUCTIONS'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/instructions'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1565C0),
                  side: const BorderSide(color: Color(0xFF1565C0), width: 2),
                ),
                child: const Text('APP INSTRUCTIONS'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(
                    0xFF1565C0,
                  ), // Main Call to Action
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
                onPressed: () => Navigator.pushNamed(context, '/clock'),
                child: const Text(
                  'ENTER KIOSK MODE',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class ClockScreen extends StatelessWidget {
  const ClockScreen({super.key});

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  String _formatDate(DateTime dt) =>
      '${_monthName(dt.month)} ${dt.day}, ${dt.year}';
  static String _monthName(int m) => [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][m - 1];

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return Scaffold(
          backgroundColor: Colors.white,
          // 🚀 CHANGED: Exit button in AppBar for cleaner look
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF1565C0)),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _formatTime(state.now),
                        style: GoogleFonts.montserrat(
                          fontSize: 80,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1565C0), // Dark Blue Time
                        ),
                      ),
                      Text(
                        _formatDate(state.now),
                        style: GoogleFonts.montserrat(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64B5F6), // Light Blue Date
                        ),
                      ),
                    ],
                  ),
                ),
                // Status Information at the bottom
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 40,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD), // Very Light Blue BG
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Patients Synced',
                              style: TextStyle(
                                color: Colors.blueGrey.shade700,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${state.patientCount}',
                              style: const TextStyle(
                                color: Color(0xFF1565C0),
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'System Status',
                              style: TextStyle(
                                color: Colors.blueGrey.shade700,
                                fontSize: 14,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 12,
                                  color: state.mqttStatus == 'connected'
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  state.mqttStatus.toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF1565C0),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AlarmScreen extends StatelessWidget {
  const AlarmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final p = state.activePatient;
        final a = state.activeAlarm;
        // 🚀 CHANGED: White card design with Blue accents
        return Scaffold(
          backgroundColor: const Color(0xFFE3F2FD), // Light Blue Background
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 500),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFF2196F3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.medication_liquid_rounded,
                        color: Color(0xFF1565C0),
                        size: 80,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'MEDICATION DUE',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          color: const Color(0xFF1565C0),
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Divider(color: Colors.blue.shade100, thickness: 2),
                      const SizedBox(height: 16),
                      if (p != null)
                        Column(
                          children: [
                            Text(
                              p.name,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Tray Slot #${p.slotNumber}',
                                style: const TextStyle(
                                  color: Color(0xFF1976D2),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 24),
                      if (a != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: a.meds
                                .map(
                                  (m) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      m.name,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      const SizedBox(height: 40),
                      // 🚀 CHANGED: Responsive Buttons for Portrait
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1565C0),
                              padding: const EdgeInsets.symmetric(vertical: 24),
                            ),
                            onPressed: () => state.dispenseMedicine(),
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 28,
                            ),
                            label: const Text(
                              'DISPENSE NOW',
                              style: TextStyle(fontSize: 22),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.blueGrey,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: () => state.stopAlarm(),
                            icon: const Icon(Icons.close, size: 24),
                            label: const Text(
                              'Skip / Stop Alarm',
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// -------------------- Placeholder Pages (Styled) --------------------

class RefillPage extends StatelessWidget {
  const RefillPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        "Refill Instructions",
        style: TextStyle(color: Colors.black),
      ),
      backgroundColor: Colors.white,
      elevation: 1,
      iconTheme: const IconThemeData(color: Colors.black),
    ),
    body: const Center(child: Text("Refill Instructions Placeholder")),
  );
}

class AppInstructionsPage extends StatelessWidget {
  const AppInstructionsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        "App Instructions",
        style: TextStyle(color: Colors.black),
      ),
      backgroundColor: Colors.white,
      elevation: 1,
      iconTheme: const IconThemeData(color: Colors.black),
    ),
    body: const Center(child: Text("App Instructions Placeholder")),
  );
}
