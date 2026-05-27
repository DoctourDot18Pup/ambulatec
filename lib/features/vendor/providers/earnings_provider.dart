import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../orders/domain/order_model.dart';
import '../../orders/providers/orders_provider.dart';

// ── Models ─────────────────────────────────────────────────────────────────

/// Earnings for a single day of the week.
class DayEarnings {
  final String label; // 'L', 'M', 'M', 'J', 'V', 'S', 'D'
  final double amount;
  const DayEarnings({required this.label, required this.amount});
}

/// Computed earnings summary for a vendor, derived from [ordersProvider].
class EarningsData {
  final double todayTotal;
  final double weekTotal;
  final double monthTotal;
  final int todayOrders;
  final int weekOrders;
  final int monthOrders;

  /// Mon–Sun breakdown for the current ISO week.
  final List<DayEarnings> weeklyBreakdown;

  /// Percent change vs previous period (positive = growth).
  /// `null` when previous period had 0 earnings (avoids division by zero).
  final double? dayChangePercent;
  final double? weekChangePercent;
  final double? monthChangePercent;

  /// Orders delivered today (used in the "Hoy" tab list).
  final List<OrderModel> todayOrderList;

  /// Orders delivered this week (used in "Semana" tab list).
  final List<OrderModel> weekOrderList;

  /// Orders delivered this month (used in "Mes" tab list).
  final List<OrderModel> monthOrderList;

  const EarningsData({
    this.todayTotal = 0,
    this.weekTotal = 0,
    this.monthTotal = 0,
    this.todayOrders = 0,
    this.weekOrders = 0,
    this.monthOrders = 0,
    this.weeklyBreakdown = const [],
    this.dayChangePercent,
    this.weekChangePercent,
    this.monthChangePercent,
    this.todayOrderList = const [],
    this.weekOrderList = const [],
    this.monthOrderList = const [],
  });
}

// ── Provider ───────────────────────────────────────────────────────────────

/// Derives [EarningsData] from the live vendor orders stream.
///
/// Only counts orders with [OrderStatus.delivered].
final earningsProvider = Provider<AsyncValue<EarningsData>>((ref) {
  final ordersAsync = ref.watch(ordersProvider);

  return ordersAsync.when(
    loading: () => const AsyncLoading(),
    error: (e, st) => AsyncError(e, st),
    data: (orders) {
      final delivered =
          orders.where((o) => o.status == OrderStatus.delivered).toList();
      final now = DateTime.now();

      // ── Period helpers ─────────────────────────────────────────────────────
      bool isToday(DateTime d) =>
          d.year == now.year && d.month == now.month && d.day == now.day;

      bool isYesterday(DateTime d) {
        final y = now.subtract(const Duration(days: 1));
        return d.year == y.year && d.month == y.month && d.day == y.day;
      }

      // ISO week start (Monday)
      final weekStart =
          DateTime(now.year, now.month, now.day - (now.weekday - 1));
      final lastWeekStart = weekStart.subtract(const Duration(days: 7));

      bool isThisWeek(DateTime d) => !d.isBefore(weekStart);
      bool isLastWeek(DateTime d) =>
          !d.isBefore(lastWeekStart) && d.isBefore(weekStart);

      bool isThisMonth(DateTime d) =>
          d.year == now.year && d.month == now.month;
      bool isLastMonth(DateTime d) {
        final prev = DateTime(now.year, now.month - 1);
        return d.year == prev.year && d.month == prev.month;
      }

      // ── Filter lists ───────────────────────────────────────────────────────
      final todayList =
          delivered.where((o) => isToday(o.createdAt)).toList();
      final weekList =
          delivered.where((o) => isThisWeek(o.createdAt)).toList();
      final monthList =
          delivered.where((o) => isThisMonth(o.createdAt)).toList();

      final yesterdayList =
          delivered.where((o) => isYesterday(o.createdAt)).toList();
      final lastWeekList =
          delivered.where((o) => isLastWeek(o.createdAt)).toList();
      final lastMonthList =
          delivered.where((o) => isLastMonth(o.createdAt)).toList();

      // ── Totals ─────────────────────────────────────────────────────────────
      double sum(List<OrderModel> list) =>
          list.fold(0.0, (acc, o) => acc + o.finalPrice);

      final todayTotal = sum(todayList);
      final weekTotal = sum(weekList);
      final monthTotal = sum(monthList);
      final yesterdayTotal = sum(yesterdayList);
      final lastWeekTotal = sum(lastWeekList);
      final lastMonthTotal = sum(lastMonthList);

      double? changePct(double current, double previous) {
        if (previous == 0) return null;
        return ((current - previous) / previous) * 100;
      }

      // ── Weekly breakdown (Mon–Sun) ─────────────────────────────────────────
      const dayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
      final weeklyBreakdown = List.generate(7, (i) {
        final day = weekStart.add(Duration(days: i));
        final dayTotal = delivered
            .where((o) =>
                o.createdAt.year == day.year &&
                o.createdAt.month == day.month &&
                o.createdAt.day == day.day)
            .fold(0.0, (acc, o) => acc + o.finalPrice);
        return DayEarnings(label: dayLabels[i], amount: dayTotal);
      });

      return AsyncData(EarningsData(
        todayTotal: todayTotal,
        weekTotal: weekTotal,
        monthTotal: monthTotal,
        todayOrders: todayList.length,
        weekOrders: weekList.length,
        monthOrders: monthList.length,
        weeklyBreakdown: weeklyBreakdown,
        dayChangePercent: changePct(todayTotal, yesterdayTotal),
        weekChangePercent: changePct(weekTotal, lastWeekTotal),
        monthChangePercent: changePct(monthTotal, lastMonthTotal),
        todayOrderList: todayList,
        weekOrderList: weekList,
        monthOrderList: monthList,
      ));
    },
  );
});
