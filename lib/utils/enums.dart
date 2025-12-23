
import 'package:flutter/material.dart';

enum MealType {
  breakfast,
  lunch,
  dinner;

  String get displayName => name[0].toUpperCase() + name.substring(1);

  IconData get icon {
    switch (this) {
      case MealType.breakfast:
        return Icons.wb_sunny;
      case MealType.lunch:
        return Icons.wb_cloudy;
      case MealType.dinner:
        return Icons.nightlight;
    }
  }
}

enum MqttConnectionStatus {
  disconnected,
  connecting,
  connected,
  error;

  bool get isConnected => this == MqttConnectionStatus.connected;
}

enum NotificationType {
  medication,
  refill;
  
  String get value => name;
}
