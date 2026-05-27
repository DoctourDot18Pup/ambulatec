import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../chat/providers/chat_provider.dart';
import '../../orders/domain/order_model.dart';
import '../../profile/domain/review_model.dart';
import '../../profile/providers/review_controller.dart';

// ── Page-scoped providers ──────────────────────────────────────────────────

final _ratingProvider = StateProvider.autoDispose<int>((ref) => 0);
final _selectedTagsProvider =
    StateProvider.autoDispose<Set<String>>((ref) => {});
final _commentProvider = StateProvider.autoDispose<String>((ref) => '');

const _kTags = [
  'Puntual',
  'Producto exacto',
  'Buena presentación',
  'Amable',
  'Repetiría',
];

// ── Page ───────────────────────────────────────────────────────────────────

class ReviewPage extends ConsumerWidget {
  final String orderId;
  const ReviewPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderByIdProvider(orderId));

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        title: Text('Reseña',
            style:
                AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: orderAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(
                color: AppColors.accentGold)),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.error))),
        data: (order) {
          if (order == null) {
            return Center(
              child: Text('Orden no encontrada',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary)),
            );
          }
          if (order.status != OrderStatus.delivered) {
            return Center(
              child: Text('El pedido aún no ha sido entregado.',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
            );
          }
          return _ReviewContent(order: order);
        },
      ),
    );
  }
}

// ── Content ────────────────────────────────────────────────────────────────

class _ReviewContent extends ConsumerWidget {
  final OrderModel order;
  const _ReviewContent({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewState = ref.watch(reviewControllerProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title ─────────────────────────────────────────────
            Text('¿Cómo fue tu experiencia?',
                style: AppTextStyles.h2
                    .copyWith(color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'Tu reseña ayuda a otros estudiantes a confiar en este vendedor.',
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),

            // ── Vendor card ───────────────────────────────────────
            _VendorCard(order: order),
            const SizedBox(height: 24),

            // ── Stars ─────────────────────────────────────────────
            Text('CALIFICACIÓN',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            const _StarSelector(),
            const SizedBox(height: 24),

            // ── Tags ──────────────────────────────────────────────
            Text('ETIQUETAS (OPCIONAL)',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            const _TagChips(),
            const SizedBox(height: 24),

            // ── Comment ───────────────────────────────────────────
            Text('COMENTARIO (OPCIONAL)',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextFormField(
              maxLines: 4,
              maxLength: 200,
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textPrimary),
              onChanged: (v) =>
                  ref.read(_commentProvider.notifier).state = v,
              decoration: const InputDecoration(
                hintText: 'Cuéntanos tu experiencia…',
                counterStyle:
                    TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 28),

            // ── Error message ─────────────────────────────────────
            if (reviewState is AsyncError)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  reviewState.error.toString(),
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.error),
                ),
              ),

            // ── Submit ────────────────────────────────────────────
            _SubmitButton(order: order),
          ],
        ),
      ),
    );
  }
}

// ── Vendor card ────────────────────────────────────────────────────────────

class _VendorCard extends StatelessWidget {
  final OrderModel order;
  const _VendorCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOverlay),
      ),
      child: Row(
        children: [
          // Thumbnail (first post image)
          if (order.postMediaUrls.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: order.postMediaUrls.first,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                    color: AppColors.bgSurface, width: 56, height: 56),
                errorWidget: (_, _, _) => Container(
                    color: AppColors.bgSurface,
                    width: 56,
                    height: 56,
                    child: const Icon(Icons.store_outlined,
                        color: AppColors.textSecondary)),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pedido de',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(order.postTitle,
                    style: AppTextStyles.body.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                Text(
                    'ORDEN #AT-${order.id.substring(0, 6).toUpperCase()}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Star selector ──────────────────────────────────────────────────────────

class _StarSelector extends ConsumerWidget {
  const _StarSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rating = ref.watch(_ratingProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final filled = i < rating;
        return GestureDetector(
          onTap: () =>
              ref.read(_ratingProvider.notifier).state = i + 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: AnimatedScale(
              scale: filled ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Icon(
                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 40,
                color: filled ? AppColors.accentGold : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Tag chips ──────────────────────────────────────────────────────────────

class _TagChips extends ConsumerWidget {
  const _TagChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_selectedTagsProvider);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _kTags.map((tag) {
        final isSelected = selected.contains(tag);
        return GestureDetector(
          onTap: () {
            final next = Set<String>.from(selected);
            isSelected ? next.remove(tag) : next.add(tag);
            ref.read(_selectedTagsProvider.notifier).state = next;
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.accentGreen.withValues(alpha: 0.25)
                  : AppColors.bgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? AppColors.accentGreen
                    : AppColors.borderOverlay,
              ),
            ),
            child: Text(
              tag,
              style: AppTextStyles.body.copyWith(
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Submit button ──────────────────────────────────────────────────────────

class _SubmitButton extends ConsumerWidget {
  final OrderModel order;
  const _SubmitButton({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rating = ref.watch(_ratingProvider);
    final tags = ref.watch(_selectedTagsProvider);
    final comment = ref.watch(_commentProvider);
    final reviewState = ref.watch(reviewControllerProvider);

    final isLoading = reviewState is AsyncLoading;
    final isEnabled = rating > 0 && !isLoading;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isEnabled ? () => _submit(context, ref, rating, tags, comment) : null,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.bgPrimary),
                ),
              )
            : const Text('Enviar reseña'),
      ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    int rating,
    Set<String> tags,
    String comment,
  ) async {
    final notifier = ref.read(reviewControllerProvider.notifier);

    // Check duplicate
    final already = await notifier.hasReviewed(order.id);
    if (already) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ya dejaste una reseña para este pedido.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final review = ReviewModel(
      id: '',
      orderId: order.id,
      vendorId: order.vendorId,
      buyerId: user.uid,
      buyerName: user.displayName ?? '',
      buyerPhotoUrl: user.photoURL ?? '',
      rating: rating,
      tags: tags.toList(),
      comment: comment.trim().isEmpty ? null : comment.trim(),
      createdAt: DateTime.now(),
    );

    await notifier.submitReview(review);

    final state = ref.read(reviewControllerProvider);
    if (state is AsyncData && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('¡Gracias por tu reseña!'),
        behavior: SnackBarBehavior.floating,
      ));
      context.go('/home');
    }
  }
}
