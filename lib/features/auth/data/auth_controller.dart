import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import '../domain/user_model.dart';
import '../domain/vendor_verification_data.dart';
import '../../../core/constants/app_constants.dart';

final authControllerProvider =
    NotifierProvider<AuthController, AsyncValue<void>>(AuthController.new);

/// Handles all authentication and user-document mutations.
///
/// The state is an [AsyncValue<void>] so callers can react to loading and
/// error conditions without holding any UI-coupled state here.
class AuthController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return; // User dismissed the dialog.

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) return;

      // Create the Firestore document on first sign-in.
      final userRef = FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid);

      final snapshot = await userRef.get();
      if (!snapshot.exists) {
        await userRef.set(
          UserModel(
            uid: user.uid,
            displayName: user.displayName ?? '',
            email: user.email ?? '',
            photoUrl: user.photoURL,
            roles: [],
            vendorStatus: null,
            createdAt: DateTime.now(),
            onboardingCompleted: true,
          ).toMap(),
        );
      }
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
    });
  }

  /// Assigns roles to the authenticated user.
  ///
  /// If [roles] contains `'vendor'`, sets [VendorStatus.pending] so the
  /// router redirects to the verification flow.
  Future<void> setRoles(List<String> roles) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No hay usuario autenticado.');

      final updates = <String, dynamic>{'roles': roles};
      if (roles.contains('vendor')) {
        updates['vendorStatus'] = VendorStatus.pending.name;
      }

      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .update(updates);
    });
  }

  /// Uploads ID images and saves the verification request to Firestore.
  Future<void> submitVendorVerification(VendorVerificationData data) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No hay usuario autenticado.');

      // Upload images using cross-platform XFile.readAsBytes().
      final storageBase = FirebaseStorage.instance
          .ref(AppConstants.vendorIdStoragePath)
          .child(user.uid);

      final ts = DateTime.now().millisecondsSinceEpoch;
      final frontRef = storageBase.child('front_$ts.jpg');
      final backRef = storageBase.child('back_$ts.jpg');

      final frontBytes = await XFile(data.idFrontPath).readAsBytes();
      final backBytes = await XFile(data.idBackPath).readAsBytes();

      await frontRef.putData(frontBytes);
      await backRef.putData(backBytes);

      final frontUrl = await frontRef.getDownloadURL();
      final backUrl = await backRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .update({
        'vendorStatus': VendorStatus.pending.name,
        'vendorVerification': {
          'fullName': data.fullName,
          'career': data.career,
          'controlNumber': data.controlNumber,
          'idFrontUrl': frontUrl,
          'idBackUrl': backUrl,
          'submittedAt': FieldValue.serverTimestamp(),
        },
      });
    });
  }

  /// Updates the vendor's live availability status.
  ///
  /// [availability] must be one of: 'active', 'busy', 'offline'.
  Future<void> setVendorAvailability(String availability) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No hay usuario autenticado.');

      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .update({'vendorAvailability': availability});
    });
  }
}
