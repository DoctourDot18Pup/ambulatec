import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/post_model.dart';
import 'posts_provider.dart';
import 'category_filter_provider.dart';
import 'following_provider.dart';

/// Combines the raw posts stream with the active category filter and the
/// followed-vendors list.
///
/// Sort order:
///   1. Posts from followed vendors first.
///   2. Within each group: most recently created first.
final filteredPostsProvider = Provider<AsyncValue<List<PostModel>>>((ref) {
  final postsAsync = ref.watch(postsProvider);
  final filter = ref.watch(categoryFilterProvider);
  final followingAsync = ref.watch(followingProvider);

  return postsAsync.when(
    loading: () => const AsyncLoading(),
    error: (e, st) => AsyncError(e, st),
    data: (posts) {
      // Apply category filter.
      final filtered = filter == 'todos'
          ? posts
          : posts.where((p) => p.category == filter).toList();

      // Sort: followed vendors first, then by date desc.
      final following = followingAsync.asData?.value ?? [];
      final followedSet = following.toSet();

      filtered.sort((a, b) {
        final aFollowed = followedSet.contains(a.vendorId) ? 0 : 1;
        final bFollowed = followedSet.contains(b.vendorId) ? 0 : 1;
        if (aFollowed != bFollowed) return aFollowed.compareTo(bFollowed);
        return b.createdAt.compareTo(a.createdAt);
      });

      return AsyncData(filtered);
    },
  );
});
