import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../feed/domain/post_model.dart';
import '../providers/current_order_provider.dart';

// ── Page-scoped quantity provider ──────────────────────────────────────────

final _quantityProvider = StateProvider.autoDispose<int>((ref) => 1);

// ── Page ───────────────────────────────────────────────────────────────────

class OrderSummaryPage extends ConsumerWidget {
  const OrderSummaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(currentOrderProvider);

    if (draft == null) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: _buildAppBar(context),
        body: Center(
          child: Text(
            'No hay orden activa',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return _SummaryView(draft: draft);
  }

  AppBar _buildAppBar(BuildContext context) => AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.go('/home'),
        ),
        title: Text('Resumen',
            style:
                AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
      );
}

// ── Summary view ───────────────────────────────────────────────────────────

class _SummaryView extends ConsumerWidget {
  final OrderDraft draft;
  const _SummaryView({required this.draft});

  /// Computes total considering offer type.
  double _computeTotal(PostModel post, int quantity) {
    if (!post.hasOffer) return post.price * quantity;
    switch (post.offerType) {
      case OfferType.twoForOne:
        // Buy 2 pay for 1, e.g. quantity=3 → pay for 2.
        return post.price * ((quantity + 1) ~/ 2);
      default:
        return post.price * quantity;
    }
  }

  double _computeSubtotal(PostModel post, int quantity) {
    return (post.originalPrice ?? post.price) * quantity;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = draft.post;
    final quantity = ref.watch(_quantityProvider);
    final subtotal = _computeSubtotal(post, quantity);
    final total = _computeTotal(post, quantity);
    final discount = subtotal - total;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.go('/post/${post.id}'),
        ),
        title: Text('Resumen',
            style:
                AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
      ),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Product card ─────────────────────────────────
                    _ProductCard(
                      post: post,
                      quantity: quantity,
                      onDecrement: quantity > 1
                          ? () => ref
                              .read(_quantityProvider.notifier)
                              .state--
                          : null,
                      onIncrement: () =>
                          ref.read(_quantityProvider.notifier).state++,
                    ),
                    const SizedBox(height: 16),

                    // ── Price breakdown ──────────────────────────────
                    _PriceBreakdown(
                      subtotal: subtotal,
                      discount: discount,
                      total: total,
                      hasOffer: post.hasOffer,
                    ),
                    const SizedBox(height: 16),

                    // ── Delivery card ─────────────────────────────────
                    _DeliveryCard(draft: draft, postId: post.id),
                  ],
                ),
              ),
            ),
          ),

          // ── Fixed CTA ─────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: AppColors.bgPrimary,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: ElevatedButton(
                onPressed: () {
                  // Update quantity in draft then proceed to payment.
                  ref.read(currentOrderProvider.notifier).state =
                      draft.copyWith(quantity: quantity);
                  context.go('/payment');
                },
                child: const Text('Proceder al pago'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Product card ───────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final PostModel post;
  final int quantity;
  final VoidCallback? onDecrement;
  final VoidCallback onIncrement;

  const _ProductCard({
    required this.post,
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

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
          // Thumbnail
          if (post.mediaUrls.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: post.mediaUrls.first,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                    color: AppColors.bgSurface, width: 80, height: 80),
                errorWidget: (_, _, _) => Container(
                  color: AppColors.bgSurface,
                  width: 80,
                  height: 80,
                  child: const Icon(Icons.image_not_supported_outlined,
                      color: AppColors.textSecondary),
                ),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.vendorName,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  post.title,
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Quantity controls
                Row(
                  children: [
                    _QtyButton(
                      icon: Icons.remove,
                      onTap: onDecrement,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$quantity',
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 12),
                    _QtyButton(
                      icon: Icons.add,
                      onTap: onIncrement,
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${post.price.toStringAsFixed(post.price % 1 == 0 ? 0 : 2)}',
                          style: AppTextStyles.h3
                              .copyWith(color: AppColors.accentGold),
                        ),
                        if (post.originalPrice != null &&
                            post.originalPrice! > post.price)
                          Text(
                            '\$${post.originalPrice!.toStringAsFixed(post.originalPrice! % 1 == 0 ? 0 : 2)}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: onTap != null
              ? AppColors.bgSurface
              : AppColors.bgCard,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.borderOverlay),
        ),
        child: Icon(
          icon,
          size: 14,
          color: onTap != null
              ? AppColors.textPrimary
              : AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ── Price breakdown ────────────────────────────────────────────────────────

class _PriceBreakdown extends StatelessWidget {
  final double subtotal;
  final double discount;
  final double total;
  final bool hasOffer;

  const _PriceBreakdown({
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.hasOffer,
  });

  String _fmt(double v) =>
      '\$${v.toStringAsFixed(v % 1 == 0 ? 0 : 2)}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOverlay),
      ),
      child: Column(
        children: [
          _PriceRow(
            label: 'Subtotal',
            value: _fmt(subtotal),
          ),
          if (hasOffer && discount > 0) ...[
            const SizedBox(height: 8),
            _PriceRow(
              label: 'Descuento aplicado',
              value: '-${_fmt(discount)}',
              valueColor: AppColors.success,
            ),
          ],
          const SizedBox(height: 10),
          const Divider(color: AppColors.borderOverlay, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Total',
                  style: AppTextStyles.h3
                      .copyWith(color: AppColors.textPrimary)),
              const Spacer(),
              Text(
                _fmt(total),
                style: AppTextStyles.h2
                    .copyWith(color: AppColors.accentGold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _PriceRow(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: AppTextStyles.body
                .copyWith(color: AppColors.textSecondary)),
        const Spacer(),
        Text(value,
            style: AppTextStyles.body.copyWith(
                color: valueColor ?? AppColors.textPrimary)),
      ],
    );
  }
}

// ── Delivery card ──────────────────────────────────────────────────────────

class _DeliveryCard extends StatelessWidget {
  final OrderDraft draft;
  final String postId;

  const _DeliveryCard({required this.draft, required this.postId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOverlay),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  color: AppColors.accentGold, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  draft.deliveryNote,
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textPrimary),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/post/$postId'),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: Text('Editar',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.accentGold)),
              ),
            ],
          ),
          if (draft.deliveryImageBytes != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(
                draft.deliveryImageBytes!,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
