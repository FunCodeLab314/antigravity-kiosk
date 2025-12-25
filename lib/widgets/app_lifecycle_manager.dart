import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/data_providers.dart';
import '../providers/alarm_queue_provider.dart';
import '../main.dart'; // Import to access navigatorKey

class AppLifecycleManager extends ConsumerStatefulWidget {
  final Widget child;

  const AppLifecycleManager({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends ConsumerState<AppLifecycleManager> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle background/foreground changes if necessary
    super.didChangeAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(patientAlarmSyncProvider);

    ref.listen(alarmQueueProvider, (previous, next) {
      
      // TRIGGER: Show Popup
      if ((previous?.isPopupVisible == false || previous == null) && next.isPopupVisible) {
        debugPrint("🚨 Alarm Triggered! Navigating to Popup...");
        navigatorKey.currentState?.pushNamed('/alarm_popup');
      }

      // DISMISS: Close Popup and return to home
      if ((previous?.isPopupVisible == true) && !next.isPopupVisible) {
         debugPrint("✅ Alarm Closed. Returning to Home...");
         
         // Pop the alarm popup to go back to previous screen
         navigatorKey.currentState?.pop();
      }
    });

    return widget.child;
  }
}