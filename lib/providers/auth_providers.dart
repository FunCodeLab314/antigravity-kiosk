
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_providers.g.dart';

@Riverpod(keepAlive: true)
FirebaseAuth firebaseAuth(FirebaseAuthRef ref) {
  return FirebaseAuth.instance;
}

@Riverpod(keepAlive: true)
Stream<User?> authState(AuthStateRef ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
}

@riverpod
String? currentUserUid(CurrentUserUidRef ref) {
  final user = ref.watch(authStateProvider).value;
  return user?.uid;
}
