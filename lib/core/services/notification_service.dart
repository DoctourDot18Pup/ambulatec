import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../constants/app_constants.dart';

// ── Background FCM handler (top-level, required by Firebase) ──────────────

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized. Navigation is handled via
  // onMessageOpenedApp / getInitialMessage when the user taps the notification.
}

// ── Notification channel ───────────────────────────────────────────────────

const _kChannelId = 'ambulatec_orders';
const _kChannelName = 'Pedidos AmbulaTec';

const _kChannel = AndroidNotificationChannel(
  _kChannelId,
  _kChannelName,
  description: 'Notificaciones de nuevos pedidos y actualizaciones de entrega.',
  importance: Importance.high,
);

// ── Service ────────────────────────────────────────────────────────────────

class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Called when the user taps a local notification.
  /// Set this in the widget tree to handle navigation.
  static void Function(String route)? onNotificationTap;

  static Future<void> initialize() async {
    try {
      // ── Local notifications setup ────────────────────────────────────
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(
        const InitializationSettings(android: androidSettings),
        onDidReceiveNotificationResponse: (details) {
          final route = details.payload;
          if (route != null) onNotificationTap?.call(route);
        },
      );

      // Create the high-priority channel (Android 8+)
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_kChannel);

      // ── FCM setup ────────────────────────────────────────────────────
      FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler);

      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final String? token;
      if (kIsWeb) {
        token = await FirebaseMessaging.instance.getToken(
          vapidKey: AppConstants.fcmVapidKey,
        );
      } else {
        token = await FirebaseMessaging.instance.getToken();
      }

      assert(() {
        // ignore: avoid_print
        print('[FCM] Token (${kIsWeb ? 'web' : 'native'}): $token');
        return true;
      }());

      // Persist token so future server-side sends can target this device.
      if (token != null) {
        await _saveToken(token);
        FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);
      }
    } catch (_) {
      // FCM / local notifications unavailable — in-app banners still work.
    }
  }

  /// Shows a system-level local notification visible even when the app
  /// is in the background. [route] is stored as the notification payload
  /// and forwarded to [onNotificationTap] when the user taps it.
  static Future<void> showLocal({
    required String title,
    required String body,
    required String route,
  }) async {
    if (kIsWeb) return; // Local notifications are Android/iOS only.
    try {
      await _plugin.show(
        route.hashCode.abs() % 2147483647,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _kChannelId,
            _kChannelName,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: route,
      );
    } catch (_) {}
  }

  static Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .update({'fcmTokens': FieldValue.arrayUnion([token])});
    } catch (_) {}
  }
}
