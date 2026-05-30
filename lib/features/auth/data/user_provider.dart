import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/user_model.dart';
import '../../../core/constants/app_constants.dart';
import 'auth_provider.dart';

/// Reactive stream of the currently authenticated user's Firestore document.
///
/// Depends on [authStateProvider]; emits `null` when unauthenticated or when
/// the document does not yet exist.
///
/// Stream errors (e.g. transient Firestore connection resets) are converted to
/// a `null` emission so the [StreamProvider] never transitions to [AsyncError],
/// keeping the router's loading guard intact until the connection recovers.
final userProvider = StreamProvider<UserModel?>((ref) {
  final authValue = ref.watch(authStateProvider);
  final firebaseUser = authValue.asData?.value;

  if (firebaseUser == null) return Stream.value(null);

  final controller = StreamController<UserModel?>();

  final sub = FirebaseFirestore.instance
      .collection(AppConstants.usersCollection)
      .doc(firebaseUser.uid)
      .snapshots()
      .listen(
    (doc) {
      if (!doc.exists || doc.data() == null) {
        controller.add(null);
      } else {
        try {
          controller.add(UserModel.fromMap({'uid': doc.id, ...doc.data()!}));
        } catch (_) {
          controller.add(null);
        }
      }
    },
    onError: (Object e) {
      // Emit null on transient errors so the stream stays open and the
      // Firestore SDK can recover on its own reconnect cycle.
      controller.add(null);
    },
    onDone: () => controller.close(),
    cancelOnError: false,
  );

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});
