import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/adaptive_scaffold.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../auth/data/user_provider.dart';
import '../domain/order_model.dart';
import '../providers/buyer_orders_provider.dart';
import '../providers/orders_provider.dart';

// ── Page ───────────────────────────────────────────────────────────────────

class OrdersPage extends ConsumerWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);
    final user = userAsync.asData?.value;
    final isVendor = user?.roles.contains('vendor') ?? false;

    return AdaptiveScaffold(
      currentIndex: 3,
      body: isVendor ? const _VendorOrdersBody() : const _BuyerOrdersBody(),
    );
  }
}

// ── Buyer body ─────────────────────────────────────────────────────────────

class _BuyerOrdersBody extends ConsumerWidget {
  const _BuyerOrdersBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(buyerOrdersProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          backgroundColor: AppColors.bgSurface,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text('Mis pedidos',
              style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
          bottom: TabBar(
            labelColor: AppColors.accentGold,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle:
                AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            unselectedLabelStyle: AppTextStyles.body,
            indicatorColor: AppColors.accentGold,
            indicatorWeight: 2,
            tabs: const [
              Tab(text: 'Activas'),
              Tab(text: 'Historial'),
            ],
          ),
        ),
        body: ordersAsync.when(
          loading: () => const Center(
              child:
                  CircularProgressIndicator(color: AppColors.accentGold)),
          error: (e, _) => Center(
              child: Text('$e',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.error))),
          data: (orders) {
            final active = orders
                .where((o) =>
                    o.status == OrderStatus.pending ||
                    o.status == OrderStatus.awaiting_payment ||
                    o.status == OrderStatus.confirmed)
                .toList();
            final history = orders
                .where((o) =>
                    o.status == OrderStatus.delivered ||
                    o.status == OrderStatus.rejected ||
                    o.status == OrderStatus.cancelled)
                .toList();

            return TabBarView(
              children: [
                _OrderList(
                  orders: active,
                  emptyTitle: 'Sin pedidos activos',
                  emptySubtitle:
                      'Tus compras en curso aparecerán aquí.',
                  isBuyer: true,
                ),
                _OrderList(
                  orders: history,
                  emptyTitle: 'Sin historial',
                  emptySubtitle:
                      'Tus pedidos completados aparecerán aquí.',
                  isBuyer: true,
                  isHistory: true,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Vendor body ────────────────────────────────────────────────────────────

class _VendorOrdersBody extends ConsumerWidget {
  const _VendorOrdersBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          backgroundColor: AppColors.bgSurface,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text('Mis ventas',
              style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
          bottom: TabBar(
            labelColor: AppColors.accentGold,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle:
                AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            unselectedLabelStyle: AppTextStyles.body,
            indicatorColor: AppColors.accentGold,
            indicatorWeight: 2,
            tabs: const [
              Tab(text: 'Todas'),
              Tab(text: 'Pendientes'),
              Tab(text: 'Entregadas'),
            ],
          ),
        ),
        body: ordersAsync.when(
          loading: () => const Center(
              child:
                  CircularProgressIndicator(color: AppColors.accentGold)),
          error: (e, _) => Center(
              child: Text('$e',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.error))),
          data: (orders) {
            final pending = orders
                .where((o) =>
                    o.status == OrderStatus.pending ||
                    o.status == OrderStatus.awaiting_payment ||
                    o.status == OrderStatus.confirmed)
                .toList();
            final delivered = orders
                .where((o) => o.status == OrderStatus.delivered)
                .toList();

            return TabBarView(
              children: [
                _OrderList(
                  orders: orders,
                  emptyTitle: 'Sin órdenes',
                  emptySubtitle: 'Las órdenes de tus clientes aparecerán aquí.',
                  isBuyer: false,
                ),
                _OrderList(
                  orders: pending,
                  emptyTitle: 'Sin órdenes pendientes',
                  isBuyer: false,
                ),
                _OrderList(
                  orders: delivered,
                  emptyTitle: 'Sin órdenes entregadas',
                  isBuyer: false,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Order list ─────────────────────────────────────────────────────────────

class _OrderList extends StatelessWidget {
  final List<OrderModel> orders;
  final String emptyTitle;
  final String? emptySubtitle;
  final bool isBuyer;
  final bool isHistory;

  const _OrderList({
    required this.orders,
    required this.emptyTitle,
    this.emptySubtitle,
    required this.isBuyer,
    this.isHistory = false,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.receipt_long_outlined,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _OrderCard(
        order: orders[i],
        isBuyer: isBuyer,
        isHistory: isHistory,
      ),
    );
  }
}

// ── Order card ─────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final bool isBuyer;
  final bool isHistory;

  const _OrderCard({
    required this.order,
    required this.isBuyer,
    this.isHistory = false,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = order.status == OrderStatus.pending ||
        order.status == OrderStatus.awaiting_payment ||
        order.status == OrderStatus.confirmed;
    final canReview =
        isBuyer && order.status == OrderStatus.delivered;

    // Siempre navega al detalle de la orden — las acciones están allí
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/order-detail/${order.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderOverlay),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title + status ──────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.postTitle,
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(status: order.status),
              ],
            ),
            const SizedBox(height: 6),

            // ── Buyer / vendor info ─────────────────────────────────────
            Text(
              isBuyer
                  ? 'Pedido: ${order.postTitle}'
                  : 'Comprador: ${order.buyerName}',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),

            // ── Price + date + action ───────────────────────────────────
            Row(
              children: [
                Text(
                  '\$${order.finalPrice.toStringAsFixed(order.finalPrice % 1 == 0 ? 0 : 2)}',
                  style: AppTextStyles.body.copyWith(
                      color: AppColors.accentGold,
                      fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  _fmtDate(order.createdAt),
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(width: 8),
                Icon(
                  canReview
                      ? Icons.star_outline_rounded
                      : isActive
                          ? Icons.chat_bubble_outline
                          : Icons.chevron_right,
                  size: 16,
                  color: AppColors.accentGold,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} $h:$m';
  }
}

// ── Status chip ────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final OrderStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      OrderStatus.pending => ('Pendiente', AppColors.accentGold),
      OrderStatus.awaiting_payment => ('Pago pendiente', AppColors.accentGold),
      OrderStatus.confirmed => ('Confirmada', AppColors.success),
      OrderStatus.delivered => ('Entregada', AppColors.accentGreen),
      OrderStatus.cancelled => ('Cancelada', AppColors.textSecondary),
      OrderStatus.rejected => ('Rechazada', AppColors.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption
            .copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
