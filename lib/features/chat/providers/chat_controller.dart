import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../orders/domain/order_model.dart';
import '../domain/message_model.dart';

// ── Chat controller ────────────────────────────────────────────────────────

/// Provides chat interaction methods and order status transitions.
///
/// All public methods are `async` and guard against null auth.
class ChatController {
  const ChatController();

  // ── Messages ───────────────────────────────────────────────────────────────

  /// Sends a text message from the current Firebase user.
  Future<void> sendMessage(String orderId, String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || text.trim().isEmpty) return;

    final msg = MessageModel(
      id: '',
      senderId: user.uid,
      senderName: user.displayName ?? 'Usuario',
      senderPhotoUrl: user.photoURL,
      text: text.trim(),
      createdAt: DateTime.now(),
    );

    await FirebaseFirestore.instance
        .collection(AppConstants.chatsCollection)
        .doc(orderId)
        .collection('messages')
        .add(msg.toMap());
  }

  // ── Order transitions ──────────────────────────────────────────────────────

  /// Vendor confirms the order: `pending → confirmed`.
  ///
  /// Writes a system message to the chat so both parties see the update.
  Future<void> confirmOrder(String orderId) async {
    await FirebaseFirestore.instance
        .collection(AppConstants.ordersCollection)
        .doc(orderId)
        .update({
      'status': OrderStatus.confirmed.name,
      'confirmedAt': Timestamp.fromDate(DateTime.now()),
    });
    await _addSystemMessage(
        orderId, '✅ Vendedor confirmó el pedido. ¡Ya está en preparación!');
  }

  /// Vendor rejects the order: `pending → rejected`.
  Future<void> rejectOrder(String orderId) async {
    await FirebaseFirestore.instance
        .collection(AppConstants.ordersCollection)
        .doc(orderId)
        .update({'status': OrderStatus.rejected.name});
    await _addSystemMessage(
        orderId, '❌ El vendedor no pudo aceptar este pedido.');
  }

  /// Vendor marks the order as delivered: `confirmed → delivered`.
  ///
  /// Also writes an `order_delivered` notification directed at the buyer
  /// so the [_NotificationWrapper] can show them the review banner.
  Future<void> markDelivered(OrderModel order) async {
    await FirebaseFirestore.instance
        .collection(AppConstants.ordersCollection)
        .doc(order.id)
        .update({
      'status': OrderStatus.delivered.name,
      'deliveredAt': Timestamp.fromDate(DateTime.now()),
    });
    await _addSystemMessage(
        order.id, '🎉 ¡El vendedor marcó el pedido como entregado!');

    // Notify the buyer so they can leave a review.
    await FirebaseFirestore.instance
        .collection(AppConstants.notificationsCollection)
        .add({
      'type': 'order_delivered',
      'recipientId': order.buyerId, // buyer receives this
      'buyerId': order.buyerId,
      'vendorId': order.vendorId,
      'orderId': order.id,
      'buyerName': order.buyerName,
      'productTitle': order.postTitle,
      'status': 'unread',
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ── Internal helpers ───────────────────────────────────────────────────────

  Future<void> _addSystemMessage(String orderId, String text) async {
    final msg = MessageModel(
      id: '',
      senderId: 'system',
      senderName: 'Sistema',
      text: text,
      createdAt: DateTime.now(),
      isSystem: true,
    );
    await FirebaseFirestore.instance
        .collection(AppConstants.chatsCollection)
        .doc(orderId)
        .collection('messages')
        .add(msg.toMap());
  }
}

// ── Provider ───────────────────────────────────────────────────────────────

final chatControllerProvider =
    Provider<ChatController>((_) => const ChatController());
