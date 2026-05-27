import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/user_provider.dart';
import '../domain/order_model.dart';
import '../../../core/constants/app_constants.dart';

/// Streams orders for the current user.
///
/// - If the user is a **vendor** (approved), returns orders where
///   `vendorId == uid`, ordered by `createdAt` desc.
/// - Otherwise returns orders where `buyerId == uid`.
final ordersProvider = StreamProvider<List<OrderModel>>((ref) {
  final userAsync = ref.watch(userProvider);
  final user = userAsync.asData?.value;
  if (user == null) return Stream.value([]);

  final uid = user.uid;
  final isVendor = user.roles.contains('vendor');

  final query = FirebaseFirestore.instance
      .collection(AppConstants.ordersCollection)
      .where(isVendor ? 'vendorId' : 'buyerId', isEqualTo: uid)
      .orderBy('createdAt', descending: true);

  return query.snapshots().map((snap) =>
      snap.docs.map((d) => OrderModel.fromMap(d.id, d.data())).toList());
});
