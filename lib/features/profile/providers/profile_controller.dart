import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/cloudinary_service.dart';

final profileControllerProvider = NotifierProvider.autoDispose<
    ProfileController, AsyncValue<void>>(ProfileController.new);

class ProfileController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Updates [displayName] and, if provided, uploads [imageBytes] to
  /// Cloudinary and stores the resulting URL as [photoUrl].
  ///
  /// Writes only to Firestore. The [userProvider] StreamProvider picks up the
  /// change automatically and propagates it app-wide.
  Future<void> updateProfile({
    required String uid,
    required String displayName,
    Uint8List? imageBytes,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      String? photoUrl;

      if (imageBytes != null) {
        photoUrl = await CloudinaryService()
            .uploadImage(imageBytes, 'avatars/$uid');
      }

      final updates = <String, dynamic>{'displayName': displayName.trim()};
      if (photoUrl != null) updates['photoUrl'] = photoUrl;

      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .update(updates);

      // Keep Firebase Auth profile in sync (used by displayName/photoURL getters
      // on FirebaseAuth.instance.currentUser elsewhere in the app).
      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser != null) {
        await fbUser.updateDisplayName(displayName.trim());
        if (photoUrl != null) await fbUser.updatePhotoURL(photoUrl);
      }
    });
  }
}
