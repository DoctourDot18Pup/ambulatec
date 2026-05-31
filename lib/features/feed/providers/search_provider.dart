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

class _SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void update(String value) => state = value;
}

/// The text the user has typed in the search bar.
final searchQueryProvider =
    NotifierProvider<_SearchQueryNotifier, String>(_SearchQueryNotifier.new);

// ── Results provider ───────────────────────────────────────────────────────

/// Searches posts and vendors by **case-insensitive substring** match.
///
/// **Approach:** fetches active posts and approved vendors (capped), then
/// filters client-side with `toLowerCase().contains(query)`. Unlike Firestore
/// prefix ranges, this matches anywhere in the string ("birria" finds
/// "TACOS DE BIRRIA") and is case-insensitive, with no composite index and no
/// extra stored field — ideal for the demo's catalog size.
///
/// **Debounce:** awaits 300 ms before querying. If [searchQueryProvider]
/// changes first, Riverpod re-creates this autoDispose provider and cancels
/// the previous future.
///
/// **Scale note:** for a large catalog, move to Algolia/Typesense or a
/// `titleLower` prefix field (documented as a future improvement in README).
final searchResultsProvider =
    FutureProvider.autoDispose<SearchResults>((ref) async {
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();

  if (query.length < 2) {
    return const SearchResults(posts: [], vendors: []);
  }

  // 300 ms debounce — cancel if query changes before this resolves.
  await Future.delayed(const Duration(milliseconds: 300));

  // Fetch candidates in parallel (capped for the demo's catalog size).
  final results = await Future.wait([
    FirebaseFirestore.instance
        .collection(AppConstants.postsCollection)
        .where('isActive', isEqualTo: true)
        .limit(100)
        .get(),
    FirebaseFirestore.instance
        .collection(AppConstants.usersCollection)
        .where('vendorStatus', isEqualTo: VendorStatus.approved.name)
        .limit(100)
        .get(),
  ]);

  // Posts: match on title, vendor name or category (case-insensitive).
  final posts = results[0]
      .docs
      .map((d) => PostModel.fromMap(d.id, d.data()))
      .where((p) =>
          p.title.toLowerCase().contains(query) ||
          p.vendorName.toLowerCase().contains(query) ||
          p.category.toLowerCase().contains(query))
      .take(15)
      .toList();

  // Vendors: match on display name (case-insensitive).
  final vendors = results[1]
      .docs
      .map((d) => UserModel.fromMap({
            'uid': d.id,
            ...d.data(),
          }))
      .where((u) =>
          u.roles.contains('vendor') &&
          u.vendorStatus == VendorStatus.approved &&
          u.displayName.toLowerCase().contains(query))
      .take(10)
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
