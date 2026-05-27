import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/orders/providers/pending_notifications_provider.dart';
import 'firebase_options.dart';
import 'shared/widgets/notification_banner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await NotificationService.initialize();
  } catch (_) {
    // Running without Firebase — auth will always return null (unauthenticated).
  }
  runApp(const ProviderScope(child: AmbulaTecApp()));
}

// ── App root ───────────────────────────────────────────────────────────────

class AmbulaTecApp extends ConsumerWidget {
  const AmbulaTecApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'AmbulaTec',
      theme: AppTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return _NotificationWrapper(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

// ── Notification wrapper ───────────────────────────────────────────────────

/// Wraps the entire widget tree and listens for incoming [AppNotification]s.
///
/// When a new unread notification arrives for the current vendor, a
/// slide-from-top [NotificationBannerController] banner is shown.
/// Tapping the banner marks the notification as read and navigates to
/// `/order-alert/:orderId` so the vendor can accept or reject the order.
///
/// Uses a [Set] to track already-shown notification IDs so that rebuilds
/// and stream replays never show the same banner twice.
class _NotificationWrapper extends ConsumerStatefulWidget {
  final Widget child;
  const _NotificationWrapper({required this.child});

  @override
  ConsumerState<_NotificationWrapper> createState() =>
      _NotificationWrapperState();
}

class _NotificationWrapperState
    extends ConsumerState<_NotificationWrapper> {
  /// IDs of notifications that have already triggered a banner this session.
  final Set<String> _shownIds = {};

  @override
  Widget build(BuildContext context) {
    // ref.listen re-registers on each build but Riverpod deduplicates it
    // for the same provider.
    ref.listen<AsyncValue<List<AppNotification>>>(
      pendingNotificationsProvider,
      (_, next) {
        final notifications = next.asData?.value ?? [];
        for (final n in notifications) {
          if (_shownIds.contains(n.id)) continue;
          _shownIds.add(n.id);
          _showBanner(n);
        }
      },
    );

    return widget.child;
  }

  void _showBanner(AppNotification n) {
    if (!mounted) return;
    final isDelivered = n.type == 'order_delivered';
    NotificationBannerController.show(
      context: context,
      title: isDelivered ? '¡Tu pedido llegó!' : '¡Nuevo pedido!',
      body: isDelivered
          ? 'Califica tu experiencia con ${n.productTitle}'
          : '${n.buyerName} quiere: ${n.productTitle}',
      onTap: () {
        markNotificationRead(n.id);
        final route = isDelivered
            ? '/review/${n.orderId}'
            : '/order-alert/${n.orderId}';
        ref.read(routerProvider).go(route);
      },
    );
  }
}
