import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_provider.dart';
import '../domain/follow_model.dart';

// ── Controller ─────────────────────────────────────────────────────────────

class FollowController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> toggleFollow(String vendorId) async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final followRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .doc(vendorId);

      final snap = await followRef.get();
      if (snap.exists) {
        await followRef.delete();
      } else {
        final model = FollowModel(
          vendorId: vendorId,
          followedAt: DateTime.now(),
        );
        await followRef.set(model.toMap());
      }
    });
  }
}

final followControllerProvider =
    NotifierProvider<FollowController, AsyncValue<void>>(
        FollowController.new);
