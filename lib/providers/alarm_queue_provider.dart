
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/alarm_trigger.dart';
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
    // Subscription to Alarm Service
    final alarmService = ref.read(alarmServiceProvider);
    
    // Listen to the stream manually and manage subscription
    final sub = alarmService.onAlarmTriggered.listen(_addTrigger);
    
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
    // Lock mechanism to prevent race conditions (Bug 2 fix)
    if (_isProcessingQueue || state.activeTrigger != null || state.queue.isEmpty) {
      return;
    }

    _isProcessingQueue = true;

    try {
      final nextTrigger = state.queue.first;
      final remainingQueue = state.queue.skip(1).toList();

      if (nextTrigger.isCreator) {
        // Show popup loop
        state = state.copyWith(
          queue: remainingQueue,
          activeTrigger: nextTrigger,
          isPopupVisible: true,
        );
        
        // Start Audio
        await ref.read(audioServiceProvider).play();
        
        // Save to Firestore Notifications
        try {
          await ref.read(firestoreServiceProvider).saveNotification(
            title: "💊 Medication Reminder",
            body: "${nextTrigger.patient.name} - ${nextTrigger.alarm.medication.name} (${nextTrigger.alarm.mealType.toUpperCase()})",
            type: 'medication',
            patientId: nextTrigger.patient.id,
            patientNumber: nextTrigger.patient.patientNumber,
            creatorUid: nextTrigger.patient.createdByUid, 
          );
        } catch (e) {
          print("Error saving notification: $e");
        }
        
      } else {
        // Non-creator: Remove from queue and continue
        state = state.copyWith(queue: remainingQueue);
        
        // Small delay
        await Future.delayed(const Duration(milliseconds: 500));
        
        _isProcessingQueue = false;
        _processQueue(); // Recursive call to check next
      }
    } catch (e) {
      print("Error processing queue: $e");
      _isProcessingQueue = false;
    }
  }

  // --- ACTIONS ---

  Future<void> dispense() async {
    final trigger = state.activeTrigger;
    if (trigger == null) return;

    try {
      // 1. Send MQTT Command
      await ref.read(mqttServiceProvider).dispense(trigger.alarm.medication.slotNumber);
      
      // 2. Mark as Taken in DB
      await ref.read(firestoreServiceProvider).markTaken(trigger.patient, trigger.alarm);

      _closeAlarm();
    } catch (e) {
      print("Dispense error: $e");
      rethrow;
    }
  }

  Future<void> skip() async {
    final trigger = state.activeTrigger;
    if (trigger == null) return;

    try {
      await ref.read(firestoreServiceProvider).markSkipped(trigger.patient, trigger.alarm);
      _closeAlarm();
    } catch (e) {
      print("Skip error: $e");
    }
  }

  void _closeAlarm() {
    // Stop Audio
    ref.read(audioServiceProvider).stop();

    // Reset State
    state = state.copyWith(
      forceActiveTriggerNull: true,
      isPopupVisible: false,
    );
    // Note: copyWith passing null for nullable fields:
    // My manual copyWith implementation: activeTrigger ?? this.activeTrigger
    // If I pass null, it keeps previous value!
    // I need to fix copyWith to allow nullable updates.
    
    // Quick fix: Recreate state manually since I'm resetting mostly everything or fix copyWith logic.
    // I'll fix copyWith logic in this file content.
     
    _isProcessingQueue = false;
    Future.delayed(const Duration(milliseconds: 500), _processQueue);
  }
}
