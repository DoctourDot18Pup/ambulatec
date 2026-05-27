import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/animated_counter_widget.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../orders/domain/order_model.dart';
import '../providers/earnings_provider.dart';

// ── Page ───────────────────────────────────────────────────────────────────

class EarningsPage extends ConsumerWidget {
  const EarningsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        leading: BackButton(
          color: AppColors.textPrimary,
          onPressed: () => context.go('/dashboard'),
        ),
        title: Text('Ganancias',
            style:
                AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            // ── Tab bar ──────────────────────────────────────────────
            Container(
              color: AppColors.bgSurface,
              child: TabBar(
                labelColor: AppColors.accentGold,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: AppTextStyles.body
                    .copyWith(fontWeight: FontWeight.w600),
                unselectedLabelStyle: AppTextStyles.body,
                indicatorColor: AppColors.accentGold,
                indicatorWeight: 2,
                tabs: const [
                  Tab(text: 'Hoy'),
                  Tab(text: 'Semana'),
                  Tab(text: 'Mes'),
                ],
              ),
            ),

            // ── Tab views ────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                children: [
                  _TodayTab(),
                  _PeriodTab(period: _Period.week),
                  _PeriodTab(period: _Period.month),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Period enum ────────────────────────────────────────────────────────────

enum _Period { week, month }

// ── Today tab ──────────────────────────────────────────────────────────────

class _TodayTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earningsAsync = ref.watch(earningsProvider);

    return earningsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accentGold)),
      error: (e, _) => Center(
          child: Text('$e',
              style:
                  AppTextStyles.body.copyWith(color: AppColors.error))),
      data: (data) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SummaryCard(
            label: 'Hoy',
            total: data.todayTotal,
            orderCount: data.todayOrders,
            changePercent: data.dayChangePercent,
          ),
          const SizedBox(height: 20),
          if (data.todayOrderList.isEmpty)
            const EmptyStateWidget(
              icon: Icons.receipt_long_outlined,
              title: 'Sin órdenes hoy',
              subtitle: 'Las ventas completadas de hoy aparecerán aquí.',
            )
          else ...[
            Text('ÓRDENES DEL DÍA',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            ...data.todayOrderList.map((o) => _OrderRow(order: o)),
          ],
        ],
      ),
    );
  }
}

// ── Week / Month tab ───────────────────────────────────────────────────────

class _PeriodTab extends ConsumerWidget {
  final _Period period;
  const _PeriodTab({required this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earningsAsync = ref.watch(earningsProvider);

    return earningsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accentGold)),
      error: (e, _) => Center(
          child: Text('$e',
              style:
                  AppTextStyles.body.copyWith(color: AppColors.error))),
      data: (data) {
        final isWeek = period == _Period.week;
        final total = isWeek ? data.weekTotal : data.monthTotal;
        final count = isWeek ? data.weekOrders : data.monthOrders;
        final change = isWeek
            ? data.weekChangePercent
            : data.monthChangePercent;
        final orders = isWeek ? data.weekOrderList : data.monthOrderList;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 1024;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: isDesktop ? 800 : double.infinity),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _SummaryCard(
                      label: isWeek ? 'Esta semana' : 'Este mes',
                      total: total,
                      orderCount: count,
                      changePercent: change,
                    ),
                    const SizedBox(height: 20),

                    // ── Line chart ──────────────────────────────────
                    if (isWeek)
                      _WeeklyChart(
                          breakdown: data.weeklyBreakdown,
                          height: isDesktop ? 200 : 160),
                    const SizedBox(height: 20),

                    // ── Orders list ─────────────────────────────────
                    if (orders.isEmpty)
                      EmptyStateWidget(
                        icon: Icons.receipt_long_outlined,
                        title: isWeek
                            ? 'Sin ventas esta semana'
                            : 'Sin ventas este mes',
                      )
                    else ...[
                      Text('ÓRDENES PAGADAS',
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      ...orders.map((o) => _OrderRow(order: o)),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Summary card ───────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final double total;
  final int orderCount;
  final double? changePercent;

  const _SummaryCard({
    required this.label,
    required this.total,
    required this.orderCount,
    this.changePercent,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),

          // Animated total
          AnimatedCounterWidget(
            value: total,
            formatter: (v) =>
                '\$${v.toStringAsFixed(v % 1 < 0.01 ? 0 : 2)}',
            style: AppTextStyles.h1
                .copyWith(color: AppColors.accentGold, fontSize: 32),
          ),
          const SizedBox(height: 6),

          Row(
            children: [
              Text('$orderCount órdenes completadas',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary)),
              if (changePercent != null) ...[
                const SizedBox(width: 12),
                _ChangeBadge(percent: changePercent!),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Change badge ───────────────────────────────────────────────────────────

class _ChangeBadge extends StatelessWidget {
  final double percent;
  const _ChangeBadge({required this.percent});

  @override
  Widget build(BuildContext context) {
    final isPositive = percent >= 0;
    final color = isPositive ? AppColors.success : AppColors.error;
    final prefix = isPositive ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$prefix${percent.toStringAsFixed(1)}%',
        style: AppTextStyles.caption
            .copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Weekly line chart ──────────────────────────────────────────────────────

class _WeeklyChart extends StatelessWidget {
  final List<DayEarnings> breakdown;
  final double height;
  const _WeeklyChart({required this.breakdown, required this.height});

  @override
  Widget build(BuildContext context) {
    final spots = breakdown.isEmpty
        ? [const FlSpot(0, 0)]
        : breakdown
            .asMap()
            .entries
            .map((e) => FlSpot(e.key.toDouble(), e.value.amount))
            .toList();

    final maxY = breakdown.isEmpty
        ? 1.0
        : breakdown.map((d) => d.amount).reduce((a, b) => a > b ? a : b) *
            1.2;

    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOverlay),
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY < 1 ? 1 : maxY,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, _) {
                  final i = value.toInt();
                  if (i < 0 || i >= breakdown.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      breakdown[i].label,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
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
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, _, _, _) =>
                    FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.accentGold,
                  strokeWidth: 0,
                  strokeColor: Colors.transparent,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.accentGold.withValues(alpha: 0.10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Order row ──────────────────────────────────────────────────────────────

class _OrderRow extends StatelessWidget {
  final OrderModel order;
  const _OrderRow({required this.order});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Initials avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.accentGreen,
            child: Text(
              order.buyerName.isNotEmpty
                  ? order.buyerName[0].toUpperCase()
                  : '?',
              style: AppTextStyles.caption
                  .copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.buyerName,
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis),
                Text(
                  '#AT-${order.id.substring(0, 6).toUpperCase()} · ${_fmtDate(order.createdAt)}',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            '+\$${order.finalPrice.toStringAsFixed(order.finalPrice % 1 == 0 ? 0 : 2)}',
            style: AppTextStyles.body
                .copyWith(color: AppColors.success, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month} $h:$m';
  }
}
