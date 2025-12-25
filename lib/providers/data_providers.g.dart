// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$patientsHash() => r'b2112748c23b2e147ec705475859d9bb234aafdb';

/// See also [patients].
@ProviderFor(patients)
final patientsProvider = AutoDisposeStreamProvider<List<Patient>>.internal(
  patients,
  name: r'patientsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$patientsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef PatientsRef = AutoDisposeStreamProviderRef<List<Patient>>;
String _$patientsListHash() => r'0cd0544fdfb7534a7db469180439c6fecc11b2eb';

/// See also [patientsList].
@ProviderFor(patientsList)
final patientsListProvider = AutoDisposeProvider<List<Patient>>.internal(
  patientsList,
  name: r'patientsListProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$patientsListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef PatientsListRef = AutoDisposeProviderRef<List<Patient>>;
String _$mqttStatusHash() => r'7ab33eebb3a33ed482729fd14dca2c066c91990e';

/// See also [mqttStatus].
@ProviderFor(mqttStatus)
final mqttStatusProvider =
    AutoDisposeStreamProvider<MqttConnectionStatus>.internal(
  mqttStatus,
  name: r'mqttStatusProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$mqttStatusHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef MqttStatusRef = AutoDisposeStreamProviderRef<MqttConnectionStatus>;
String _$mqttIsConnectedHash() => r'503567e37323b13069ff5f56d0f7fdcb1719b511';

/// See also [mqttIsConnected].
@ProviderFor(mqttIsConnected)
final mqttIsConnectedProvider = AutoDisposeProvider<bool>.internal(
  mqttIsConnected,
  name: r'mqttIsConnectedProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$mqttIsConnectedHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef MqttIsConnectedRef = AutoDisposeProviderRef<bool>;
String _$patientAlarmSyncHash() => r'52444e9e22197d9558f65739c110634da3da881a';

/// Synchronization provider to bridge Firestore data, Auth, AlarmService, and Notifications
///
/// Copied from [patientAlarmSync].
@ProviderFor(patientAlarmSync)
final patientAlarmSyncProvider = AutoDisposeProvider<void>.internal(
  patientAlarmSync,
  name: r'patientAlarmSyncProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$patientAlarmSyncHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef PatientAlarmSyncRef = AutoDisposeProviderRef<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
