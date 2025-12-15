import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

// --- IMPORT THE FILE YOU JUST GENERATED ---
import 'firebase_options.dart';

// Global navigator key for provider-driven navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Disable Google Fonts runtime fetching to avoid AssetManifest.json errors
  GoogleFonts.config.allowRuntimeFetching = false;

  // Initialize Firebase using the credentials you just generated
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print(
      'Firebase initialized for project: ${DefaultFirebaseOptions.currentPlatform.projectId}',
    );
  } catch (e) {
    print('Firebase initialization error: $e');
  }

  // Lock to landscape (kiosk-like)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]).then((_) {
    runApp(const PillPalApp());
  });
}

class PillPalApp extends StatelessWidget {
  const PillPalApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Use system font directly without GoogleFonts to avoid AssetManifest issues
    final baseTextStyle = const TextStyle(
      color: Colors.white,
      fontFamily: 'Roboto',
    );

    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'PillPal',
        theme: ThemeData(
          scaffoldBackgroundColor: Colors.black,
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
          ),
          colorScheme: const ColorScheme.dark(),
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

// -------------------- Models --------------------
class Medication {
  String name;
  Medication({required this.name});
  factory Medication.fromJson(dynamic j) {
    if (j == null) return Medication(name: '');
    if (j is String) return Medication(name: j);
    if (j is Map) return Medication(name: j['name'] ?? '');
    return Medication(name: j.toString());
  }
  Map<String, dynamic> toJson() => {'name': name};
}

class AlarmModel {
  int hour;
  int minute;
  bool isActive;
  List<Medication> meds;
  String? id;

  AlarmModel({
    required this.hour,
    required this.minute,
    required this.isActive,
    required this.meds,
    this.id,
  });

  factory AlarmModel.fromJson(Map<dynamic, dynamic> j) {
    // Support both List and Map representations from Realtime Database
    var medsField =
        j['meds'] ?? j['medications']; // Try 'meds' or 'medications' field
    List medsList = [];
    if (medsField is List) {
      medsList = medsField;
    } else if (medsField is Map) {
      medsList = medsField.values.toList();
    }

    // Parse hour and minute from either separate fields or timeOfDay string
    int hour = 0;
    int minute = 0;

    if (j.containsKey('hour') && j.containsKey('minute')) {
      // If separate fields exist, use them
      hour = int.tryParse(j['hour'].toString()) ?? 0;
      minute = int.tryParse(j['minute'].toString()) ?? 0;
    } else if (j.containsKey('timeOfDay')) {
      // Parse timeOfDay string like "01:43" or "14:30"
      final timeOfDay = j['timeOfDay']?.toString() ?? '';
      final parts = timeOfDay.split(':');
      if (parts.length == 2) {
        hour = int.tryParse(parts[0]) ?? 0;
        minute = int.tryParse(parts[1]) ?? 0;
      }
    }

    return AlarmModel(
      hour: hour,
      minute: minute,
      isActive: j['isActive'] ?? true,
      meds: medsList.map((m) => Medication.fromJson(m)).toList(),
      id: j['__id']?.toString(),
    );
  }
}

class Patient {
  String name;
  int age;
  int slotNumber;
  List<AlarmModel> alarms;
  String? id;

  Patient({
    required this.name,
    required this.age,
    required this.slotNumber,
    required this.alarms,
    this.id,
  });

  factory Patient.fromJson(Map<dynamic, dynamic> j) {
    // Support both List and Map representations from Realtime Database
    var alarmsField = j['alarms'];
    List alarmsList = [];
    if (alarmsField is List) {
      alarmsList = alarmsField;
    } else if (alarmsField is Map) {
      // If alarms is a map, inject the alarm ID from the key
      alarmsField.forEach((key, alarmData) {
        if (alarmData is Map) {
          alarmData['__id'] = key;
        }
      });
      alarmsList = alarmsField.values.toList();
    }

    return Patient(
      name: j['name'] ?? '',
      age: int.tryParse(j['age'].toString()) ?? 0,
      slotNumber: int.tryParse(j['slotNumber'].toString()) ?? 0,
      alarms: alarmsList.map((a) => AlarmModel.fromJson(a)).toList(),
      id: j['__id']?.toString(),
    );
  }
}

// -------------------- App State & MQTT --------------------
class AppState extends ChangeNotifier {
  List<Patient> patients = [];
  bool isAlarmActive = false;
  String mqttStatus = 'disconnected';
  DateTime now = DateTime.now();

  // Active alarm references
  Patient? activePatient;
  AlarmModel? activeAlarm;

  // Firebase Database Reference
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // MQTT config (Your HiveMQ Credentials)
  final String _host = 'b18466311acb443e9753aae2266143d3.s1.eu.hivemq.cloud';
  final int _port = 8883;
  final String _username = 'pillpal_device';
  final String _password = 'SecurePass123!';
  final String _clientId = 'PillPal_Flutter_Kiosk';

  // Topics
  final String _topicCmd = 'pillpal/device001/cmd';
  final String _topicStatus = 'pillpal/device001/status';

  late MqttServerClient _client;
  Timer? _clockTimer;

  AppState() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      now = DateTime.now();
      notifyListeners();
      _checkAlarms();
    });

    Future.microtask(() {
      try {
        _connectMqtt().catchError((e) => print('MQTT init error: $e'));
      } catch (e) {
        print('MQTT exception: $e');
      }
      _listenToFirebase();
      // TODO: Remove this test data once Firebase Realtime Database security rules are fixed
      _loadTestData();
    });
  }

  // Temporary test data for alarm testing (remove once Firebase is working)
  void _loadTestData() {
    try {
      print('DEBUG: Starting _loadTestData()');
      final now = DateTime.now();
      print('DEBUG: Current time is ${now.hour}:${now.minute}:${now.second}');
      final testPatients = [
        Patient(
          name: 'Test Patient',
          age: 65,
          slotNumber: 1,
          alarms: [
            AlarmModel(
              hour: now.hour,
              minute: now.minute,
              isActive: true,
              meds: [
                Medication(name: 'Aspirin'),
                Medication(name: 'Vitamin D'),
              ],
            ),
          ],
          id: 'test_patient_1',
        ),
      ];
      patients = testPatients;
      notifyListeners();
      print('DEBUG: Loaded test data: ${patients.length} test patients');
    } catch (e) {
      print('ERROR loading test data: $e');
    }
  }

  int get patientCount => patients.length;

  // --- FIREBASE LISTENER ---
  void _listenToFirebase() {
    // One-time fetch to help debug initial sync
    _dbRef
        .child('patients')
        .get()
        .then((snap) {
          print('Firebase initial fetch type: ${snap.value.runtimeType}');
        })
        .catchError((e) {
          print('Firebase initial fetch error: $e');
        });

    _dbRef
        .child('patients')
        .onValue
        .listen(
          (event) {
            try {
              final data = event.snapshot.value;
              // Helpful debug logging to understand data shape coming from RTDB
              try {
                print('Firebase snapshot type: ${data.runtimeType}');
                // Avoid throwing for non-encodable types
                print('Raw snapshot (preview): ${jsonEncode(data)}');
              } catch (e) {
                print('Firebase snapshot debug encode failed: $e');
              }
              List<Patient> newPatients = [];

              if (data is List) {
                for (var item in data) {
                  if (item != null) newPatients.add(Patient.fromJson(item));
                }
              } else if (data is Map) {
                data.forEach((key, value) {
                  // Inject the RTDB key so Patient/Alarm models can persist changes back
                  if (value is Map) {
                    value['__id'] = key;
                  }
                  newPatients.add(Patient.fromJson(value));
                });
              }

              patients = newPatients;
              notifyListeners();
              print("Firebase: Synced ${patients.length} patients.");
            } catch (e) {
              print("Firebase Sync Error: $e");
            }
          },
          onError: (err) {
            print('Firebase onValue listener error: $err');
          },
        );
  }

  // Manual fetch helper for debugging and one-off syncs
  Future<void> fetchPatientsNow() async {
    try {
      final snap = await _dbRef.child('patients').get();
      final data = snap.value;
      print('Manual fetch snapshot type: ${data.runtimeType}');

      List<Patient> newPatients = [];
      if (data is List) {
        for (var item in data) {
          if (item != null) newPatients.add(Patient.fromJson(item));
        }
      } else if (data is Map) {
        data.forEach((key, value) {
          if (value is Map) value['__id'] = key;
          newPatients.add(Patient.fromJson(value));
        });
      }

      patients = newPatients;
      notifyListeners();
      print('Manual fetch: Synced ${patients.length} patients.');
    } catch (e) {
      print('Manual fetch error: $e');
    }
  }

  // --- MQTT CONNECTION ---
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

  // --- ALARM LOGIC ---
  void _checkAlarms() {
    if (isAlarmActive) return;

    for (final p in patients) {
      for (final a in p.alarms) {
        if (!a.isActive) continue;

        // Trigger if times match (and seconds is 0 to avoid multi-trigger)
        if (a.hour == now.hour && a.minute == now.minute && now.second == 0) {
          print(
            'Alarm matched for patient ${p.name} slot ${p.slotNumber} at ${a.hour}:${a.minute}',
          );
          _triggerAlarm(p, a);
          return;
        }
      }
    }
  }

  void _triggerAlarm(Patient p, AlarmModel a) {
    print('Triggering alarm UI for ${p.name}');
    activePatient = p;
    activeAlarm = a;
    isAlarmActive = true;
    notifyListeners();
    navigatorKey.currentState?.pushNamed('/alarm');
  }

  // --- DISPENSE ACTION ---
  void dispenseMedicine() {
    if (activePatient == null || activeAlarm == null) return;

    // Capture current alarm/patient for persistence after MQTT
    final Patient currentPatient = activePatient!;
    final AlarmModel currentAlarm = activeAlarm!;

    // TODO: Send JSON Command to ESP32 (hardware integration later)
    // final msg = jsonEncode({
    //   'command': 'DISPENSE',
    //   'slot': currentPatient.slotNumber,
    // });
    // final builder = MqttClientPayloadBuilder();
    // builder.addString(msg);
    // _client.publishMessage(_topicCmd, MqttQos.atLeastOnce, builder.payload!);
    print(
      'Dispense medicine for patient ${currentPatient.name} slot ${currentPatient.slotNumber}',
    );

    // Persist alarm inactive state back to Firebase if we have keys
    try {
      Patient? p;
      for (var pt in patients) {
        if (pt.slotNumber == currentPatient.slotNumber) {
          p = pt;
          break;
        }
      }
      if (p != null && p.id != null) {
        // Try to find alarm index to update; best-effort (may fail for map-shaped alarms)
        final idx = p.alarms.indexWhere(
          (al) =>
              al.hour == currentAlarm.hour && al.minute == currentAlarm.minute,
        );
        if (idx != -1) {
          final pid = p.id!;
          _dbRef
              .child('patients')
              .child(pid)
              .child('alarms')
              .child('$idx')
              .child('isActive')
              .set(false)
              .then((_) {
                print(
                  'Persisted alarm inactive for patient $pid alarm index $idx',
                );
              })
              .catchError((e) {
                print('Failed to persist alarm state: $e');
              });
        }
      }
    } catch (e) {
      print('Error persisting alarm state: $e');
    }

    // Clear Alarm State locally
    currentAlarm.isActive = false;
    isAlarmActive = false;
    activePatient = null;
    activeAlarm = null;
    notifyListeners();
    // Go back to clock
    navigatorKey.currentState?.popUntil(
      (route) => route.settings.name == '/clock',
    );
  }

  void stopAlarm() {
    // TODO: Send STOP to ESP32 (hardware integration later)
    // final msg = jsonEncode({'command': 'STOP'});
    // final builder = MqttClientPayloadBuilder();
    // builder.addString(msg);
    // _client.publishMessage(_topicCmd, MqttQos.atLeastOnce, builder.payload!);
    print('Alarm stopped by user');

    isAlarmActive = false;
    activePatient = null;
    activeAlarm = null;
    notifyListeners();
    navigatorKey.currentState?.popUntil(
      (route) => route.settings.name == '/clock',
    );
  }

  void rebootDevice() {
    // Only used for simulation in App
  }
}

// -------------------- UI Screens --------------------

class TitleScreen extends StatelessWidget {
  const TitleScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Container(
          color: Colors.black,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Text(
                'PillPal',
                style: textTheme.headlineLarge?.copyWith(fontSize: 72),
              ),
              const SizedBox(height: 12),
              Text('SMART MEDICINE DISPENSER', style: textTheme.headlineMedium),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white24,
                      padding: const EdgeInsets.all(16),
                    ),
                    onPressed: () => Navigator.pushNamed(context, '/refill'),
                    child: const Text('Refill Instructions'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white24,
                      padding: const EdgeInsets.all(16),
                    ),
                    onPressed: () =>
                        Navigator.pushNamed(context, '/instructions'),
                    child: const Text('App Instructions'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                onPressed: () => Navigator.pushNamed(context, '/clock'),
                child: const Text('ENTER KIOSK MODE'),
              ),
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
          body: SafeArea(
            child: Container(
              color: Colors.black,
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(state.now),
                          style: Theme.of(
                            context,
                          ).textTheme.headlineLarge?.copyWith(fontSize: 96),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatDate(state.now),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 24,
                    bottom: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Patients Synced: ${state.patientCount}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        Text(
                          'MQTT: ${state.mqttStatus}',
                          style: TextStyle(
                            color: state.mqttStatus == 'connected'
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (kDebugMode)
                    Positioned(
                      right: 24,
                      bottom: 24,
                      child: FloatingActionButton(
                        mini: true,
                        onPressed: () => state.fetchPatientsNow(),
                        child: const Icon(Icons.sync),
                      ),
                    ),
                  Positioned(
                    left: 24,
                    top: 24,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('EXIT'),
                    ),
                  ),
                ],
              ),
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
        return Scaffold(
          backgroundColor: Colors.black,
          body: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.redAccent, width: 4),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 80,
                ),
                const SizedBox(height: 16),
                Text(
                  'MEDICATION DUE',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.red,
                    fontSize: 56,
                  ),
                ),
                const SizedBox(height: 24),
                if (p != null)
                  Text(
                    'Patient: ${p.name}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                if (p != null)
                  Text(
                    'Slot #${p.slotNumber}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                const SizedBox(height: 16),
                if (a != null)
                  ...a.meds.map(
                    (m) => Text(
                      '- ${m.name}',
                      style: const TextStyle(fontSize: 24, color: Colors.white),
                    ),
                  ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 20,
                        ),
                      ),
                      onPressed: () => state.dispenseMedicine(),
                      child: const Text(
                        'DISPENSE',
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 40),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 20,
                        ),
                      ),
                      onPressed: () => state.stopAlarm(),
                      child: const Text(
                        'SKIP / STOP',
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class RefillPage extends StatelessWidget {
  const RefillPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Refill")),
    body: const Center(child: Text("Refill Instructions Placeholder")),
  );
}

class AppInstructionsPage extends StatelessWidget {
  const AppInstructionsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Instructions")),
    body: const Center(child: Text("App Instructions Placeholder")),
  );
}
