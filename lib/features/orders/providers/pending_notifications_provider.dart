import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_provider.dart';
import '../../../core/constants/app_constants.dart';

// ── Model ──────────────────────────────────────────────────────────────────

/// A single unread notification document from Firestore.
///
/// All notifications include a `recipientId` field so that both
/// vendor (new-order) and buyer (order-delivered) notifications
/// can be queried with a single `where('recipientId', isEqualTo: uid)`.
///
/// Known types:
///   `'new_order'`       — written by [PaymentPage] → vendor receives it.
///   `'order_delivered'` — written by [ChatController] → buyer receives it.
class AppNotification {
  final String id;
  final String orderId;
  final String vendorId;
  final String buyerName;
  final String productTitle;
  final DateTime createdAt;

  /// Notification type. `null` treated as `'new_order'` for back-compat.
  final String? type;

  /// `'unread'` or `'read'`. Used by the history screen to highlight pending items.
  final String status;

  const AppNotification({
    required this.id,
    required this.orderId,
    required this.vendorId,
    required this.buyerName,
    required this.productTitle,
    required this.createdAt,
    this.type,
    this.status = 'unread',
  });

  factory AppNotification.fromMap(Map<String, dynamic> map, String id) {
    return AppNotification(
      id: id,
      orderId: map['orderId'] as String? ?? id,
      vendorId: map['vendorId'] as String? ?? '',
      buyerName: map['buyerName'] as String? ?? '',
      productTitle: map['productTitle'] as String? ?? '',
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: map['type'] as String?,
      status: map['status'] as String? ?? 'unread',
    );
  }

  bool get isUnread => status == 'unread';
}

// ── Provider ───────────────────────────────────────────────────────────────

/// Streams unread [AppNotification]s for the currently authenticated user.
///
/// Uses a `recipientId` field that is set on **all** notification documents
/// (both vendor new-order alerts and buyer delivery alerts), so a single
/// query covers every notification type without OR logic.
///
/// Requires a Firestore composite index:
///   Collection: notifications | recipientId ASC, status ASC, createdAt DESC
final pendingNotificationsProvider =
    StreamProvider<List<AppNotification>>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection(AppConstants.notificationsCollection)
      .where('recipientId', isEqualTo: user.uid)
      .where('status', isEqualTo: 'unread')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => AppNotification.fromMap(d.data(), d.id))
          .toList());
});

// ── Helper ─────────────────────────────────────────────────────────────────

/// Marks a notification document as read so it disappears from the stream.
Future<void> markNotificationRead(String notificationId) async {
  await FirebaseFirestore.instance
      .collection(AppConstants.notificationsCollection)
      .doc(notificationId)
      .update({'status': 'read'});
}
