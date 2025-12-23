
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/service_providers.dart';
import '../providers/data_providers.dart';
import '../providers/auth_providers.dart';
import '../providers/alarm_queue_provider.dart';

class AppLifecycleManager extends ConsumerStatefulWidget {
  final Widget child;
  const AppLifecycleManager({super.key, required this.child});

  @override
  ConsumerState<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends ConsumerState<AppLifecycleManager> {
  @override
  Widget build(BuildContext context) {
    // 1. Watch Patients to update AlarmService & Schedule Notifications
    ref.listen(patientsProvider, (previous, next) {
      if (next.hasValue) {
        final patients = next.value!;
        final alarmService = ref.read(alarmServiceProvider);
        final notifService = ref.read(notificationServiceProvider);
        final currentUser = ref.read(currentUserUidProvider);
        
        // Update Alarm Service Monitoring
        if (currentUser != null) {
          alarmService.setCurrentUser(currentUser);
        }
        alarmService.updatePatients(patients);
        alarmService.startMonitoring(); // Ensure timer is running

        // Schedule Notifications
        // if (currentUser == null) return; // Removed to allow universal scheduling 

        for (var p in patients) {
          for (var alarm in p.alarms) {
            notifService.scheduleDailyAlarm(
              patient: p,
              alarm: alarm,
              isCreator: true // Universal alarm for all users
            );
          }
        }
      }
    });

    // 2. Watch Auth to update AlarmService context
    ref.listen(currentUserUidProvider, (prev, next) {
      if (next != null) {
        ref.read(alarmServiceProvider).setCurrentUser(next);
      }
    });

    // 3. Watch Alarm Queue for Popup Navigation
    ref.listen(alarmQueueProvider, (previous, next) {
      if (next.isPopupVisible && (previous == null || !previous.isPopupVisible)) {
        // Show Popup
        Navigator.of(context).pushNamed('/alarm_popup');
      } else if (!next.isPopupVisible && (previous != null && previous.isPopupVisible)) {
        // Close Popup
        // Check if top is alarm popup before popping to avoid popping other screens
        // Navigator.of(context).popUntil(...) ?? 
        // We can just pop if we are sure.
        // Or we rely on the popup itself handling dispense/skip which closes it.
        // But if queue closes it programmatically (timeout?), we need to pop.
        
        // Since AlarmPopup is a route, we should verify it's the top route.
        // This is tricky without a dedicated navigator key or route observer.
        // For now, we assume standard flow.
      }
    });

    return widget.child;
  }
}
