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
class _PendingFcmRoute extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String route) => state = route;
  void clear() => state = null;
}

final pendingFcmRouteProvider =
    NotifierProvider<_PendingFcmRoute, String?>(_PendingFcmRoute.new);

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

class _NotificationWrapperState
    extends ConsumerState<_NotificationWrapper> {
  /// IDs of notifications that have already triggered a banner this session.
  final Set<String> _shownIds = {};

  @override
  void initState() {
    super.initState();
    _initFcmTapHandlers();
  }

  /// Handles the two cases where a user taps an FCM notification:
  /// 1. App in background → [FirebaseMessaging.onMessageOpenedApp]
  /// 2. App terminated → [FirebaseMessaging.instance.getInitialMessage]
  Future<void> _initFcmTapHandlers() async {
    // Case 1 — app was backgrounded when user tapped the notification.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final route = message.data['route'] as String?;
      if (route != null && mounted) {
        ref.read(pendingFcmRouteProvider.notifier).set(route);
      }
    });

    // Case 2 — app was terminated; launched by tapping the notification.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    final route = initial?.data['route'] as String?;
    if (route != null && mounted) {
      ref.read(pendingFcmRouteProvider.notifier).set(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Navigate when an FCM tap sets a pending route.
    ref.listen<String?>(pendingFcmRouteProvider, (_, route) {
      if (route == null) return;
      ref.read(pendingFcmRouteProvider.notifier).clear();
      final ctx = ref
          .read(routerProvider)
          .routerDelegate
          .navigatorKey
          .currentContext;
      if (ctx != null) ref.read(routerProvider).go(route);
    });
    // ref.listen re-registers on each build but Riverpod deduplicates it
    // for the same provider.
    final notificationsEnabled = ref.watch(notificationPreferencesProvider);

    ref.listen<AsyncValue<List<AppNotification>>>(
      pendingNotificationsProvider,
      (_, next) {
        if (!notificationsEnabled) return;
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
    // Use the navigator key so the context is inside the Navigator/Overlay.
    final ctx =
        ref.read(routerProvider).routerDelegate.navigatorKey.currentContext;
    if (ctx == null) return;
    final isDelivered = n.type == 'order_delivered';
    NotificationBannerController.show(
      context: ctx,
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
