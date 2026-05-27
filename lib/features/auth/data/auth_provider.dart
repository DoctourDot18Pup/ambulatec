import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reactive stream of the Firebase Authentication state.
///
/// Returns `null` when no user is signed in or when Firebase is not yet
/// configured (the [UnimplementedError] from the placeholder
/// [DefaultFirebaseOptions] is caught and treated as unauthenticated).
final authStateProvider = StreamProvider<User?>((ref) {
  try {
    return FirebaseAuth.instance.authStateChanges();
  } catch (_) {
    return Stream.value(null);
  }
});
