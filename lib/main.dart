
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'widgets/app_lifecycle_manager.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/kiosk_mode_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/history_screen.dart';
import 'screens/alarm_popup.dart';
import 'providers/auth_providers.dart';
import 'providers/service_providers.dart';

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
    // Initialize Notification Service to request permissions and handle taps
    final notifService = ref.read(notificationServiceProvider);
    notifService.initialize((response) {
      if (response.payload != null) {
        // TODO: Handle navigation based on payload
        debugPrint("Notification Tapped: ${response.payload}");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PillPal Kiosk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
        fontFamily: GoogleFonts.rubik().fontFamily,
      ),
      home: const AuthWrapper(),
      // Define routes for named navigation (used by AppLifecycleManager)
      routes: {
        '/kiosk': (context) => const KioskModeScreen(),
        '/alarm_popup': (context) => const AlarmPopup(),
        '/notifications': (context) => const NotificationsScreen(),
        '/history': (context) => const HistoryScreen(),
      },
      builder: (context, child) {
        // Wrap with Lifecycle Manager to handle background events (alerts, updates)
        return AppLifecycleManager(child: child!);
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