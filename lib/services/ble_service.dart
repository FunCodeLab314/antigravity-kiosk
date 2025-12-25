import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:logger/logger.dart';

class BleService {
  final Logger _logger = Logger();

  // UUIDs from ESP32 code
  static const String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String commandCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  static const String statusCharacteristicUuid = "a1e1f32a-57b1-4176-a19f-d31e5f8f831b";
  static const String espDeviceName = "PillPal-Dispenser";

  late BluetoothDevice _connectedDevice;
  late BluetoothCharacteristic _commandCharacteristic;
  late BluetoothCharacteristic _statusCharacteristic;

  final _connectionStateController = StreamController<bool>.broadcast();
  Stream<bool> get onConnectionStateChanged => _connectionStateController.stream;

  final _statusController = StreamController<String>.broadcast();
  Stream<String> get onStatusReceived => _statusController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  Timer? _reconnectTimer;

  /// Start scanning for ESP32 device
  Future<void> startScanning() async {
    try {
      _logger.i("Starting BLE scan for $espDeviceName...");

      // Cancel any existing scan subscription before starting a new one
      await FlutterBluePlus.stopScan();
      await _scanSubscription?.cancel();

      // Start scan, prefer filtering by advertised service UUID when possible
      try {
        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 10),
          withServices: [Guid(serviceUuid)],
        );
      } catch (e) {
        // Some platforms or plugin versions may not support withServices; fallback to broad scan
        _logger.w('startScan with service filter failed, falling back to broad scan: $e');
        await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      }

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (results.isEmpty) {
          _logger.d('Scan update: no devices in this batch');
          return;
        }

        _logger.d('📡 Scan batch: ${results.length} devices found');

        for (ScanResult result in results) {
          try {
            final adv = result.advertisementData;
            final deviceName = (result.device.name ?? adv.localName ?? '').toLowerCase();
            final advertisedServices = adv.serviceUuids.map((s) => s.toString().toLowerCase()).toList();

            _logger.i('📱 Device: id=${result.device.remoteId}, name="$deviceName", advName="${adv.localName}", rssi=${result.rssi}, services=$advertisedServices');

            final bool nameMatches = deviceName.contains('pillpal') || deviceName.contains('pill');
            final bool serviceMatches = advertisedServices.contains(serviceUuid.toLowerCase());

            if (nameMatches || serviceMatches) {
              _logger.i("Found PillPal device: ${result.device.remoteId} (name match=$nameMatches, service match=$serviceMatches)");
              _connectToDevice(result.device);
              FlutterBluePlus.stopScan();
              break;
            }
          } catch (e) {
            _logger.w('Error processing scan result: $e');
          }
        }
      });
    } catch (e) {
      _logger.e("Error starting scan: $e");
      rethrow;
    }
  }

  /// Connect to the ESP32 device
  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      _logger.i("Attempting to connect to ${device.remoteId}...");
      await device.connect(timeout: const Duration(seconds: 10));
      _connectedDevice = device;

      // Listen for disconnection and attempt reconnection
      _connectionSubscription =
          _connectedDevice.connectionState.listen((BluetoothConnectionState state) {
        if (state == BluetoothConnectionState.disconnected) {
          _logger.w("Device disconnected! Attempting to reconnect...");
          _isConnected = false;
          _connectionStateController.add(false);
          _scheduleReconnection();
        }
      });

      _logger.i("Connected! Discovering services...");
      await _discoverCharacteristics();

      _isConnected = true;
      _connectionStateController.add(true);
      _logger.i("✅ Successfully connected and ready!");
    } catch (e) {
      _logger.e("Connection error: $e");
      _isConnected = false;
      _connectionStateController.add(false);
      _scheduleReconnection();
    }
  }

  /// Schedule automatic reconnection
  void _scheduleReconnection() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _logger.i("Attempting automatic reconnection...");
      startScanning();
    });
  }

  /// Discover and store characteristic references
  Future<void> _discoverCharacteristics() async {
    try {
      List<BluetoothService> services = await _connectedDevice.discoverServices();

      for (BluetoothService service in services) {
        if (service.uuid.str.toLowerCase() == serviceUuid.toLowerCase()) {
          _logger.i("Found PillPal service!");

          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.str.toLowerCase() == commandCharacteristicUuid.toLowerCase()) {
              _commandCharacteristic = characteristic;
              _logger.i("Found command characteristic");
            } else if (characteristic.uuid.str.toLowerCase() ==
                statusCharacteristicUuid.toLowerCase()) {
              _statusCharacteristic = characteristic;
              _logger.i("Found status characteristic");

              // Subscribe to status notifications
              if (characteristic.properties.notify) {
                await characteristic.setNotifyValue(true);
                _listenToStatusUpdates();
                _logger.i("Subscribed to status notifications");
              }
            }
          }
          break;
        }
      }
    } catch (e) {
      _logger.e("Error discovering characteristics: $e");
      rethrow;
    }
  }

  /// Listen for status updates from ESP32
  void _listenToStatusUpdates() {
    _statusCharacteristic.onValueReceived.listen((value) {
      try {
        String statusJson = String.fromCharCodes(value);
        _logger.i("Status received from ESP: $statusJson");
        _statusController.add(statusJson);

        // Parse and log if it's JSON
        try {
          final decoded = jsonDecode(statusJson);
          _logger.i("Parsed status: $decoded");
        } catch (_) {
          // Not JSON, just log the raw string
        }
      } catch (e) {
        _logger.e("Error processing status: $e");
      }
    });
  }

  /// Send a DISPENSE command to ESP32 for a specific slot
  Future<void> sendDispenseCommand(int slot) async {
    try {
      if (!_isConnected) {
        throw Exception("BLE not connected");
      }

      final command = {
        "command": "DISPENSE",
        "slot": slot.toString(),
      };

      String jsonCommand = jsonEncode(command);
      List<int> bytes = utf8.encode(jsonCommand);

      _logger.i("Sending dispense command: $jsonCommand");
      await _commandCharacteristic.write(bytes, withoutResponse: false);
      _logger.i("✅ Dispense command sent!");
    } catch (e) {
      _logger.e("Error sending dispense command: $e");
      rethrow;
    }
  }

  /// Send ALARM_START command
  Future<void> sendAlarmStartCommand() async {
    try {
      if (!_isConnected) {
        throw Exception("BLE not connected");
      }

      final command = {
        "command": "ALARM_START",
      };

      String jsonCommand = jsonEncode(command);
      List<int> bytes = utf8.encode(jsonCommand);

      _logger.i("Sending alarm start command");
      await _commandCharacteristic.write(bytes, withoutResponse: false);
      _logger.i("✅ Alarm start command sent!");
    } catch (e) {
      _logger.e("Error sending alarm start command: $e");
      rethrow;
    }
  }

  /// Send ALARM_STOP command
  Future<void> sendAlarmStopCommand() async {
    try {
      if (!_isConnected) {
        throw Exception("BLE not connected");
      }

      final command = {
        "command": "ALARM_STOP",
      };

      String jsonCommand = jsonEncode(command);
      List<int> bytes = utf8.encode(jsonCommand);

      _logger.i("Sending alarm stop command");
      await _commandCharacteristic.write(bytes, withoutResponse: false);
      _logger.i("✅ Alarm stop command sent!");
    } catch (e) {
      _logger.e("Error sending alarm stop command: $e");
      rethrow;
    }
  }

  /// Disconnect from device
  Future<void> disconnect() async {
    try {
      if (_connectedDevice != null) {
        await _connectedDevice.disconnect();
        _isConnected = false;
        _connectionStateController.add(false);
        _logger.i("Disconnected from device");
      }
    } catch (e) {
      _logger.e("Error disconnecting: $e");
    }
  }

  /// Dispose resources
  void dispose() {
    _reconnectTimer?.cancel();
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _connectionStateController.close();
    _statusController.close();
    if (_isConnected) {
      disconnect();
    }
  }
}
