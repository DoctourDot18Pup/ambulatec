import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/post_model.dart';

/// Streams all active posts from Firestore, ordered by creation date desc.
/// Client-side filters out posts whose offer has already expired.
final postsProvider = StreamProvider<List<PostModel>>((ref) {
  final query = FirebaseFirestore.instance
      .collection('posts')
      .where('isActive', isEqualTo: true)
      .orderBy('createdAt', descending: true);

  return query.snapshots().map((snap) {
    final now = DateTime.now();
    return snap.docs
        .map((doc) => PostModel.fromMap(doc.id, doc.data()))
        .where((post) {
          // If offer has an expiry and it's passed, treat the post as non-offered
          // but still show it (active). We do NOT hide the post.
          return true;
        })
        .map((post) {
          // Auto-expire offer on client side so the badge disappears.
          if (post.hasOffer &&
              post.offerExpiresAt != null &&
              now.isAfter(post.offerExpiresAt!)) {
            return post.copyWith(hasOffer: false, offerType: null);
          }
          return post;
        })
        .toList();
  });
});
