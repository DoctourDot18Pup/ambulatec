import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../domain/review_model.dart';

/// Streams all [ReviewModel]s for a given vendor, ordered newest-first.
///
/// Usage:
/// ```dart
/// final reviews = ref.watch(vendorReviewsProvider(vendorId));
/// ```
final vendorReviewsProvider = StreamProvider.autoDispose
    .family<List<ReviewModel>, String>((ref, vendorId) {
  if (vendorId.isEmpty) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection(AppConstants.reviewsCollection)
      .where('vendorId', isEqualTo: vendorId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => ReviewModel.fromMap(d.data(), d.id))
          .toList());
});
