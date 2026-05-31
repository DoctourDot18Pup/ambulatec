import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_provider.dart';
import '../../feed/domain/post_model.dart';
import '../../../core/constants/app_constants.dart';

/// Streams the posts created by the currently authenticated vendor,
/// ordered by creation date descending.
final vendorPostsProvider = StreamProvider<List<PostModel>>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection(AppConstants.postsCollection)
      .where('vendorId', isEqualTo: user.uid)
      .snapshots()
      .map((snap) {
        final list = snap.docs
            .map((d) => PostModel.fromMap(d.id, d.data()))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
});
