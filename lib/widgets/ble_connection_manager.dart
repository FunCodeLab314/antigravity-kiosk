import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/service_providers.dart';
import '../utils/ble_permission_manager.dart';

/// Widget that manages BLE connection status and auto-connects when the app starts
class BleConnectionManager extends ConsumerStatefulWidget {
  final Widget child;

  const BleConnectionManager({required this.child, super.key});

  @override
  ConsumerState<BleConnectionManager> createState() => _BleConnectionManagerState();
}

class _BleConnectionManagerState extends ConsumerState<BleConnectionManager> {
  @override
  void initState() {
    super.initState();
    _initBleConnection();
  }

  Future<void> _initBleConnection() async {
    try {
      debugPrint("🔵 Initializing BLE connection...");
      
      // Request permissions first
      final hasPermission = await BlePermissionManager.requestBlePermissions();
      
      if (!hasPermission) {
        debugPrint("❌ BLE permissions not granted");
        return;
      }

      if (!mounted) return;

      debugPrint("✅ BLE permissions granted");
      
      // Get the BLE service and start scanning
      final bleService = ref.read(bleServiceProvider);
      
      // Start scanning with a slight delay to ensure everything is initialized
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;
      
      debugPrint("🔍 Starting BLE scan for PillPal-Dispenser...");
      await bleService.startScanning();
      
      debugPrint("✅ BLE scan started successfully");
    } catch (e) {
      debugPrint("❌ Error initializing BLE: $e");
    }
  }

  @override
  void dispose() {
    // Don't disconnect automatically - keep connection alive for alarms
    // ref.read(bleServiceProvider).dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the BLE connection state to update when connection changes
    final connectionState = ref.watch(bleConnectionStateProvider);
    
    return connectionState.when(
      data: (isConnected) {
        if (isConnected) {
          debugPrint("🟢 BLE Connected to PillPal-Dispenser");
        }
        return widget.child;
      },
      loading: () {
        return widget.child;
      },
      error: (error, stack) {
        debugPrint("⚠️ BLE connection error: $error");
        return widget.child;
      },
    );
  }
}
