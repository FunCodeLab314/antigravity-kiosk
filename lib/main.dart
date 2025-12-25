import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'widgets/app_lifecycle_manager.dart';
import 'widgets/ble_connection_manager.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/kiosk_mode_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/history_screen.dart';
import 'screens/alarm_popup.dart';
import 'providers/auth_providers.dart';
import 'providers/service_providers.dart';
import 'providers/data_providers.dart';
import 'providers/alarm_queue_provider.dart';
import 'utils/ble_permission_manager.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  tz.initializeTimeZones();

  runApp(
    const ProviderScope(
      child: PillPalApp(),
    ),
  );
}

class PillPalApp extends ConsumerStatefulWidget {
  const PillPalApp({super.key});

  @override
  ConsumerState<PillPalApp> createState() => _PillPalAppState();
}

class _PillPalAppState extends ConsumerState<PillPalApp> {
  @override
  void initState() {
    super.initState();
    _setupServices();
  }

  Future<void> _setupServices() async {
    // Initialize BLE permissions and scanning
    await BlePermissionManager.initializeBleScanning();
    
    // Initialize notifications
    _setupNotifications();
  }

  Future<void> _setupNotifications() async {
    final notifService = ref.read(notificationServiceProvider);
    
    // 1. Initialize and handle foreground/background taps
    await notifService.initialize((response) {
      if (response.payload != null) {
        debugPrint("📱 Notification tapped in foreground/background");
        _handleNotificationTap(response.payload!);
      }
    });

    // 2. Handle Terminated State (App Launch from Notification)
    // If the app was dead, we check if it was launched by a notification
    final launchPayload = await notifService.getLaunchPayload();
    if (launchPayload != null) {
      debugPrint("🔔 App launched from terminated state by notification");
      // Wait for app to fully initialize and providers to be ready
      Future.delayed(const Duration(seconds: 3), () {
        debugPrint("📲 Now processing terminated-state notification after delay");
        _handleNotificationTap(launchPayload);
      });
    }

    // In debug builds, schedule a quick test notification to validate OS delivery
    if (kDebugMode) {
      try {
        debugPrint('🔧 Scheduling debug test notifications');
        await notifService.showImmediateTestNotification();
        await notifService.showTestNotification(delaySeconds: 10);
      } catch (e) {
        debugPrint('❌ Failed to schedule debug test notifications: $e');
      }
    }
  }

  void _handleNotificationTap(String payloadJson) {
    try {
      final data = jsonDecode(payloadJson);
      debugPrint("🔍 Notification payload: $data");
      
      if (data['type'] == 'alarm') {
        debugPrint("🔔 Processing alarm notification: ${data['patientName']} - ${data['medicationName']}");
        // Pass data to AlarmQueue to force-show the popup
        Future.delayed(const Duration(milliseconds: 500), () {
          ref.read(alarmQueueProvider.notifier).handleNotificationTrigger(data);
        });
      } else if (data['type'] == 'test' || data['type'] == 'immediate_test') {
        debugPrint("🧪 Test notification received");
      }
    } catch (e) {
      debugPrint("❌ Error parsing notification payload: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PillPal Kiosk',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
        fontFamily: GoogleFonts.rubik().fontFamily,
      ),
      home: const AuthWrapper(),
      routes: {
        '/kiosk': (context) => const KioskModeScreen(),
        '/alarm_popup': (context) => const AlarmPopup(),
        '/notifications': (context) => const NotificationsScreen(),
        '/history': (context) => const HistoryScreen(),
      },
      builder: (context, child) {
        return BleConnectionManager(
          child: AppLifecycleManager(child: child!),
        );
      },
    );
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          return const DashboardScreen();
        }
        return const AuthScreen();
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, trace) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}