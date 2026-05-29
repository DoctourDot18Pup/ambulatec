import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/adaptive_scaffold.dart';
import '../../auth/data/auth_controller.dart';
import '../../auth/data/user_provider.dart';
import '../../orders/domain/order_model.dart';
import '../../orders/providers/orders_provider.dart';
import '../providers/vendor_stats_provider.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AdaptiveScaffold(
      currentIndex: 1,
      showVendorFab: true,
      body: _DashboardBody(),
    );
  }
}

// ── Dashboard body ─────────────────────────────────────────────────────────

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;
        return isDesktop
            ? const _DesktopDashboard()
            : const _MobileDashboard();
      },
    );
  }
}

// ── ─────────────────────────────────────────────────────────────────────────
// Mobile dashboard
// ── ─────────────────────────────────────────────────────────────────────────

class _MobileDashboard extends ConsumerWidget {
  const _MobileDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider).asData?.value;
    final ordersAsync = ref.watch(ordersProvider);
    final statsAsync = ref.watch(vendorStatsProvider);

    return SafeArea(
      child: Column(
        children: [
          // ── App bar ─────────────────────────────────────────────────
          Container(
            color: AppColors.bgSurface,
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
            child: Row(
              children: [
                RichText(
                  text: TextSpan(children: [
                    TextSpan(
                      text: 'Ambula',
                      style: AppTextStyles.h3
                          .copyWith(color: AppColors.textPrimary),
                    ),
                    TextSpan(
                      text: 'Tec',
                      style: AppTextStyles.h3
                          .copyWith(color: AppColors.accentGold),
                    ),
                  ]),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: AppColors.textSecondary),
                  onPressed: () {},
                ),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.bgCard,
                  backgroundImage: user?.photoUrl != null
                      ? NetworkImage(user!.photoUrl!)
                      : null,
                  child: user?.photoUrl == null
                      ? const Icon(Icons.person,
                          color: AppColors.textSecondary, size: 16)
                      : null,
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Status toggle ──────────────────────────────────
                  _VendorStatusToggle(),
                  const SizedBox(height: 20),

                  // ── Stats row ─────────────────────────────────────
                  statsAsync.when(
                    loading: () => const _StatsShimmer(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (stats) => _StatsRow(stats: stats),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.go('/earnings'),
                      child: Text('Ver ganancias →',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.accentGold)),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Orders section ────────────────────────────────
                  Row(
                    children: [
                      Text('Órdenes recientes',
                          style: AppTextStyles.h3
                              .copyWith(color: AppColors.textPrimary)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => context.go('/orders'),
                        child: Text('Ver todas',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.accentGold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ordersAsync.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.accentGold)),
                    error: (e, _) => Text(e.toString(),
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.error)),
                    data: (orders) {
                      if (orders.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text('Sin órdenes aún',
                                style: AppTextStyles.body.copyWith(
                                    color: AppColors.textSecondary)),
                          ),
                        );
                      }
                      return Column(
                        children: orders
                            .take(5)
                            .map((o) => _OrderListItem(order: o))
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── ─────────────────────────────────────────────────────────────────────────
// Desktop dashboard
// ── ─────────────────────────────────────────────────────────────────────────

class _DesktopDashboard extends ConsumerWidget {
  const _DesktopDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider).asData?.value;
    final ordersAsync = ref.watch(ordersProvider);
    final statsAsync = ref.watch(vendorStatsProvider);

    final firstName =
        (user?.displayName ?? '').split(' ').first;
    final ordersToday =
        statsAsync.asData?.value.ordersToday ?? 0;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Greeting + controls ────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hola, $firstName 👋',
                        style: AppTextStyles.h1
                            .copyWith(color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$ordersToday ${ordersToday == 1 ? 'orden' : 'órdenes'} hoy',
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                _VendorStatusToggle(),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => context.go('/create-post'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nueva publicación'),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Stats ──────────────────────────────────────────────
            statsAsync.when(
              loading: () => const _StatsShimmer(),
              error: (_, _) => const SizedBox.shrink(),
              data: (stats) => _StatsRow(stats: stats),
            ),
            const SizedBox(height: 32),

            // ── Two-column layout ──────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Orders list
                Expanded(
                  flex: 3,
                  child: _DesktopOrdersPanel(ordersAsync: ordersAsync),
                ),
                const SizedBox(width: 24),
                // Weekly chart
                Expanded(
                  flex: 2,
                  child: _WeeklyChartCard(ordersAsync: ordersAsync),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Vendor status toggle ───────────────────────────────────────────────────

class _VendorStatusToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider).asData?.value;
    final current = user?.vendorAvailability ?? 'active';
    final isLoading = ref.watch(authControllerProvider).isLoading;

    final options = [
      ('active', 'Activo', AppColors.success),
      ('busy', 'En espera', AppColors.accentGold),
      ('offline', 'Offline', AppColors.textSecondary),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderOverlay),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final (value, label, color) = opt;
          final selected = current == value;
          return GestureDetector(
            onTap: isLoading
                ? null
                : () => ref
                    .read(authControllerProvider.notifier)
                    .setVendorAvailability(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: AppTextStyles.caption.copyWith(
                      color: selected
                          ? color
                          : AppColors.textSecondary,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Stats row ──────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final VendorStats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'GANANCIAS',
            value:
                '\$${stats.earningsToday.toStringAsFixed(stats.earningsToday % 1 == 0 ? 0 : 2)}',
            sublabel: 'hoy',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'ÓRDENES',
            value: '${stats.ordersToday}',
            sublabel: 'hoy',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'ACTIVOS',
            value: '${stats.activePosts}',
            sublabel: 'posts',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String sublabel;

  const _StatCard({
    required this.label,
    required this.value,
    required this.sublabel,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value,
              style:
                  AppTextStyles.h2.copyWith(color: AppColors.accentGold)),
          Text(sublabel,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _StatsShimmer extends StatelessWidget {
  const _StatsShimmer();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        3,
        (i) => Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 2 ? 12 : 0),
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Order list item ────────────────────────────────────────────────────────

class _OrderListItem extends StatelessWidget {
  final OrderModel order;
  const _OrderListItem({required this.order});

  Color _statusColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.confirmed:
        return AppColors.success;
      case OrderStatus.delivered:
        return AppColors.accentGreen;
      case OrderStatus.pending:
      case OrderStatus.awaiting_payment:
        return AppColors.accentGold;
      case OrderStatus.cancelled:
      case OrderStatus.rejected:
        return AppColors.error;
    }
  }

  String _statusLabel(OrderStatus s) {
    switch (s) {
      case OrderStatus.confirmed:
        return 'Confirmada';
      case OrderStatus.delivered:
        return 'Entregada';
      case OrderStatus.pending:
        return 'Pendiente';
      case OrderStatus.awaiting_payment:
        return 'Pago pendiente';
      case OrderStatus.cancelled:
        return 'Cancelada';
      case OrderStatus.rejected:
        return 'Rechazada';
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = order.buyerName.isNotEmpty
        ? order.buyerName
            .trim()
            .split(' ')
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
            .take(2)
            .join()
        : '?';

    return GestureDetector(
      onTap: () => context.go('/order-detail/${order.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderOverlay),
        ),
        child: Row(
          children: [
            // Buyer avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.bgSurface,
              child: Text(initials,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textPrimary)),
            ),
            const SizedBox(width: 10),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.buyerName,
                      style: AppTextStyles.body.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                  Text(
                    '${order.postTitle} · #${order.id.substring(0, 6).toUpperCase()}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${order.finalPrice.toStringAsFixed(order.finalPrice % 1 == 0 ? 0 : 2)}',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.accentGold),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(order.status)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(order.status),
                    style: AppTextStyles.caption.copyWith(
                      color: _statusColor(order.status),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Desktop orders panel ───────────────────────────────────────────────────

class _DesktopOrdersPanel extends ConsumerStatefulWidget {
  final AsyncValue<List<OrderModel>> ordersAsync;
  const _DesktopOrdersPanel({required this.ordersAsync});

  @override
  ConsumerState<_DesktopOrdersPanel> createState() =>
      _DesktopOrdersPanelState();
}

class _DesktopOrdersPanelState
    extends ConsumerState<_DesktopOrdersPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOverlay),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.accentGold,
            labelColor: AppColors.accentGold,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: AppTextStyles.body,
            tabs: const [
              Tab(text: 'Todas'),
              Tab(text: 'Pendientes'),
              Tab(text: 'Entregadas'),
            ],
          ),
          SizedBox(
            height: 400,
            child: widget.ordersAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.accentGold)),
              error: (e, _) => Center(
                  child: Text(e.toString(),
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.error))),
              data: (orders) {
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _OrderTab(orders: orders),
                    _OrderTab(
                        orders: orders
                            .where((o) =>
                                o.status == OrderStatus.pending)
                            .toList()),
                    _OrderTab(
                        orders: orders
                            .where((o) =>
                                o.status == OrderStatus.delivered)
                            .toList()),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTab extends StatelessWidget {
  final List<OrderModel> orders;
  const _OrderTab({required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Text('Sin órdenes',
            style: AppTextStyles.body
                .copyWith(color: AppColors.textSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      itemBuilder: (context, i) => _OrderListItem(order: orders[i]),
    );
  }
}

// ── Weekly chart card ──────────────────────────────────────────────────────

class _WeeklyChartCard extends StatelessWidget {
  final AsyncValue<List<OrderModel>> ordersAsync;
  const _WeeklyChartCard({required this.ordersAsync});

  /// Groups delivered orders by day of the current ISO week (Mon=0, Sun=6).
  /// Returns data to use in comments.
  // NOTE: If no real orders exist, all spots will be 0 (flat line).
  List<FlSpot> _weeklySpots(List<OrderModel> orders) {
    final now = DateTime.now();
    // Monday of current week
    final monday =
        now.subtract(Duration(days: now.weekday - 1));
    final weekStart =
        DateTime(monday.year, monday.month, monday.day);

    final earnings = List.generate(7, (i) => 0.0);
    for (final order in orders) {
      if (order.status != OrderStatus.delivered) continue;
      final dayDiff =
          order.createdAt.difference(weekStart).inDays;
      if (dayDiff >= 0 && dayDiff < 7) {
        earnings[dayDiff] += order.finalPrice;
      }
    }
    return List.generate(
        7, (i) => FlSpot(i.toDouble(), earnings[i]));
  }

  double _weekTotal(List<OrderModel> orders) {
    final now = DateTime.now();
    final monday =
        now.subtract(Duration(days: now.weekday - 1));
    final weekStart =
        DateTime(monday.year, monday.month, monday.day);
    return orders
        .where((o) =>
            o.status == OrderStatus.delivered &&
            o.createdAt.isAfter(weekStart))
        .fold(0.0, (sum, o) => sum + o.finalPrice);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOverlay),
      ),
      child: ordersAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(
                color: AppColors.accentGold)),
        error: (_, _) => const SizedBox.shrink(),
        data: (orders) {
          final spots = _weeklySpots(orders);
          final total = _weekTotal(orders);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Esta semana',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.go('/earnings'),
                    child: Text('Ver detalle',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.accentGold)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '\$${total.toStringAsFixed(total % 1 == 0 ? 0 : 2)}',
                style: AppTextStyles.h2
                    .copyWith(color: AppColors.accentGold),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 160,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                          sideTitles:
                              SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles:
                              SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles:
                              SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          getTitlesWidget: (value, meta) {
                            const days = [
                              'L', 'M', 'M', 'J', 'V', 'S', 'D'
                            ];
                            final idx = value.toInt();
                            if (idx < 0 || idx >= days.length) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              days[idx],
                              style: AppTextStyles.caption
                                  .copyWith(
                                      color:
                                          AppColors.textSecondary,
                                      fontSize: 11),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: AppColors.accentGold,
                        barWidth: 2,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.accentGold
                              .withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
