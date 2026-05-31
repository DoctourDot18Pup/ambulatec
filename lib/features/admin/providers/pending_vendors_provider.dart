import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/domain/user_model.dart';

/// Streams [UserModel]s whose [VendorStatus] is `pending`.
///
/// Only intended for admin users (`isAdmin == true`).
///
/// Sorts by `createdAt` desc **client-side** instead of via `orderBy`, so the
/// query needs no composite index. With the index requirement, the snapshot
/// would only resolve from local cache and then stall/error on the server
/// round-trip — the cause of the slow admin panel (Prueba 8).
final pendingVendorsProvider =
    StreamProvider<List<UserModel>>((ref) {
  return FirebaseFirestore.instance
      .collection(AppConstants.usersCollection)
      .where('vendorStatus', isEqualTo: VendorStatus.pending.name)
      .snapshots()
      .map((snap) {
        final list = snap.docs
            .map((d) => UserModel.fromMap({'uid': d.id, ...d.data()}))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
});
