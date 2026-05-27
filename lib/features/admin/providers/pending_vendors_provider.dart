import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/domain/user_model.dart';

/// Streams [UserModel]s whose [VendorStatus] is `pending`.
///
/// Only intended for admin users (`isAdmin == true`).
/// Requires a Firestore composite index on `vendorStatus` if combined
/// with an `orderBy` — add it via the Firebase Console link in the error
/// message on first run, or simply create:
///   Collection: users | Field: vendorStatus ASC, createdAt DESC
final pendingVendorsProvider =
    StreamProvider<List<UserModel>>((ref) {
  return FirebaseFirestore.instance
      .collection(AppConstants.usersCollection)
      .where('vendorStatus', isEqualTo: VendorStatus.pending.name)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => UserModel.fromMap({'uid': d.id, ...d.data()}))
          .toList());
});
