import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

/// Top-level handler required by FCM for background messages.
/// Must be a bare top-level function annotated with @pragma('vm:entry-point').
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized by the time this runs on Android.
  // No additional work needed here — navigation is handled via
  // onMessageOpenedApp / getInitialMessage when the user taps the notification.
}

class NotificationService {
  NotificationService._();

  static Future<void> initialize() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Register background handler before anything else.
      FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler);

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
        token = await messaging.getToken();
      }

      assert(() {
        // ignore: avoid_print
        print('[FCM] Token (${kIsWeb ? 'web' : 'native'}): $token');
        return true;
      }());

      // ── Persist token in Firestore ─────────────────────────────────────
      if (token != null) {
        await _saveToken(token);
        // Keep token current if FCM rotates it.
        messaging.onTokenRefresh.listen(_saveToken);
      }
    } catch (_) {
      // FCM unavailable (missing VAPID / no Play Services / simulator).
      // Firestore-based in-app notifications continue to work normally.
    }
  }

  /// Stores [token] in the current user's `fcmTokens` array in Firestore.
  /// Safe to call multiple times — arrayUnion deduplicates automatically.
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
