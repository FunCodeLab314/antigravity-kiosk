
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
  @override
  Widget build(BuildContext context) {
    final notificationService = ref.read(firestoreServiceProvider); // Using FirestoreService for notification list

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        title: const Text("Notifications"),
        actions: [
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
