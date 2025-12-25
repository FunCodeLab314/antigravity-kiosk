import 'dart:async';
import 'package:logger/logger.dart';
import '../models/patient_model.dart';
import '../models/alarm_trigger.dart';
import '../models/alarm_model.dart';

class AlarmService {
  final Logger _logger = Logger();
  
  final _controller = StreamController<AlarmTrigger>.broadcast();
  Stream<AlarmTrigger> get onAlarmTriggered => _controller.stream;

  Timer? _timer;
  List<Patient> _currentPatients = [];
  String? _currentUserUid; // Store the logged-in Admin ID
  int _lastTriggeredMinute = -1;

  void updatePatients(List<Patient> patients) {
    _currentPatients = patients;
  }

  // Call this when the user logs in
  void setCurrentUser(String? uid) {
    _currentUserUid = uid;
    _logger.i("AlarmService: Current user set to $_currentUserUid");
  }

  void startMonitoring() {
    _logger.i("Starting alarm monitoring...");
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkAlarms();
    });
  }

  void stopMonitoring() {
    _logger.i("Stopping alarm monitoring...");
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stopMonitoring();
    _controller.close();
  }

  void _checkAlarms() {
    final now = DateTime.now();
    
    if (now.minute == _lastTriggeredMinute) return;

    bool foundAny = false;

    for (var p in _currentPatients) {
      for (var a in p.alarms) {
        if (!a.isActive) continue;

        if (_wasHandledToday(a, now)) {
            continue;
        }

        if (a.hour == now.hour && a.minute == now.minute) {
          
          // --- FIX: Dynamic Check ---
          // Only return TRUE if the patient was created by the current logged-in admin.
          bool isCreator = false;

          if (_currentUserUid != null && p.createdByUid == _currentUserUid) {
             isCreator = true;
          }

          // Debug log to help you verify it works
          if (isCreator) {
             _logger.i("✅ ALARM MATCH: Admin $_currentUserUid matches Patient Creator ${p.createdByUid}");
          } else {
             _logger.w("⚠️ SKIPPING: Alarm for ${p.name} (Created by ${p.createdByUid}) but Logged in as $_currentUserUid");
          }
          
          _controller.add(AlarmTrigger(
            patient: p, 
            alarm: a, 
            isCreator: isCreator, 
            timestamp: now
          ));
          
          foundAny = true;
        }
      }
    }

    if (foundAny) {
      _lastTriggeredMinute = now.minute;
    }
  }

  bool _wasHandledToday(AlarmModel alarm, DateTime now) {
    final lastAction = alarm.medication.lastActionAt;
    if (lastAction == null) return false;

    final isSameDay = lastAction.year == now.year &&
        lastAction.month == now.month &&
        lastAction.day == now.day;
    
    return isSameDay;
  }
}