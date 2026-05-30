import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../chat/providers/chat_controller.dart';
import '../../chat/providers/chat_provider.dart';
import '../domain/order_model.dart';
import '../providers/payment_provider.dart';

// ── Page ───────────────────────────────────────────────────────────────────

class OrderDetailPage extends ConsumerWidget {
  final String orderId;
  const OrderDetailPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderByIdProvider(orderId));

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        leading: BackButton(color: AppColors.textPrimary),
        title: orderAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (order) => Text(
            'Orden #AT-${orderId.substring(0, 6).toUpperCase()}',
            style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
          ),
        ),
      ),
      body: orderAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accentGold)),
        error: (e, _) => Center(
            child: Text('$e',
                style: AppTextStyles.body.copyWith(color: AppColors.error))),
        data: (order) {
          if (order == null) {
            return Center(
              child: Text('Orden no encontrada',
                  style:
                      AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
            );
          }
          return _OrderDetailBody(order: order);
        },
      ),
    );
  }
}

// ── Body ───────────────────────────────────────────────────────────────────

class _OrderDetailBody extends ConsumerWidget {
  final OrderModel order;
  const _OrderDetailBody({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isVendor = order.vendorId == currentUid;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;
        return Center(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: isDesktop ? 640 : double.infinity),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Status banner ────────────────────────────────────────
                _StatusBanner(status: order.status),
                const SizedBox(height: 16),

                // ── Product card ─────────────────────────────────────────
                _SectionCard(
                  children: [
                    if (order.postMediaUrls.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          order.postMediaUrls.first,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            height: 160,
                            color: AppColors.bgSurface,
                            child: const Icon(Icons.image_outlined,
                                color: AppColors.textSecondary, size: 40),
                          ),
                        ),
                      ),
                    if (order.postMediaUrls.isNotEmpty) const SizedBox(height: 12),
                    Text(order.postTitle,
                        style: AppTextStyles.h3
                            .copyWith(color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    _InfoRow(label: 'Cantidad', value: '${order.quantity}'),
                    _InfoRow(
                      label: 'Total pagado',
                      value:
                          '\$${order.finalPrice.toStringAsFixed(order.finalPrice % 1 == 0 ? 0 : 2)}',
                      valueColor: AppColors.accentGold,
                    ),
                    if (order.offerApplied)
                      _InfoRow(
                        label: 'Precio original',
                        value:
                            '\$${order.originalPrice.toStringAsFixed(order.originalPrice % 1 == 0 ? 0 : 2)}',
                        strikethrough: true,
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Buyer / vendor info ───────────────────────────────────
                _SectionCard(
                  children: [
                    Text(isVendor ? 'COMPRADOR' : 'VENDEDOR',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.accentGreen,
                          backgroundImage:
                              order.buyerPhotoUrl.isNotEmpty
                                  ? NetworkImage(order.buyerPhotoUrl)
                                  : null,
                          child: order.buyerPhotoUrl.isEmpty
                              ? Text(
                                  order.buyerName.isNotEmpty
                                      ? order.buyerName[0].toUpperCase()
                                      : '?',
                                  style: AppTextStyles.body
                                      .copyWith(color: Colors.white),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Text(order.buyerName,
                            style: AppTextStyles.body
                                .copyWith(color: AppColors.textPrimary)),
                      ],
                    ),
                    if (order.deliveryNote.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('NOTA DE ENTREGA',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(order.deliveryNote,
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.textPrimary)),
                      if (order.deliveryImageUrl != null &&
                          order.deliveryImageUrl!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: order.deliveryImageUrl!,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => Container(
                                color: AppColors.bgSurface,
                                width: 120,
                                height: 120),
                            errorWidget: (_, _, _) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // ── Timeline ─────────────────────────────────────────────
                _SectionCard(
                  children: [
                    Text('ESTADO',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    _TimelineRow(
                      icon: Icons.shopping_bag_outlined,
                      label: 'Pedido realizado',
                      date: order.createdAt,
                      done: true,
                    ),
                    _TimelineRow(
                      icon: Icons.check_circle_outline,
                      label: 'Confirmado por vendedor',
                      date: order.confirmedAt,
                      done: order.confirmedAt != null,
                    ),
                    _TimelineRow(
                      icon: Icons.local_shipping_outlined,
                      label: 'Entregado',
                      date: order.deliveredAt,
                      done: order.deliveredAt != null,
                      isLast: true,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Actions ──────────────────────────────────────────────
                _ActionsSection(order: order, isVendor: isVendor),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Status banner ──────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final OrderStatus status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      OrderStatus.pending =>
        ('Esperando confirmación del vendedor', AppColors.accentGold, Icons.hourglass_empty_outlined),
      OrderStatus.awaiting_payment =>
        ('Aceptado — pendiente de pago', AppColors.accentGold, Icons.payment_outlined),
      OrderStatus.confirmed =>
        ('Confirmado — en preparación', AppColors.success, Icons.check_circle_outline),
      OrderStatus.delivered =>
        ('¡Entregado con éxito!', AppColors.success, Icons.local_shipping_outlined),
      OrderStatus.rejected =>
        ('Rechazado por el vendedor', AppColors.error, Icons.cancel_outlined),
      OrderStatus.cancelled =>
        ('Cancelado', AppColors.textSecondary, Icons.block_outlined),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: AppTextStyles.body.copyWith(
                    color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Actions section ────────────────────────────────────────────────────────

class _ActionsSection extends ConsumerWidget {
  final OrderModel order;
  final bool isVendor;
  const _ActionsSection({required this.order, required this.isVendor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── Vendor actions ──────────────────────────────────────────────────────
    if (isVendor) {
      if (order.status == OrderStatus.pending) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ActionButton(
              label: 'Confirmar orden',
              icon: Icons.check_circle_outline,
              color: AppColors.success,
              onTap: () async {
                final ok = await _confirmDialog(
                  context,
                  title: '¿Aceptar pedido?',
                  body: 'El comprador será notificado para proceder al pago.',
                  confirmLabel: 'Aceptar',
                  confirmColor: AppColors.success,
                );
                if (ok && context.mounted) {
                  await ref
                      .read(chatControllerProvider)
                      .confirmOrder(order);
                  if (context.mounted) context.push('/chat/${order.id}');
                }
              },
            ),
            const SizedBox(height: 10),
            _ActionButton(
              label: 'Rechazar orden',
              icon: Icons.cancel_outlined,
              color: AppColors.error,
              outlined: true,
              onTap: () async {
                final ok = await _confirmDialog(
                  context,
                  title: '¿Rechazar pedido?',
                  body: 'Esta acción no se puede deshacer.',
                  confirmLabel: 'Rechazar',
                  confirmColor: AppColors.error,
                );
                if (ok && context.mounted) {
                  await ref
                      .read(chatControllerProvider)
                      .rejectOrder(order);
                  if (context.mounted) context.pop();
                }
              },
            ),
          ],
        );
      }

      if (order.status == OrderStatus.confirmed) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ActionButton(
              label: 'Marcar como entregado',
              icon: Icons.local_shipping_outlined,
              color: AppColors.success,
              onTap: () async {
                final ok = await _confirmDialog(
                  context,
                  title: '¿Confirmar entrega?',
                  body:
                      'El comprador recibirá una notificación para dejar su reseña.',
                  confirmLabel: 'Entregar',
                  confirmColor: AppColors.success,
                );
                if (ok && context.mounted) {
                  await ref
                      .read(chatControllerProvider)
                      .markDelivered(order);
                  if (context.mounted) context.pop();
                }
              },
            ),
            const SizedBox(height: 10),
            _ActionButton(
              label: 'Ir al chat',
              icon: Icons.chat_bubble_outline,
              color: AppColors.accentGold,
              outlined: true,
              onTap: () => context.push('/chat/${order.id}'),
            ),
          ],
        );
      }
    }

    // ── Buyer actions ───────────────────────────────────────────────────────
    if (!isVendor) {
      if (order.status == OrderStatus.awaiting_payment) {
        return _ActionButton(
          label:
              'Proceder al pago — \$${order.finalPrice.toStringAsFixed(order.finalPrice % 1 == 0 ? 0 : 2)}',
          icon: Icons.payment_outlined,
          color: AppColors.accentGold,
          onTap: () {
            ref.read(pendingPaymentOrderIdProvider.notifier).update(order.id);
            context.push('/payment');
          },
        );
      }
      if (order.status == OrderStatus.pending ||
          order.status == OrderStatus.confirmed) {
        return _ActionButton(
          label: 'Ir al chat',
          icon: Icons.chat_bubble_outline,
          color: AppColors.accentGold,
          onTap: () => context.push('/chat/${order.id}'),
        );
      }
      if (order.status == OrderStatus.delivered) {
        return _ActionButton(
          label: 'Dejar reseña',
          icon: Icons.star_outline_rounded,
          color: AppColors.accentGold,
          onTap: () => context.push('/review/${order.id}'),
        );
      }
    }

    return const SizedBox.shrink();
  }

  Future<bool> _confirmDialog(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text(title,
            style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
        content: Text(body,
            style:
                AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// ── Action button ──────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool outlined;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = outlined
        ? OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color),
            minimumSize: const Size(double.infinity, 52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          )
        : ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          );

    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text(label,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
      ],
    );

    return outlined
        ? OutlinedButton(onPressed: onTap, style: style, child: child)
        : ElevatedButton(onPressed: onTap, style: style, child: child);
  }
}

// ── Section card ───────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOverlay),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

// ── Info row ───────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool strikethrough;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.strikethrough = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Text(label,
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
          const Spacer(),
          Text(
            value,
            style: AppTextStyles.body.copyWith(
              color: valueColor ?? AppColors.textPrimary,
              fontWeight:
                  valueColor != null ? FontWeight.w600 : FontWeight.normal,
              decoration:
                  strikethrough ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Timeline row ───────────────────────────────────────────────────────────

class _TimelineRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final DateTime? date;
  final bool done;
  final bool isLast;

  const _TimelineRow({
    required this.icon,
    required this.label,
    required this.date,
    required this.done,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.success : AppColors.textSecondary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon + vertical line
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: done
                    ? AppColors.success.withValues(alpha: 0.15)
                    : AppColors.bgSurface,
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            if (!isLast)
              Container(
                width: 1,
                height: 24,
                color: done
                    ? AppColors.success.withValues(alpha: 0.3)
                    : AppColors.borderOverlay,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTextStyles.body.copyWith(color: color)),
                if (date != null) ...[
                  const SizedBox(height: 2),
                  Text(_fmt(date!),
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary)),
                ],
                SizedBox(height: isLast ? 0 : 12),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _fmt(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} $h:$m';
  }
}
