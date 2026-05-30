import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../auth/data/auth_provider.dart';
import '../../orders/providers/pending_notifications_provider.dart';

/// Streams the last 50 notifications for the current user (read + unread),
/// newest first. Used by the notification history screen.
final notificationHistoryProvider =
    StreamProvider<List<AppNotification>>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection(AppConstants.notificationsCollection)
      .where('recipientId', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => AppNotification.fromMap(d.data(), d.id))
          .toList());
});
