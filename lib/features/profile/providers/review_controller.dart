import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../domain/review_model.dart';

// ── Notifier ───────────────────────────────────────────────────────────────

class ReviewNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Persists [review] to Firestore and recalculates the vendor's
  /// average rating and total review count.
  Future<void> submitReview(ReviewModel review) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // 1. Write the review document.
      await FirebaseFirestore.instance
          .collection(AppConstants.reviewsCollection)
          .add(review.toMap());

      // 2. Re-read all reviews for this vendor to recalculate the average.
      //    This is a simple approach suitable for low-volume apps; for
      //    production at scale, use a Cloud Function with a counter document.
      final snap = await FirebaseFirestore.instance
          .collection(AppConstants.reviewsCollection)
          .where('vendorId', isEqualTo: review.vendorId)
          .get();

      final ratings = snap.docs
          .map((d) => d.data()['rating'] as int? ?? 0)
          .toList();

      final avg = ratings.isEmpty
          ? 0.0
          : ratings.reduce((a, b) => a + b) / ratings.length;

      // 3. Update the vendor's user document.
      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(review.vendorId)
          .update({
        'vendorRating': double.parse(avg.toStringAsFixed(1)),
        'totalReviews': ratings.length,
      });
    });
  }

  /// Returns `true` if a review for [orderId] already exists in Firestore.
  Future<bool> hasReviewed(String orderId) async {
    final snap = await FirebaseFirestore.instance
        .collection(AppConstants.reviewsCollection)
        .where('orderId', isEqualTo: orderId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }
}

// ── Provider ───────────────────────────────────────────────────────────────

final reviewControllerProvider =
    NotifierProvider<ReviewNotifier, AsyncValue<void>>(ReviewNotifier.new);
