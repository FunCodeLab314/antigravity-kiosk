
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/service_providers.dart';
import '../models/notification_item.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  Future<void> _sendTestNotificationFromAlarm(WidgetRef ref) async {
    // Get the patient list
    final firestore = ref.read(firestoreServiceProvider);
    final patients = await firestore.getPatients().first;
    
    if (patients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ No patients found!')),
      );
      return;
    }

    // Find the first patient with an active alarm
    for (var patient in patients) {
      for (var alarm in patient.alarms) {
        if (alarm.isActive) {
          // Send notification with real alarm data
          final notifService = ref.read(notificationServiceProvider);
          final title = "💊 Time for Medication!";
          final body = "${patient.name} - ${alarm.medication.name}";
          
          await notifService.showTestNotificationWithData(
            title: title,
            body: body,
            patientName: patient.name,
            medicationName: alarm.medication.name,
            alarmTime: "${alarm.hour.toString().padLeft(2, '0')}:${alarm.minute.toString().padLeft(2, '0')}",
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Test notification sent for ${patient.name}!')),
          );
          return;
        }
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('❌ No active alarms found!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notificationService = ref.read(firestoreServiceProvider); // Using FirestoreService for notification list

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        title: const Text("Notifications"),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active, color: Colors.green),
            tooltip: "Send Test Notification",
            onPressed: () async {
              await _sendTestNotificationFromAlarm(ref);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.red),
            onPressed: () {
              ref.read(firestoreServiceProvider).clearAllNotifications();
            },
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationItem>>(
        stream: notificationService.getNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No notifications"));
          }

          final notifications = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              return _buildNotificationCard(notifications[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem notification) {
    IconData icon;
    Color color;

    switch (notification.type) {
      case 'medication':
        icon = Icons.medication;
        color = Colors.blue;
        break;
      case 'refill':
        icon = Icons.warning_amber_rounded;
        color = Colors.orange;
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
    }

    return Card(
      color: notification.isRead ? Colors.white : Colors.blue[50],
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          notification.title,
          style: TextStyle(fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold),
        ),
        subtitle: Text(
          "${notification.body}\n${DateFormat('MMM dd, HH:mm').format(notification.timestamp)}",
        ),
        trailing: !notification.isRead
            ? IconButton(
                icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                onPressed: () {
                  ref.read(firestoreServiceProvider).markNotificationAsRead(notification.id);
                },
              )
            : null,
      ),
    );
  }
}
