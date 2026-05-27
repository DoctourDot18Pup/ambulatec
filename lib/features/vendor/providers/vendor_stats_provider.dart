import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../orders/domain/order_model.dart';
import '../../orders/providers/orders_provider.dart';
import 'vendor_posts_provider.dart';

// ── Stats model ────────────────────────────────────────────────────────────

class VendorStats {
  final double earningsToday;
  final int ordersToday;
  final int activePosts;

  const VendorStats({
    this.earningsToday = 0,
    this.ordersToday = 0,
    this.activePosts = 0,
  });
}

// ── Provider ───────────────────────────────────────────────────────────────

/// Derives [VendorStats] from live Firestore streams.
/// Returns [AsyncLoading] while either stream is loading.
final vendorStatsProvider = Provider<AsyncValue<VendorStats>>((ref) {
  final ordersAsync = ref.watch(ordersProvider);
  final postsAsync = ref.watch(vendorPostsProvider);

  return ordersAsync.when(
    loading: () => const AsyncLoading(),
    error: (e, st) => AsyncError(e, st),
    data: (orders) {
      final now = DateTime.now();

      // Filter to today's orders.
      final todayOrders = orders.where((o) {
        final d = o.createdAt;
        return d.year == now.year &&
            d.month == now.month &&
            d.day == now.day;
      }).toList();

      final earningsToday = todayOrders
          .where((o) => o.status == OrderStatus.delivered)
          .fold(0.0, (sum, o) => sum + o.finalPrice);

      final ordersToday = todayOrders
          .where((o) => o.status != OrderStatus.cancelled)
          .length;

      final activePosts = postsAsync.asData?.value
              .where((p) => p.isActive)
              .length ??
          0;

      return AsyncData(VendorStats(
        earningsToday: earningsToday,
        ordersToday: ordersToday,
        activePosts: activePosts,
      ));
    },
  );
});
