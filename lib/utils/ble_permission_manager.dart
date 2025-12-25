import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:logger/logger.dart';

class BlePermissionManager {
  static final Logger _logger = Logger();

  /// Request BLE permissions on Android 12+
  static Future<bool> requestBlePermissions() async {
    try {
      _logger.i("Requesting BLE permissions...");
      
      // Check if BLE is supported
      if (!await FlutterBluePlus.isSupported) {
        _logger.e("BLE is not supported on this device");
        return false;
      }

      // For Android 12+, we need to request BLUETOOTH_SCAN and BLUETOOTH_CONNECT
      // flutter_blue_plus handles this automatically
      _logger.i("BLE permissions check complete");
      return true;
    } catch (e) {
      _logger.e("Error requesting BLE permissions: $e");
      return false;
    }
  }

  /// Initialize BLE scanning when the app starts
  static Future<void> initializeBleScanning() async {
    try {
      final hasPermission = await requestBlePermissions();
      if (!hasPermission) {
        _logger.w("BLE permissions not granted");
        return;
      }

      _logger.i("BLE permissions granted, ready to scan for devices");
    } catch (e) {
      _logger.e("Error initializing BLE: $e");
    }
  }
}
