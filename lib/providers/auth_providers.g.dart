// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$firebaseAuthHash() => r'46c40b7c5cf8ab936c0daa96a6af106bd2ae5d51';

/// See also [firebaseAuth].
@ProviderFor(firebaseAuth)
final firebaseAuthProvider = Provider<FirebaseAuth>.internal(
  firebaseAuth,
  name: r'firebaseAuthProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$firebaseAuthHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef FirebaseAuthRef = ProviderRef<FirebaseAuth>;
String _$authStateHash() => r'b01d14771c53293e435df7f6d28884edabc46d2f';

/// See also [authState].
@ProviderFor(authState)
final authStateProvider = StreamProvider<User?>.internal(
  authState,
  name: r'authStateProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$authStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AuthStateRef = StreamProviderRef<User?>;
String _$currentUserUidHash() => r'18c20bbec755d81b9f32f62901f745f975202a46';

/// See also [currentUserUid].
@ProviderFor(currentUserUid)
final currentUserUidProvider = AutoDisposeProvider<String?>.internal(
  currentUserUid,
  name: r'currentUserUidProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentUserUidHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef CurrentUserUidRef = AutoDisposeProviderRef<String?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
