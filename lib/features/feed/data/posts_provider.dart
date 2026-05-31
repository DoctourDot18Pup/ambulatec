import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/post_model.dart';

/// Streams all active posts from Firestore, ordered by creation date desc.
/// Client-side filters out posts whose offer has already expired.
final postsProvider = StreamProvider<List<PostModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('posts')
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snap) {
        final now = DateTime.now();
        final list = snap.docs.map((doc) {
          final post = PostModel.fromMap(doc.id, doc.data());
          if (post.hasOffer &&
              post.offerExpiresAt != null &&
              now.isAfter(post.offerExpiresAt!)) {
            return post.copyWith(hasOffer: false, offerType: null);
          }
          return post;
        }).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
});
