import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../orders/domain/order_model.dart';
import '../domain/message_model.dart';

// ── Messages ───────────────────────────────────────────────────────────────

/// Live stream of [MessageModel] for a given order's chat.
///
/// Messages are stored in `chats/{orderId}/messages/` ordered by
/// [MessageModel.createdAt] ascending.
final chatMessagesProvider = StreamProvider.autoDispose
    .family<List<MessageModel>, String>((ref, orderId) {
  return FirebaseFirestore.instance
      .collection(AppConstants.chatsCollection)
      .doc(orderId)
      .collection('messages')
      .orderBy('createdAt')
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => MessageModel.fromMap(d.data(), d.id))
          .toList());
});

// ── Order ──────────────────────────────────────────────────────────────────

/// Live stream of a single [OrderModel] by its Firestore document ID.
///
/// Emits `null` when the document does not exist.
final orderByIdProvider =
    StreamProvider.autoDispose.family<OrderModel?, String>((ref, orderId) {
  return FirebaseFirestore.instance
      .collection(AppConstants.ordersCollection)
      .doc(orderId)
      .snapshots()
      .map((snap) =>
          snap.exists ? OrderModel.fromMap(snap.id, snap.data()!) : null);
});

// ── Countdown timer ────────────────────────────────────────────────────────

/// Emits the [Duration] remaining until [deadline], ticking every second.
///
/// Emits [Duration.zero] once the deadline has passed and stops ticking.
///
/// Usage:
/// ```dart
/// final countdown = ref.watch(countdownProvider(order.chatExpiresAt));
/// ```
final countdownProvider =
    StreamProvider.autoDispose.family<Duration, DateTime>((ref, deadline) {
  return Stream.periodic(const Duration(seconds: 1), (_) {
    final remaining = deadline.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  });
});
