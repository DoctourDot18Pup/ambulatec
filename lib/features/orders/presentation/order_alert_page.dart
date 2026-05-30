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

class _AlertBody extends ConsumerStatefulWidget {
  final OrderModel order;
  final DateTime deadline;
  const _AlertBody({required this.order, required this.deadline});

  @override
  ConsumerState<_AlertBody> createState() => _AlertBodyState();
}

class _AlertBodyState extends ConsumerState<_AlertBody> {
  late int _qty;

  @override
  void initState() {
    super.initState();
    _qty = widget.order.quantity;
  }

  @override
  Widget build(BuildContext context) {
    final countdownAsync = ref.watch(countdownProvider(widget.deadline));
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
          _ProductCard(
            order: widget.order,
            qty: _qty,
            onQtyChanged: (q) => setState(() => _qty = q),
          ),
          const SizedBox(height: 16),

          // ── Buyer card ───────────────────────────────────────────
          _BuyerCard(order: widget.order),
          const SizedBox(height: 16),

          // ── Selected extras ──────────────────────────────────────
          if (widget.order.selectedExtras.isNotEmpty) ...[
            _ExtrasCard(selectedExtras: widget.order.selectedExtras),
            const SizedBox(height: 16),
          ],

          // ── Delivery card ────────────────────────────────────────
          if (widget.order.deliveryNote.isNotEmpty)
            _DeliveryCard(
              note: widget.order.deliveryNote,
              imageUrl: widget.order.deliveryImageUrl,
            ),
          if (widget.order.deliveryNote.isNotEmpty)
            const SizedBox(height: 24),

          // ── Action buttons ───────────────────────────────────────
          _ActionRow(
            order: widget.order,
            adjustedQty: _qty,
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
  final int qty;
  final void Function(int) onQtyChanged;
  const _ProductCard({
    required this.order,
    required this.qty,
    required this.onQtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final adjustedTotal = order.originalPrice * qty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOverlay),
      ),
      child: Column(
        children: [
          Row(
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
                    placeholder: (_, _) => Container(
                        color: AppColors.bgSurface, width: 64, height: 64),
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
                        style: AppTextStyles.body.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                    if (qty != order.quantity) ...[
                      const SizedBox(height: 2),
                      Text('Solicitado: ${order.quantity}',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${adjustedTotal.toStringAsFixed(adjustedTotal % 1 == 0 ? 0 : 2)}',
                    style: AppTextStyles.h3
                        .copyWith(color: AppColors.accentGold),
                  ),
                  if (order.offerApplied)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accentGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Oferta',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.accentGold)),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.borderOverlay, height: 1),
          const SizedBox(height: 10),
          // ── Quantity stepper ──────────────────────────────────
          Row(
            children: [
              Text('CANTIDAD',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
              const Spacer(),
              _QtyBtn(
                icon: Icons.remove,
                enabled: qty > 1,
                onTap: () => onQtyChanged(qty - 1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('$qty',
                    style: AppTextStyles.h3
                        .copyWith(color: AppColors.textPrimary)),
              ),
              _QtyBtn(
                icon: Icons.add,
                enabled: qty < 99,
                onTap: () => onQtyChanged(qty + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _QtyBtn(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color =
        enabled ? AppColors.accentGold : AppColors.textSecondary;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: enabled
                  ? AppColors.accentGold.withValues(alpha: 0.5)
                  : AppColors.borderOverlay),
          color: enabled
              ? AppColors.accentGold.withValues(alpha: 0.1)
              : Colors.transparent,
        ),
        child: Icon(icon, size: 15, color: color),
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

// ── Extras card ────────────────────────────────────────────────────────────

class _ExtrasCard extends StatelessWidget {
  final Map<String, List<String>> selectedExtras;
  const _ExtrasCard({required this.selectedExtras});

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
          const Row(
            children: [
              Icon(Icons.tune_outlined,
                  size: 14, color: AppColors.textSecondary),
              SizedBox(width: 6),
              Text('PERSONALIZACIONES',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          ...selectedExtras.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${e.key}: ',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    Expanded(
                      child: Text(
                        e.value.join(', '),
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ── Delivery card ──────────────────────────────────────────────────────────

class _DeliveryCard extends StatelessWidget {
  final String note;
  final String? imageUrl;
  const _DeliveryCard({required this.note, this.imageUrl});

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
          if (imageUrl != null && imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: imageUrl!,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                    color: AppColors.bgSurface, width: 100, height: 100),
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Action row ─────────────────────────────────────────────────────────────

class _ActionRow extends ConsumerWidget {
  final OrderModel order;
  final int adjustedQty;
  final bool disabled;
  const _ActionRow({
    required this.order,
    required this.adjustedQty,
    required this.disabled,
  });

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
                        .rejectOrder(order);
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
                        .confirmOrder(order, quantity: adjustedQty);
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
