import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/rating_stars_widget.dart';
import '../../../shared/widgets/status_dot_widget.dart';
import '../../auth/data/auth_provider.dart';
import '../../auth/domain/user_model.dart';
import '../../feed/data/follow_controller.dart';
import '../../feed/data/following_provider.dart';
import '../../feed/domain/post_model.dart';
import '../domain/review_model.dart';
import '../providers/vendor_reviews_provider.dart';

// ── Page-scoped providers ──────────────────────────────────────────────────

final _vendorByIdProvider =
    FutureProvider.autoDispose.family<UserModel?, String>((ref, vendorId) async {
  if (vendorId.isEmpty) return null;
  final doc = await FirebaseFirestore.instance
      .collection(AppConstants.usersCollection)
      .doc(vendorId)
      .get();
  if (!doc.exists || doc.data() == null) return null;
  return UserModel.fromMap({'uid': doc.id, ...doc.data()!});
});

final _vendorActivePostsProvider =
    StreamProvider.autoDispose.family<List<PostModel>, String>((ref, vendorId) {
  if (vendorId.isEmpty) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection(AppConstants.postsCollection)
      .where('vendorId', isEqualTo: vendorId)
      .where('isActive', isEqualTo: true)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => PostModel.fromMap(d.id, d.data())).toList());
});

// ── Page ───────────────────────────────────────────────────────────────────

class VendorProfilePage extends ConsumerWidget {
  final String vendorId;
  const VendorProfilePage({super.key, required this.vendorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorAsync = ref.watch(_vendorByIdProvider(vendorId));

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        leading: BackButton(color: AppColors.textPrimary),
        title: vendorAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (vendor) => Text(
            vendor?.displayName ?? '',
            style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
          ),
        ),
      ),
      body: vendorAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accentGold)),
        error: (e, _) => Center(
            child: Text('$e',
                style: AppTextStyles.body.copyWith(color: AppColors.error))),
        data: (vendor) {
          if (vendor == null) {
            return const EmptyStateWidget(
              icon: Icons.person_off_outlined,
              title: 'Vendedor no encontrado',
            );
          }
          return _VendorBody(vendor: vendor);
        },
      ),
    );
  }
}

// ── Body ───────────────────────────────────────────────────────────────────

class _VendorBody extends ConsumerWidget {
  final UserModel vendor;
  const _VendorBody({required this.vendor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(_vendorActivePostsProvider(vendor.uid));
    final reviewsAsync = ref.watch(vendorReviewsProvider(vendor.uid));
    final followingAsync = ref.watch(followingProvider);
    final currentUser = ref.watch(authStateProvider).asData?.value;

    final isFollowing =
        (followingAsync.asData?.value ?? []).contains(vendor.uid);
    final isSelf = currentUser?.uid == vendor.uid;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;
        return Center(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: isDesktop ? 760 : double.infinity),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Header card ──────────────────────────────────────────
                _HeaderCard(
                  vendor: vendor,
                  isFollowing: isFollowing,
                  isSelf: isSelf,
                  onFollow: isSelf
                      ? null
                      : () => ref
                          .read(followControllerProvider.notifier)
                          .toggleFollow(vendor.uid),
                ),
                const SizedBox(height: 24),

                // ── Active posts ─────────────────────────────────────────
                Text('PUBLICACIONES ACTIVAS',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                postsAsync.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accentGold)),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (posts) => posts.isEmpty
                      ? const EmptyStateWidget(
                          icon: Icons.storefront_outlined,
                          title: 'Sin publicaciones activas',
                        )
                      : _PostsGrid(posts: posts),
                ),
                const SizedBox(height: 24),

                // ── Reviews ──────────────────────────────────────────────
                reviewsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (reviews) {
                    if (reviews.isEmpty) return const SizedBox.shrink();
                    return isSelf
                        ? _VendorReviewsSection(reviews: reviews)
                        : _BuyerReviewsSection(
                            reviews: reviews,
                            vendorName: vendor.displayName,
                            onShowAll: () => _showAllReviews(
                                context, reviews, vendor.displayName),
                          );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAllReviews(
      BuildContext context, List<ReviewModel> reviews, String name) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, ctrl) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Reseñas de $name',
                style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: reviews.length,
                itemBuilder: (_, i) => _ReviewTile(review: reviews[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header card ────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final UserModel vendor;
  final bool isFollowing;
  final bool isSelf;
  final VoidCallback? onFollow;

  const _HeaderCard({
    required this.vendor,
    required this.isFollowing,
    required this.isSelf,
    required this.onFollow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOverlay),
      ),
      child: Column(
        children: [
          // ── Avatar + status ──────────────────────────────────────────
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.accentGreen,
                backgroundImage: vendor.photoUrl != null
                    ? NetworkImage(vendor.photoUrl!)
                    : null,
                child: vendor.photoUrl == null
                    ? Text(
                        vendor.displayName.isNotEmpty
                            ? vendor.displayName[0].toUpperCase()
                            : '?',
                        style: AppTextStyles.h1
                            .copyWith(color: Colors.white, fontSize: 32),
                      )
                    : null,
              ),
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bgCard, width: 2),
                  ),
                  child: StatusDotWidget(
                      status: vendor.vendorAvailability, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Name ─────────────────────────────────────────────────────
          Text(
            vendor.displayName,
            style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // ── Rating ───────────────────────────────────────────────────
          if (vendor.vendorRating > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RatingStarsWidget(rating: vendor.vendorRating, size: 14),
                const SizedBox(width: 6),
                Text(
                  '${vendor.vendorRating.toStringAsFixed(1)} · ${vendor.totalReviews} reseñas',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 8),

          // ── Follow button ────────────────────────────────────────────
          if (!isSelf)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: onFollow,
                icon: Icon(
                  isFollowing ? Icons.check : Icons.add,
                  size: 18,
                ),
                label: Text(isFollowing ? 'Siguiendo' : 'Seguir'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isFollowing
                      ? AppColors.textSecondary
                      : AppColors.accentGold,
                  side: BorderSide(
                    color: isFollowing
                        ? AppColors.textSecondary
                        : AppColors.accentGold,
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Posts grid ─────────────────────────────────────────────────────────────

class _PostsGrid extends StatelessWidget {
  final List<PostModel> posts;
  const _PostsGrid({required this.posts});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: posts.length,
      itemBuilder: (context, i) => _CompactPostCard(post: posts[i]),
    );
  }
}

class _CompactPostCard extends StatelessWidget {
  final PostModel post;
  const _CompactPostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/post/${post.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderOverlay),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: post.mediaUrls.isNotEmpty
                  ? Image.network(
                      post.mediaUrls.first,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppColors.bgCard,
                        child: const Icon(Icons.image_outlined,
                            color: AppColors.textSecondary),
                      ),
                    )
                  : Container(
                      color: AppColors.bgCard,
                      child: const Icon(Icons.image_outlined,
                          color: AppColors.textSecondary),
                    ),
            ),
            // Title + price
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\$${post.price.toStringAsFixed(post.price % 1 == 0 ? 0 : 2)}',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.accentGold,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Buyer reviews section ──────────────────────────────────────────────────

/// Overview seen by any user viewing someone else's profile.
/// Shows aggregate: avg stars, total count, tag frequency bars.
class _BuyerReviewsSection extends StatelessWidget {
  final List<ReviewModel> reviews;
  final String vendorName;
  final VoidCallback onShowAll;

  const _BuyerReviewsSection({
    required this.reviews,
    required this.vendorName,
    required this.onShowAll,
  });

  @override
  Widget build(BuildContext context) {
    final avg = reviews.map((r) => r.rating).reduce((a, b) => a + b) /
        reviews.length;

    // Count tag frequency
    final tagCounts = <String, int>{};
    for (final r in reviews) {
      for (final t in r.tags) {
        tagCounts[t] = (tagCounts[t] ?? 0) + 1;
      }
    }
    final sortedTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topTags = sortedTags.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('RESEÑAS',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
            const Spacer(),
            if (reviews.length > 3)
              GestureDetector(
                onTap: onShowAll,
                child: Text('Ver todas (${reviews.length})',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.accentGold)),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Aggregate card ───────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderOverlay),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    avg.toStringAsFixed(1),
                    style: AppTextStyles.h1.copyWith(
                        color: AppColors.accentGold, fontSize: 42),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RatingStarsWidget(rating: avg, size: 18),
                      const SizedBox(height: 2),
                      Text('${reviews.length} reseñas',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
              if (topTags.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(color: AppColors.borderOverlay, height: 1),
                const SizedBox(height: 14),
                ...topTags.map((e) => _TagBar(
                      label: e.key,
                      count: e.value,
                      total: reviews.length,
                    )),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Latest 3 reviews ─────────────────────────────────────────
        ...reviews.take(3).map((r) => _ReviewTile(review: r)),
      ],
    );
  }
}

// ── Vendor reviews section ─────────────────────────────────────────────────

/// Detailed per-order reviews seen only by the vendor on their own profile.
class _VendorReviewsSection extends StatelessWidget {
  final List<ReviewModel> reviews;
  const _VendorReviewsSection({required this.reviews});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MIS RESEÑAS',
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        ...reviews.map((r) => _VendorReviewTile(review: r)),
      ],
    );
  }
}

class _VendorReviewTile extends StatelessWidget {
  final ReviewModel review;
  const _VendorReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOverlay),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Order title + rating ──────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  review.postTitle.isNotEmpty ? review.postTitle : 'Pedido',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              RatingStarsWidget(rating: review.rating.toDouble(), size: 13),
            ],
          ),
          const SizedBox(height: 6),

          // ── Buyer + date ──────────────────────────────────────────
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.accentGreen,
                backgroundImage: review.buyerPhotoUrl.isNotEmpty
                    ? NetworkImage(review.buyerPhotoUrl)
                    : null,
                child: review.buyerPhotoUrl.isEmpty
                    ? Text(
                        review.buyerName.isNotEmpty
                            ? review.buyerName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10),
                      )
                    : null,
              ),
              const SizedBox(width: 6),
              Text(
                review.buyerName.isNotEmpty
                    ? review.buyerName
                    : 'Comprador',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
              const Spacer(),
              Text(
                '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),

          // ── Tags ─────────────────────────────────────────────────
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: review.tags.map((t) => _Tag(label: t)).toList(),
            ),
          ],

          // ── Comment ───────────────────────────────────────────────
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment!,
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tag frequency bar ──────────────────────────────────────────────────────

class _TagBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  const _TagBar(
      {required this.label, required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                backgroundColor: AppColors.bgSurface,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.accentGold),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$count',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── Review tile ────────────────────────────────────────────────────────────

class _ReviewTile extends StatelessWidget {
  final ReviewModel review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.accentGreen,
            backgroundImage: review.buyerPhotoUrl.isNotEmpty
                ? NetworkImage(review.buyerPhotoUrl)
                : null,
            child: review.buyerPhotoUrl.isEmpty
                ? Text(
                    review.buyerName.isNotEmpty
                        ? review.buyerName[0].toUpperCase()
                        : '?',
                    style:
                        AppTextStyles.caption.copyWith(color: Colors.white),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(review.buyerName,
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.textPrimary)),
                    const Spacer(),
                    RatingStarsWidget(
                        rating: review.rating.toDouble(), size: 12),
                  ],
                ),
                if (review.tags.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: review.tags
                        .map((t) => _Tag(label: t))
                        .toList(),
                  ),
                ],
                if (review.comment != null &&
                    review.comment!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    review.comment!,
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  _fmtDate(review.createdAt),
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accentGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption
            .copyWith(color: AppColors.accentGold, fontSize: 10),
      ),
    );
  }
}
