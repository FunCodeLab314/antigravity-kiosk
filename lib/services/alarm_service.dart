
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
  String? _currentUserUid;
  int _lastTriggeredMinute = -1;

  void updatePatients(List<Patient> patients) {
    _currentPatients = patients;
  }

  void setCurrentUser(String uid) {
    _currentUserUid = uid;
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
    
    // Prevent duplicate triggers in the same minute
    if (now.minute == _lastTriggeredMinute) return;

    bool foundAny = false;

    for (var p in _currentPatients) {
      for (var a in p.alarms) {
        if (!a.isActive) continue;

        // Check if handled today
        if (_wasHandledToday(a, now)) {
            continue;
        }

        if (a.hour == now.hour && a.minute == now.minute) {
          bool isCreator = true; // Universal trigger for all users
          
          _logger.i("Alarm triggered for ${p.name} - ${a.medication.name}");
          
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
