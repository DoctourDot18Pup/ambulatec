import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/domain/user_model.dart';
import '../domain/post_model.dart';

// ── Models ─────────────────────────────────────────────────────────────────

class SearchResults {
  final List<PostModel> posts;
  final List<UserModel> vendors;
  const SearchResults({required this.posts, required this.vendors});
  bool get isEmpty => posts.isEmpty && vendors.isEmpty;
}

// ── Query provider ─────────────────────────────────────────────────────────

/// The text the user has typed in the search bar.
final searchQueryProvider = StateProvider<String>((ref) => '');

// ── Results provider ───────────────────────────────────────────────────────

/// Searches posts (by title prefix) and vendors (by displayName prefix).
///
/// **Debounce:** implemented by awaiting 300 ms before the Firestore calls.
/// If [searchQueryProvider] changes before 300 ms elapses, Riverpod
/// re-creates this autoDispose provider and cancels the previous future,
/// preventing unnecessary Firestore reads.
///
/// **Limitation:** Firestore prefix search is case-sensitive and only matches
/// strings that *start with* the query. For full-text search, integrate
/// Algolia or Typesense (noted in README as a future improvement).
///
/// Requires Firestore index:
///   posts → title ASC (single-field index, usually created automatically)
final searchResultsProvider =
    FutureProvider.autoDispose<SearchResults>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();

  if (query.length < 2) {
    return const SearchResults(posts: [], vendors: []);
  }

  // 300 ms debounce — cancel if query changes before this resolves.
  await Future.delayed(const Duration(milliseconds: 300));

  final endQuery = '$query'; // Unicode sentinel for prefix range

  // Run both queries in parallel.
  final results = await Future.wait([
    // Posts: prefix match on title, filter inactive client-side
    FirebaseFirestore.instance
        .collection(AppConstants.postsCollection)
        .where('title', isGreaterThanOrEqualTo: query)
        .where('title', isLessThanOrEqualTo: endQuery)
        .limit(10)
        .get(),

    // Vendors: prefix match on displayName, filter role client-side
    FirebaseFirestore.instance
        .collection(AppConstants.usersCollection)
        .where('displayName', isGreaterThanOrEqualTo: query)
        .where('displayName', isLessThanOrEqualTo: endQuery)
        .limit(10)
        .get(),
  ]);

  final posts = results[0].docs
      .map((d) => PostModel.fromMap(d.id, d.data()))
      .where((p) => p.isActive)
      .toList();

  final vendors = results[1].docs
      .map((d) => UserModel.fromMap({
            'uid': d.id,
            ...d.data(),
          }))
      .where((u) =>
          u.roles.contains('vendor') &&
          u.vendorStatus == VendorStatus.approved)
      .take(5)
      .toList();

  return SearchResults(posts: posts, vendors: vendors);
});

// ── Active vendors (for initial state chip list) ───────────────────────────

/// Approved vendors shown in the horizontal chip strip when the search bar
/// is empty.
final activeVendorsProvider = StreamProvider.autoDispose<List<UserModel>>((ref) {
  return FirebaseFirestore.instance
      .collection(AppConstants.usersCollection)
      .where('vendorStatus', isEqualTo: VendorStatus.approved.name)
      .limit(15)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => UserModel.fromMap({'uid': d.id, ...d.data()}))
          .where((u) => u.roles.contains('vendor'))
          .toList());
});
