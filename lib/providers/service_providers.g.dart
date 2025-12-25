// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$firestoreServiceHash() => r'd7a14e8468436c9c7998493c91fea3a6f785c799';

/// See also [firestoreService].
@ProviderFor(firestoreService)
final firestoreServiceProvider = Provider<FirestoreService>.internal(
  firestoreService,
  name: r'firestoreServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$firestoreServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef FirestoreServiceRef = ProviderRef<FirestoreService>;
String _$reportServiceHash() => r'5a20de1e194c1fea9d97e73ea7cd02f143bb45fb';

/// See also [reportService].
@ProviderFor(reportService)
final reportServiceProvider = Provider<ReportService>.internal(
  reportService,
  name: r'reportServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$reportServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ReportServiceRef = ProviderRef<ReportService>;
String _$mqttServiceHash() => r'51e02e439a110c9a343ed4a141a28359c388e09d';

/// See also [mqttService].
@ProviderFor(mqttService)
final mqttServiceProvider = Provider<MqttService>.internal(
  mqttService,
  name: r'mqttServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$mqttServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef MqttServiceRef = ProviderRef<MqttService>;
String _$notificationServiceHash() =>
    r'015117d47fe71bf44664bf802ad1290b1e2492d4';

/// See also [notificationService].
@ProviderFor(notificationService)
final notificationServiceProvider = Provider<NotificationService>.internal(
  notificationService,
  name: r'notificationServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$notificationServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef NotificationServiceRef = ProviderRef<NotificationService>;
String _$audioServiceHash() => r'ee4410d8ac91f122266dda12cfa0b5e5a091a335';

/// See also [audioService].
@ProviderFor(audioService)
final audioServiceProvider = Provider<AudioService>.internal(
  audioService,
  name: r'audioServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$audioServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AudioServiceRef = ProviderRef<AudioService>;
String _$alarmServiceHash() => r'dcc2117bf269ebb30238903577a1286f856c815d';

/// See also [alarmService].
@ProviderFor(alarmService)
final alarmServiceProvider = Provider<AlarmService>.internal(
  alarmService,
  name: r'alarmServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$alarmServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AlarmServiceRef = ProviderRef<AlarmService>;
String _$bleServiceHash() => r'a45cc3a107771a38d7ab0f8433bd2cbd5faf7dbb';

/// See also [bleService].
@ProviderFor(bleService)
final bleServiceProvider = Provider<BleService>.internal(
  bleService,
  name: r'bleServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$bleServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef BleServiceRef = ProviderRef<BleService>;
String _$bleConnectionStateHash() =>
    r'e0d6bb7ce55981c37d1302a3e83fca84dee40ab1';

/// Stream provider for BLE connection state
///
/// Copied from [bleConnectionState].
@ProviderFor(bleConnectionState)
final bleConnectionStateProvider = StreamProvider<bool>.internal(
  bleConnectionState,
  name: r'bleConnectionStateProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$bleConnectionStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef BleConnectionStateRef = StreamProviderRef<bool>;
String _$bleIsConnectedHash() => r'e6f55aa389f37331664e20bad69c956045e8f2fd';

/// Simple provider to check if BLE is currently connected
///
/// Copied from [bleIsConnected].
@ProviderFor(bleIsConnected)
final bleIsConnectedProvider = Provider<bool>.internal(
  bleIsConnected,
  name: r'bleIsConnectedProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$bleIsConnectedHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef BleIsConnectedRef = ProviderRef<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
