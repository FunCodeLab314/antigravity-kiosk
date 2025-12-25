# BLE Alarm Implementation Guide

## Overview
Your app now has a fully integrated BLE (Bluetooth Low Energy) alarm system that communicates directly with your ESP32 PillPal-Dispenser device. The alarm works even when the app is in the background and sends medication dispensing commands via BLE to the ESP32.

## Key Features Implemented

### 1. **BLE Service** (`lib/services/ble_service.dart`)
- Manages BLE connection to ESP32 "PillPal-Dispenser"
- Handles device scanning and automatic connection
- Sends commands to ESP32 in JSON format:
  - `DISPENSE` command with slot number
  - `ALARM_START` and `ALARM_STOP` commands
- Listens for status updates from ESP32
- Uses the same UUIDs as your ESP code:
  - Service UUID: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
  - Command Characteristic: `beb5483e-36e1-4688-b7f5-ea07361b26a8`
  - Status Characteristic: `a1e1f32a-57b1-4176-a19f-d31e5f8f831b`

### 2. **BLE Providers** (`lib/providers/service_providers.dart`)
Added three new providers:
- `bleServiceProvider`: Main BLE service instance
- `bleConnectionStateProvider`: Stream of connection state changes
- `bleIsConnectedProvider`: Boolean provider for current connection status

### 3. **Updated Alarm Popup** (`lib/screens/alarm_popup.dart`)
- Now displays BLE connection status instead of MQTT
- "DISPENSE" button is **only enabled when BLE is connected**
- Shows "OFFLINE" status when disconnected
- Displays "Connecting to ESP Dispenser..." message when not connected
- When dispense is clicked, sends the slot number to ESP via BLE

### 4. **Updated Alarm Queue Logic** (`lib/providers/alarm_queue_provider.dart`)
- `dispense()` method now accepts `slotNumber` parameter
- Sends BLE command instead of MQTT
- Still updates Firestore to mark medication as taken

### 5. **Android Permissions** (`android/app/src/main/AndroidManifest.xml`)
Added required BLE permissions:
```xml
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

### 6. **BLE Connection Manager** (`lib/widgets/ble_connection_manager.dart`)
- Auto-initializes BLE scanning when app starts
- Requests permissions automatically
- Manages the BLE lifecycle

### 7. **Permission Manager** (`lib/utils/ble_permission_manager.dart`)
- Handles BLE permission requests
- Checks if BLE is supported on the device

## How It Works

### Alarm Flow
1. **Alarm Triggers**: When medication time arrives, the alarm popup appears
2. **Audio & Notification**: Plays sound and shows notification
3. **BLE Status Display**: Shows connection status to ESP32
   - If connected: DISPENSE button is active (blue)
   - If disconnected: DISPENSE button is disabled (gray)
4. **User Actions**:
   - **SKIP**: Marks medication as skipped in Firestore
   - **DISPENSE**: Sends JSON command to ESP32 via BLE

### BLE Communication

**Dispense Command Sent to ESP32**:
```json
{
  "command": "DISPENSE",
  "slot": "1"
}
```

The ESP32 receives this and:
- Forwards the slot number to the Nano via Serial: `<1>`
- Sends back status: `dispensing_sent`

**Status Updates Received from ESP32**:
```json
{
  "status": "gateway_online"
}
```
or
```json
{
  "status": "dispensing_sent"
}
```

## Setup Instructions

### 1. Install Dependencies
```bash
flutter pub get
```

The app now includes:
- `flutter_blue_plus: ^1.31.2` - BLE communication library

### 2. Android Configuration
- Permissions are already added to `AndroidManifest.xml`
- The app will request runtime permissions on first run (Android 12+)

### 3. Running the App
```bash
flutter run
```

### 4. Testing the Alarm

#### Prerequisites
- ESP32 with PillPal-Dispenser code running
- Device with Bluetooth capability
- Android device with Bluetooth enabled

#### Test Steps
1. Create a patient with medications and set alarm time
2. Wait for alarm time or manually trigger alarm
3. Check that alarm popup appears with BLE status
4. Verify "DISPENSE" button state:
   - ✅ **Blue/Active** if BLE is connected to ESP
   - ❌ **Gray/Disabled** if BLE is not connected
5. Press DISPENSE button
6. Check ESP32 Serial Monitor - should show: `Forwarding Dispense to Nano for Slot: 1`
7. Medication should dispense from the Nano device

## Debugging

### Check BLE Connection Status
The app logs BLE status in the console:
- ✅ "Starting BLE scan for PillPal-Dispenser..."
- ✅ "Found PillPal device: [MAC address]"
- ✅ "Connected! Discovering services..."
- ✅ "Successfully connected and ready!"

### Common Issues

**Issue**: "BLE is not supported on this device"
- **Solution**: Test on a device with Bluetooth capability

**Issue**: "DISPENSE button stays disabled"
- **Solution**: 
  - Check if ESP32 is powered on and advertising
  - Verify ESP32 device name is "PillPal-Dispenser"
  - Check Bluetooth is enabled on Android device
  - Check app permissions in Android Settings > Apps > PillPal > Permissions

**Issue**: "No Bluetooth scan results"
- **Solution**:
  - Grant BLUETOOTH_SCAN and ACCESS_FINE_LOCATION permissions
  - Check that ESP32 is advertising the service UUID
  - Restart the app

## File Changes Summary

| File | Changes |
|------|---------|
| `pubspec.yaml` | Added `flutter_blue_plus: ^1.31.2` |
| `lib/services/ble_service.dart` | **NEW** - BLE communication service |
| `lib/providers/service_providers.dart` | Added BLE service and providers |
| `lib/screens/alarm_popup.dart` | Updated to use BLE instead of MQTT |
| `lib/providers/alarm_queue_provider.dart` | Updated `dispense()` to use BLE |
| `android/app/src/main/AndroidManifest.xml` | Added BLE permissions |
| `lib/widgets/ble_connection_manager.dart` | **NEW** - BLE connection lifecycle management |
| `lib/utils/ble_permission_manager.dart` | **NEW** - BLE permission handling |
| `lib/main.dart` | Added BLE initialization and manager widget |

## Next Steps (Optional)

If you want to enhance the implementation further:

1. **Connection Indicator Widget**: Add a BLE status indicator in the top navigation bar
2. **Manual Device Selection**: Allow users to manually select ESP32 device if multiple are available
3. **Persistent Connection**: Keep BLE connection alive even when alarm is not active
4. **Error Handling**: Show user-friendly error messages if BLE operations fail
5. **Reconnection Logic**: Auto-reconnect if BLE connection drops
6. **Multiple ESP Devices**: Support multiple ESP dispensers (one per patient/location)

## Important Notes

- ✅ **Dispense button only clickable when BLE is connected** - This ensures medications are only dispensed when the system is ready
- ✅ **Background operation** - Alarm works when app is closed (handled by notification system)
- ✅ **No MQTT dependency removed** - MQTT service still exists for other features; you can use it alongside BLE
- ✅ **ESP code unchanged** - Works with your existing ESP32 code as-is

## Architecture Diagram

```
Alarm Triggers
    ↓
[AlarmPopup Widget] ← watches BLE connection status
    ↓
[DISPENSE Button] ← enabled only if BLE connected
    ↓
[BleService.sendDispenseCommand()]
    ↓
[ESP32 via BLE]
    ↓
[Serial to Nano] → Dispense medication
```
