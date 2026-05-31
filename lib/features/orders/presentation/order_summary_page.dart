import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../feed/domain/post_model.dart';
import '../domain/order_model.dart';
import '../providers/current_order_provider.dart';
import '../providers/payment_provider.dart';

class _BoolNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void update(bool value) => state = value;
}

final _submittingProvider =
    NotifierProvider.autoDispose<_BoolNotifier, bool>(_BoolNotifier.new);

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
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.go('/home'),
        ),
        title: Text('Confirmar solicitud',
            style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
      );
}

// ── Summary view ───────────────────────────────────────────────────────────

class _SummaryView extends ConsumerWidget {
  final OrderDraft draft;
  const _SummaryView({required this.draft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = draft.post;
    final isSubmitting = ref.watch(_submittingProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.go('/post/${post.id}'),
        ),
        title: Text('Confirmar solicitud',
            style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
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
                    _ProductCard(post: post, quantity: draft.quantity),
                    const SizedBox(height: 16),

                    // ── Selected extras ───────────────────────────────
                    if (draft.extrasDetail.isNotEmpty) ...[
                      _ExtrasCard(extras: draft.extrasDetail),
                      const SizedBox(height: 16),
                    ],

                    // ── Price card ─────────────────────────────────────
                    _PriceCard(
                      basePrice: post.price,
                      extras: draft.extrasDetail,
                      quantity: draft.quantity,
                    ),
                    const SizedBox(height: 16),

                    // ── Delivery card ─────────────────────────────────
                    _DeliveryCard(draft: draft, postId: post.id),
                    const SizedBox(height: 12),

                    // ── Info note ─────────────────────────────────────
                    _InfoNote(),
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
                onPressed: isSubmitting
                    ? null
                    : () => _submit(context, ref, draft),
                child: isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.bgPrimary),
                        ),
                      )
                    : const Text('Enviar solicitud al vendedor'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(
      BuildContext context, WidgetRef ref, OrderDraft draft) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    ref.read(_submittingProvider.notifier).update(true);
    try {
      final post = draft.post;
      final orderRef =
          FirebaseFirestore.instance.collection(AppConstants.ordersCollection).doc();

      // Upload delivery image if provided
      String? deliveryImageUrl;
      if (draft.deliveryImageBytes != null) {
        deliveryImageUrl = await CloudinaryService()
            .uploadImage(draft.deliveryImageBytes!, 'delivery/${user.uid}');
      }

      // Unit price = base + per-unit extras. Stored as `originalPrice` so the
      // vendor's quantity recalculation (originalPrice × quantity) keeps the
      // extras included.
      final unitPrice = post.price + draft.extrasPerUnit;

      final order = OrderModel(
        id: orderRef.id,
        buyerId: user.uid,
        buyerName: user.displayName ?? '',
        buyerPhotoUrl: user.photoURL ?? '',
        vendorId: post.vendorId,
        postId: post.id,
        postTitle: post.title,
        postMediaUrls: post.mediaUrls,
        originalPrice: unitPrice,
        finalPrice: unitPrice * draft.quantity,
        quantity: draft.quantity,
        offerApplied: post.hasOffer,
        offerType: post.offerType,
        deliveryNote: draft.deliveryNote,
        deliveryImageUrl: deliveryImageUrl,
        status: OrderStatus.pending,
        createdAt: DateTime.now(),
        chatExpiresAt: DateTime.now().add(const Duration(hours: 24)),
        selectedExtras: draft.selectedExtras,
        extrasDetail: draft.extrasDetail,
      );

      await orderRef.set(order.toMap());

      // Notify vendor of new order request.
      await FirebaseFirestore.instance
          .collection(AppConstants.notificationsCollection)
          .doc(orderRef.id)
          .set({
        'type': 'new_order',
        'recipientId': post.vendorId,
        'vendorId': post.vendorId,
        'orderId': orderRef.id,
        'buyerName': user.displayName ?? '',
        'productTitle': post.title,
        'status': 'unread',
        'createdAt': FieldValue.serverTimestamp(),
      });

      ref.read(confirmedOrderIdProvider.notifier).update(orderRef.id);

      if (context.mounted) context.go('/order-confirmed');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al enviar solicitud: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      ref.read(_submittingProvider.notifier).update(false);
    }
  }
}

// ── Product card ───────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final PostModel post;
  final int quantity;
  const _ProductCard({required this.post, required this.quantity});

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
          if (post.mediaUrls.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: post.mediaUrls.first,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    Container(color: AppColors.bgSurface, width: 80, height: 80),
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
                Text(post.vendorName,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(post.title,
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis),
                if (quantity > 1) ...[
                  const SizedBox(height: 2),
                  Text('Cantidad: $quantity',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '\$${post.price.toStringAsFixed(post.price % 1 == 0 ? 0 : 2)}',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Extras card ────────────────────────────────────────────────────────────

class _ExtrasCard extends StatelessWidget {
  final List<OrderExtra> extras;
  const _ExtrasCard({required this.extras});

  String _fmt(double v) => '\$${v.toStringAsFixed(v % 1 == 0 ? 0 : 2)}';

  @override
  Widget build(BuildContext context) {
    if (extras.isEmpty) return const SizedBox.shrink();

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
          Text('PERSONALIZACIONES',
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          ...extras.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${e.group}: ${e.option}',
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      e.price > 0 ? '+${_fmt(e.price)}' : 'Gratis',
                      style: AppTextStyles.caption.copyWith(
                          color: e.price > 0
                              ? AppColors.accentGold
                              : AppColors.textSecondary),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ── Price card ─────────────────────────────────────────────────────────────

class _PriceCard extends StatelessWidget {
  final double basePrice;
  final List<OrderExtra> extras;
  final int quantity;
  const _PriceCard({
    required this.basePrice,
    required this.extras,
    required this.quantity,
  });

  String _fmt(double v) => '\$${v.toStringAsFixed(v % 1 == 0 ? 0 : 2)}';

  @override
  Widget build(BuildContext context) {
    final extrasPerUnit = extras.fold<double>(0, (s, e) => s + e.price);
    final unitPrice = basePrice + extrasPerUnit;
    final total = unitPrice * quantity;
    final showBreakdown = extrasPerUnit > 0 || quantity > 1;

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
          if (showBreakdown) ...[
            _row('Producto', _fmt(basePrice)),
            for (final e in extras)
              if (e.price > 0)
                _row('${e.group}: ${e.option}', '+${_fmt(e.price)}'),
            if (quantity > 1) ...[
              _row('Subtotal por unidad', _fmt(unitPrice)),
              _row('Cantidad', '× $quantity'),
            ],
            const Divider(color: AppColors.borderOverlay, height: 20),
          ],
          Row(
            children: [
              Text('Total a pagar',
                  style: AppTextStyles.h3
                      .copyWith(color: AppColors.textPrimary)),
              const Spacer(),
              Text(_fmt(total),
                  style:
                      AppTextStyles.h2.copyWith(color: AppColors.accentGold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Text(value,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textPrimary)),
          ],
        ),
      );
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
                  style:
                      AppTextStyles.body.copyWith(color: AppColors.textPrimary),
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

// ── Info note ──────────────────────────────────────────────────────────────

class _InfoNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              size: 16, color: AppColors.accentGold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'El pago se realiza después de que el vendedor acepte tu solicitud.',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
