import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../chat/providers/chat_controller.dart';
import '../../chat/providers/chat_provider.dart';
import '../domain/order_model.dart';

// ── Page ───────────────────────────────────────────────────────────────────

/// Shown to a vendor when a new order arrives.
///
/// The vendor has [AppConstants.orderConfirmationTimeoutMinutes] minutes to
/// accept or reject.  After that the countdown shows "EXPIRADO" and both
/// action buttons are disabled.
class OrderAlertPage extends ConsumerWidget {
  final String orderId;
  const OrderAlertPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderByIdProvider(orderId));

    return orderAsync.when(
      loading: () => _blank(
        child: const Center(
            child: CircularProgressIndicator(
                color: AppColors.accentGold)),
      ),
      error: (e, _) => _blank(
        child: Center(
          child: Text('Error: $e',
              style:
                  AppTextStyles.body.copyWith(color: AppColors.error)),
        ),
      ),
      data: (order) {
        if (order == null) {
          return _blank(
            child: Center(
              child: Text('Orden no encontrada',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary)),
            ),
          );
        }

        // If already resolved, go straight to the chat.
        if (order.status != OrderStatus.pending) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => context.go('/chat/$orderId'));
          return _blank(child: const SizedBox.shrink());
        }

        final deadline = order.createdAt.add(
          Duration(
              minutes: AppConstants.orderConfirmationTimeoutMinutes),
        );

        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          appBar: AppBar(
            backgroundColor: AppColors.bgSurface,
            elevation: 0,
            leading: BackButton(
              color: AppColors.textPrimary,
              onPressed: () => context.go('/dashboard'),
            ),
            title: Text('Nuevo pedido',
                style: AppTextStyles.h3
                    .copyWith(color: AppColors.textPrimary)),
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 1024;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth: isDesktop ? 560 : double.infinity),
                    child: _AlertBody(
                        order: order, deadline: deadline),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _blank({required Widget child}) => Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          backgroundColor: AppColors.bgSurface,
          leading: BackButton(
            color: AppColors.textPrimary,
            onPressed: () {},
          ),
          title: Text('Nuevo pedido',
              style: AppTextStyles.h3
                  .copyWith(color: AppColors.textPrimary)),
        ),
        body: child,
      );
}

// ── Alert body ─────────────────────────────────────────────────────────────

class _AlertBody extends ConsumerWidget {
  final OrderModel order;
  final DateTime deadline;
  const _AlertBody({required this.order, required this.deadline});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countdownAsync = ref.watch(countdownProvider(deadline));
    final remaining = countdownAsync.asData?.value;
    final expired = remaining == Duration.zero;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Countdown chip ───────────────────────────────────────
          _CountdownChip(remaining: remaining, expired: expired),
          const SizedBox(height: 20),

          // ── Product card ─────────────────────────────────────────
          _ProductCard(order: order),
          const SizedBox(height: 16),

          // ── Buyer card ───────────────────────────────────────────
          _BuyerCard(order: order),
          const SizedBox(height: 16),

          // ── Delivery card ────────────────────────────────────────
          if (order.deliveryNote.isNotEmpty)
            _DeliveryCard(note: order.deliveryNote),
          if (order.deliveryNote.isNotEmpty) const SizedBox(height: 24),

          // ── Action buttons ───────────────────────────────────────
          _ActionRow(
            order: order,
            disabled: expired,
          ),
        ],
      ),
    );
  }
}

// ── Countdown chip ─────────────────────────────────────────────────────────

class _CountdownChip extends StatelessWidget {
  final Duration? remaining;
  final bool expired;
  const _CountdownChip({required this.remaining, required this.expired});

  @override
  Widget build(BuildContext context) {
    final color = expired
        ? AppColors.error
        : (remaining != null && remaining!.inSeconds < 60
            ? AppColors.error
            : AppColors.accentGold);

    final label = expired
        ? 'EXPIRADO'
        : remaining == null
            ? '--:--'
            : _fmt(remaining!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            expired ? 'Tiempo de respuesta agotado' : 'Tiempo para responder',
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTextStyles.h1.copyWith(
              color: color,
              fontSize: 36,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Product card ───────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final OrderModel order;
  const _ProductCard({required this.order});

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
          if (order.postMediaUrls.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: order.postMediaUrls.first,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    Container(color: AppColors.bgSurface, width: 64, height: 64),
                errorWidget: (_, _, _) => Container(
                  color: AppColors.bgSurface,
                  width: 64,
                  height: 64,
                  child: const Icon(Icons.image_not_supported_outlined,
                      color: AppColors.textSecondary),
                ),
              ),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.postTitle,
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('Cantidad: ${order.quantity}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Price
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${order.finalPrice.toStringAsFixed(order.finalPrice % 1 == 0 ? 0 : 2)}',
                style: AppTextStyles.h3
                    .copyWith(color: AppColors.accentGold),
              ),
              if (order.offerApplied)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color:
                        AppColors.accentGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Oferta',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.accentGold)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Buyer card ─────────────────────────────────────────────────────────────

class _BuyerCard extends StatelessWidget {
  final OrderModel order;
  const _BuyerCard({required this.order});

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
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.accentGreen,
            backgroundImage: order.buyerPhotoUrl.isNotEmpty
                ? CachedNetworkImageProvider(order.buyerPhotoUrl)
                : null,
            child: order.buyerPhotoUrl.isEmpty
                ? Text(
                    order.buyerName.isNotEmpty
                        ? order.buyerName[0].toUpperCase()
                        : '?',
                    style: AppTextStyles.h3
                        .copyWith(color: Colors.white),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Comprador',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(
                order.buyerName.isNotEmpty
                    ? order.buyerName
                    : 'Usuario anónimo',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Delivery card ──────────────────────────────────────────────────────────

class _DeliveryCard extends StatelessWidget {
  final String note;
  const _DeliveryCard({required this.note});

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on_outlined,
              color: AppColors.accentGold, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Punto de entrega',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(note,
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action row ─────────────────────────────────────────────────────────────

class _ActionRow extends ConsumerWidget {
  final OrderModel order;
  final bool disabled;
  const _ActionRow({required this.order, required this.disabled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        // ── Reject ────────────────────────────────────────────────
        Expanded(
          child: OutlinedButton(
            onPressed: disabled
                ? null
                : () async {
                    await ref
                        .read(chatControllerProvider)
                        .rejectOrder(order.id);
                    if (context.mounted) context.go('/dashboard');
                  },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(
                  color: disabled
                      ? AppColors.borderOverlay
                      : AppColors.error.withValues(alpha: 0.6)),
            ),
            child: const Text('Rechazar'),
          ),
        ),
        const SizedBox(width: 12),

        // ── Accept ────────────────────────────────────────────────
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: disabled
                ? null
                : () async {
                    await ref
                        .read(chatControllerProvider)
                        .confirmOrder(order.id);
                    if (context.mounted) {
                      context.go('/chat/${order.id}');
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Aceptar pedido'),
          ),
        ),
      ],
    );
  }
}
