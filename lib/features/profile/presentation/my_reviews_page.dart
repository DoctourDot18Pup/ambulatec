import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/rating_stars_widget.dart';
import '../domain/review_model.dart';
import '../providers/vendor_reviews_provider.dart';

const _kPageSize = 5;
final _visibleCountProvider =
    StateProvider.autoDispose<int>((ref) => _kPageSize);

class MyReviewsPage extends ConsumerWidget {
  const MyReviewsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final reviewsAsync = ref.watch(vendorReviewsProvider(uid));

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        leading: BackButton(color: AppColors.textPrimary),
        title: Text('Mis reseñas',
            style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
      ),
      body: reviewsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accentGold)),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: AppTextStyles.body.copyWith(color: AppColors.error))),
        data: (reviews) {
          if (reviews.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.star_outline_rounded,
              title: 'Sin reseñas aún',
              subtitle:
                  'Aquí aparecerán las reseñas que tus compradores dejen después de recibir sus pedidos.',
            );
          }

          // ── Aggregate stats ──────────────────────────────────────
          final avg = reviews.map((r) => r.rating).reduce((a, b) => a + b) /
              reviews.length;
          final tagCounts = <String, int>{};
          for (final r in reviews) {
            for (final t in r.tags) {
              tagCounts[t] = (tagCounts[t] ?? 0) + 1;
            }
          }
          final topTags = (tagCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .take(5)
              .toList();

          return LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth:
                          constraints.maxWidth >= 1024 ? 680 : double.infinity),
                  child: Builder(builder: (context) {
                    final visible = ref.watch(_visibleCountProvider);
                    final shown = reviews.take(visible).toList();
                    final remaining = reviews.length - visible;

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // ── Overview card ────────────────────────────
                        _OverviewCard(
                            avg: avg,
                            total: reviews.length,
                            topTags: topTags),
                        const SizedBox(height: 20),

                        Text('DETALLE POR PEDIDO',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 12),

                        // ── Per-order tiles (paginated) ──────────────
                        ...shown.map((r) => _ReviewTile(review: r)),

                        // ── Load more ────────────────────────────────
                        if (remaining > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 8),
                            child: TextButton.icon(
                              onPressed: () => ref
                                  .read(_visibleCountProvider.notifier)
                                  .state += _kPageSize,
                              icon: const Icon(Icons.expand_more,
                                  color: AppColors.accentGold, size: 18),
                              label: Text(
                                'Mostrar más ($remaining restantes)',
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.accentGold),
                              ),
                            ),
                          ),
                      ],
                    );
                  }),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Overview card ──────────────────────────────────────────────────────────

class _OverviewCard extends StatelessWidget {
  final double avg;
  final int total;
  final List<MapEntry<String, int>> topTags;

  const _OverviewCard(
      {required this.avg, required this.total, required this.topTags});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOverlay),
      ),
      child: Column(
        children: [
          // Score + stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                avg.toStringAsFixed(1),
                style: AppTextStyles.h1
                    .copyWith(color: AppColors.accentGold, fontSize: 48),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RatingStarsWidget(rating: avg, size: 20),
                  const SizedBox(height: 4),
                  Text('$total ${total == 1 ? 'reseña' : 'reseñas'}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),

          // Star distribution bars
          const SizedBox(height: 16),
          const Divider(color: AppColors.borderOverlay, height: 1),
          const SizedBox(height: 16),

          if (topTags.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text('LO QUE MÁS DESTACAN',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 10),
            ...topTags.map((e) => _TagBar(
                  label: e.key,
                  count: e.value,
                  total: total,
                )),
          ],
        ],
      ),
    );
  }
}

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
            width: 130,
            child: Text(label,
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 7,
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

// ── Per-order review tile ──────────────────────────────────────────────────

class _ReviewTile extends StatelessWidget {
  final ReviewModel review;
  const _ReviewTile({required this.review});

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
          // Product + rating
          Row(
            children: [
              Expanded(
                child: Text(
                  review.postTitle.isNotEmpty ? review.postTitle : 'Pedido',
                  style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              RatingStarsWidget(rating: review.rating.toDouble(), size: 13),
            ],
          ),
          const SizedBox(height: 8),

          // Buyer + date
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
              Expanded(
                child: Text(
                  review.buyerName.isNotEmpty ? review.buyerName : 'Comprador',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),

          // Tags
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: review.tags
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentGold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(t,
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.accentGold, fontSize: 10)),
                      ))
                  .toList(),
            ),
          ],

          // Comment
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment!,
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
