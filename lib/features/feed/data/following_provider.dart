import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_provider.dart';

/// Streams the list of vendor IDs the current user follows.
/// Returns an empty list when not signed in.
final followingProvider = StreamProvider<List<String>>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.asData?.value;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('following')
      .snapshots()
      .map((snap) => snap.docs.map((d) => d.id).toList());
});
