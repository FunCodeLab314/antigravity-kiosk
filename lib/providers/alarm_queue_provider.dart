import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/alarm_trigger.dart';
import '../models/patient_model.dart'; // Explicit import needed
import '../models/alarm_model.dart';   // Explicit import needed
import 'service_providers.dart';
import 'data_providers.dart';

part 'alarm_queue_provider.g.dart';

class AlarmQueueState {
  final List<AlarmTrigger> queue;
  final AlarmTrigger? activeTrigger;
  final bool isPopupVisible;

  const AlarmQueueState({
    this.queue = const [],
    this.activeTrigger,
    this.isPopupVisible = false,
  });

  AlarmQueueState copyWith({
    List<AlarmTrigger>? queue,
    AlarmTrigger? activeTrigger,
    bool forceActiveTriggerNull = false,
    bool? isPopupVisible,
  }) {
    return AlarmQueueState(
      queue: queue ?? this.queue,
      activeTrigger: forceActiveTriggerNull ? null : (activeTrigger ?? this.activeTrigger),
      isPopupVisible: isPopupVisible ?? this.isPopupVisible,
    );
  }
}

@Riverpod(keepAlive: true)
class AlarmQueue extends _$AlarmQueue {
  bool _isProcessingQueue = false;

  @override
  AlarmQueueState build() {
    print("🏗️ AlarmQueue Provider Built");
    final alarmService = ref.read(alarmServiceProvider);
    
    final sub = alarmService.onAlarmTriggered.listen((trigger) {
      print("👂 Provider received trigger for: ${trigger.patient.name}");
      _addTrigger(trigger);
    });
    
    ref.onDispose(() {
      sub.cancel();
    });
    
    return const AlarmQueueState();
  }

  void _addTrigger(AlarmTrigger trigger) {
    state = state.copyWith(queue: [...state.queue, trigger]);
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isProcessingQueue || state.activeTrigger != null || state.queue.isEmpty) {
      return;
    }

    _isProcessingQueue = true;

    try {
      final nextTrigger = state.queue.first;
      final remainingQueue = state.queue.skip(1).toList();

      if (nextTrigger.isCreator) {
        // --- SHOW POPUP ---
        state = state.copyWith(
          queue: remainingQueue,
          activeTrigger: nextTrigger,
          isPopupVisible: true,
        );
        
        // 1. Show Local Notification
        try {
          print("🔔 Showing local notification...");
          await ref.read(notificationServiceProvider).showTestNotificationWithData(
            title: "💊 Time for Medication!",
            body: "${nextTrigger.patient.name} - ${nextTrigger.alarm.medication.name}",
            patientName: nextTrigger.patient.name,
            medicationName: nextTrigger.alarm.medication.name,
            alarmTime: "${nextTrigger.alarm.hour.toString().padLeft(2, '0')}:${nextTrigger.alarm.minute.toString().padLeft(2, '0')}",
          );
          print("✅ Local notification shown!");
        } catch (e) {
          print("⚠️ Error showing local notification: $e");
        }
        
        // 2. Play Audio
        try {
          await ref.read(audioServiceProvider).play();
        } catch (e) {
          print("🔊 Audio error: $e");
        }
        
        // 3. Save Notification to Firestore (For NotificationScreen)
        try {
          print("💾 Saving notification to Firestore...");
          await ref.read(firestoreServiceProvider).saveNotification(
            title: "💊 Medication Reminder",
            body: "${nextTrigger.patient.name} - ${nextTrigger.alarm.medication.name} (${nextTrigger.alarm.mealType.toUpperCase()})",
            type: 'medication',
            patientId: nextTrigger.patient.id,
            patientNumber: nextTrigger.patient.patientNumber,
            creatorUid: nextTrigger.patient.createdByUid, 
          );
          print("✅ Notification saved!");
        } catch (e) {
          print("❌ Error saving notification: $e");
        }
        
      } else {
        // Non-creator: Silent consume
        state = state.copyWith(queue: remainingQueue);
        await Future.delayed(const Duration(milliseconds: 500));
        _isProcessingQueue = false;
        _processQueue();
      }
    } catch (e) {
      print("❌ Error processing queue: $e");
      _isProcessingQueue = false;
    }
  }

  // --- ACTIONS ---

  Future<void> dispense({required int slotNumber}) async {
    final trigger = state.activeTrigger;
    if (trigger == null) return;

    try {
      // Send dispense command via BLE to ESP32
      final bleService = ref.read(bleServiceProvider);
      await bleService.sendDispenseCommand(slotNumber);
      
      // Update Firestore to mark as taken
      try {
        await ref.read(firestoreServiceProvider).markTaken(trigger.patient, trigger.alarm);
      } catch (e) {
        print("Warning: Pill dispensed but DB update failed: $e");
      }
      _closeAlarm();
    } catch (e) {
      print("❌ Dispense failed: $e");
      rethrow; 
    }
  }

  Future<void> skip() async {
    final trigger = state.activeTrigger;
    if (trigger == null) return;
    try {
      await ref.read(firestoreServiceProvider).markSkipped(trigger.patient, trigger.alarm);
    } catch (e) {
      print("❌ Skip error: $e");
    } finally {
      // Ensure we always close, even if DB fails
      _closeAlarm();
    }
  }

  void _closeAlarm() {
    try {
      ref.read(audioServiceProvider).stop();
    } catch (e) {
      print("Error stopping audio: $e");
    }

    state = state.copyWith(
      forceActiveTriggerNull: true,
      isPopupVisible: false,
    );
      
    _isProcessingQueue = false;
    Future.delayed(const Duration(milliseconds: 500), _processQueue);
  }

  Future<void> handleNotificationTrigger(Map<String, dynamic> payload) async {
    final String? patientId = payload['patientId'];
    final String? alarmId = payload['alarmId'];
        // Skip test notifications without IDs
    if (payload['type'] == 'test' || payload['type'] == 'immediate_test') {
      print("🧪 Test notification received - skipping alarm trigger");
      return;
    }
        if (patientId == null || alarmId == null) {
      print("❌ Invalid notification payload - missing patientId or alarmId");
      return;
    }
    
    print("� Processing notification for Patient: $patientId, Alarm: $alarmId");

    final patients = ref.read(patientsListProvider); 

    Patient? targetPatient;
    AlarmModel? targetAlarm;
    
    for (var p in patients) {
      if (p.id == patientId) {
        for (var a in p.alarms) {
          if (a.id == alarmId) {
            targetPatient = p;
            targetAlarm = a;
            break;
          }
        }
        if (targetAlarm != null) break;
      }
    }

    if (targetPatient != null && targetAlarm != null) {
      print("✅ Found patient and alarm - triggering popup for ${targetPatient.name}");
      _addTrigger(AlarmTrigger(
        patient: targetPatient,
        alarm: targetAlarm,
        isCreator: true, // Force Popup
        timestamp: DateTime.now(),
      ));
    } else {
      print("⚠️ Could not find patient ($patientId) or alarm ($alarmId) in list");
    }
  }
}