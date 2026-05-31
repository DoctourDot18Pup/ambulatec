import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/orders/providers/pending_notifications_provider.dart';
import 'features/profile/providers/notification_preferences_provider.dart';
import 'firebase_options.dart';
import 'shared/widgets/notification_banner.dart';

/// Holds a route string received from an FCM notification tap.
/// Cleared after the app navigates to it.
class _PendingRoute extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String route) => state = route;
  void clear() => state = null;
}

/// Pending navigation route from a notification tap (local or FCM).
final pendingRouteProvider =
    NotifierProvider<_PendingRoute, String?>(_PendingRoute.new);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await GoogleSignIn.instance.initialize();
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

class _NotificationWrapperState extends ConsumerState<_NotificationWrapper>
    with WidgetsBindingObserver {
  final Set<String> _shownIds = {};
  bool _isBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Forward local notification taps to the pending route provider.
    NotificationService.onNotificationTap = (route) {
      if (mounted) ref.read(pendingRouteProvider.notifier).set(route);
    };

    // Handle FCM tap when app was backgrounded or terminated.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final route = message.data['route'] as String?;
      if (route != null && mounted) {
        ref.read(pendingRouteProvider.notifier).set(route);
      }
    });
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      final route = message?.data['route'] as String?;
      if (route != null && mounted) {
        ref.read(pendingRouteProvider.notifier).set(route);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isBackground = state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden;
  }

  @override
  Widget build(BuildContext context) {
    // Navigate when a notification tap sets a pending route.
    ref.listen<String?>(pendingRouteProvider, (_, route) {
      if (route == null) return;
      ref.read(pendingRouteProvider.notifier).clear();
      final ctx = ref
          .read(routerProvider)
          .routerDelegate
          .navigatorKey
          .currentContext;
      if (ctx != null) ref.read(routerProvider).go(route);
    });

    final notificationsEnabled = ref.watch(notificationPreferencesProvider);

    ref.listen<AsyncValue<List<AppNotification>>>(
      pendingNotificationsProvider,
      (_, next) {
        if (!notificationsEnabled) return;
        final notifications = next.asData?.value ?? [];
        for (final n in notifications) {
          if (_shownIds.contains(n.id)) continue;
          _shownIds.add(n.id);
          _handleNotification(n);
        }
      },
    );

    return widget.child;
  }

  void _handleNotification(AppNotification n) {
    if (!mounted) return;

    final isDelivered = n.type == 'order_delivered';
    final isNewOrder = n.type == 'new_order';

    final title = isDelivered
        ? '¡Tu pedido llegó!'
        : isNewOrder
            ? '¡Nuevo pedido!'
            : '¡Actualización de pedido!';

    final body = isDelivered
        ? 'Califica tu experiencia con ${n.productTitle}'
        : isNewOrder
            ? '${n.buyerName} quiere: ${n.productTitle}'
            : n.productTitle;

    final route = isDelivered
        ? '/review/${n.orderId}'
        : isNewOrder
            ? '/order-alert/${n.orderId}'
            : '/chat/${n.orderId}';

    if (_isBackground) {
      // App minimizada → notificación del sistema operativo.
      NotificationService.showLocal(title: title, body: body, route: route);
      return;
    }

    // App en primer plano → banner in-app.
    final ctx =
        ref.read(routerProvider).routerDelegate.navigatorKey.currentContext;
    if (ctx == null) return;
    NotificationBannerController.show(
      context: ctx,
      title: title,
      body: body,
      onTap: () {
        markNotificationRead(n.id);
        ref.read(routerProvider).go(route);
      },
    );
  }
}
