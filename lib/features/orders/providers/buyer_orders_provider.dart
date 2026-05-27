import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_provider.dart';
import '../domain/order_model.dart';
import '../../../core/constants/app_constants.dart';

/// Streams orders where the current user is the **buyer**, regardless of role.
///
/// Unlike [ordersProvider] (which auto-switches to vendor when applicable),
/// this provider is used in buyer-specific screens such as [OrdersPage].
///
/// Requires Firestore composite index:
///   orders → buyerId ASC, createdAt DESC
final buyerOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection(AppConstants.ordersCollection)
      .where('buyerId', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => OrderModel.fromMap(d.id, d.data())).toList());
});
