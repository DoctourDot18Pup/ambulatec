import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

/// Initialises Firebase Cloud Messaging for push notifications.
///
/// - **Web**: requests browser permission and retrieves token with VAPID key.
/// - **Android / iOS**: requests OS permission and retrieves token without
///   VAPID key.  The token is printed to the debug console so it can be used
///   for manual test sends from the Firebase Console.
///
/// In-app banners are driven by the Firestore `notifications/` collection and
/// do not require a Blaze plan or FCM server sends.
class NotificationService {
  NotificationService._();

  static Future<void> initialize() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // ── Request permission ─────────────────────────────────────────────
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // ── Retrieve FCM token ─────────────────────────────────────────────
      final String? token;
      if (kIsWeb) {
        token = await messaging.getToken(
          vapidKey: AppConstants.fcmVapidKey,
        );
      } else {
        // Android & iOS — no VAPID key needed.
        token = await messaging.getToken();
      }

      assert(() {
        // ignore: avoid_print
        print('[FCM] Token (${kIsWeb ? 'web' : 'native'}): $token');
        return true;
      }());
    } catch (_) {
      // FCM unavailable (missing VAPID / no Play Services / simulator).
      // Firestore-based in-app notifications continue to work normally.
    }
  }
}
