import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/user_model.dart';
import '../../../core/constants/app_constants.dart';
import 'auth_provider.dart';

/// Reactive stream of the currently authenticated user's Firestore document.
///
/// Depends on [authStateProvider]; emits `null` when unauthenticated or when
/// the document does not yet exist.
final userProvider = StreamProvider<UserModel?>((ref) {
  final authValue = ref.watch(authStateProvider);
  final firebaseUser = authValue.asData?.value;

  if (firebaseUser == null) return Stream.value(null);

  try {
    return FirebaseFirestore.instance
        .collection(AppConstants.usersCollection)
        .doc(firebaseUser.uid)
        .snapshots()
        .map((doc) {
          if (!doc.exists || doc.data() == null) return null;
          return UserModel.fromMap({'uid': doc.id, ...doc.data()!});
        });
  } catch (_) {
    return Stream.value(null);
  }
});
