import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/notification_service.dart';

const _kKey = 'notifications_enabled';

final notificationPreferencesProvider =
    NotifierProvider<NotificationPreferencesNotifier, bool>(
        NotificationPreferencesNotifier.new);

class NotificationPreferencesNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kKey) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kKey, value);

    try {
      if (!value) {
        // Unsubscribe from FCM push so the server stops sending pushes.
        await FirebaseMessaging.instance.deleteToken();
      } else {
        // Re-subscribe: request permission + get a fresh FCM token.
        await NotificationService.initialize();
      }
    } catch (_) {
      // FCM may be unavailable (web without VAPID, emulator, etc.) — the
      // in-app banner suppression via [state] still works regardless.
    }
  }
}
