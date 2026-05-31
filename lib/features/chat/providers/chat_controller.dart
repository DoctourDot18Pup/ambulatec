import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../orders/domain/order_model.dart';
import '../domain/message_model.dart';

// ── Chat controller ────────────────────────────────────────────────────────

class ChatController {
  const ChatController();

  // ── Messages ───────────────────────────────────────────────────────────────

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

  /// Vendor accepts: `pending → awaiting_payment`.
  /// Optional [quantity] overrides the buyer-requested amount and recalculates
  /// [finalPrice] = [OrderModel.originalPrice] × quantity.
  Future<void> confirmOrder(OrderModel order, {int? quantity}) async {
    final Map<String, dynamic> update = {
      'status': OrderStatus.awaiting_payment.name,
    };
    if (quantity != null && quantity != order.quantity) {
      update['quantity'] = quantity;
      update['finalPrice'] = order.originalPrice * quantity;
    }

    await FirebaseFirestore.instance
        .collection(AppConstants.ordersCollection)
        .doc(order.id)
        .update(update);

    final qtyNote =
        (quantity != null && quantity != order.quantity)
            ? ' Cantidad ajustada a $quantity.'
            : '';

    await _addSystemMessage(
        order.id,
        '¡El vendedor aceptó tu pedido!$qtyNote Procede al pago para confirmarlo.');

    await FirebaseFirestore.instance
        .collection(AppConstants.notificationsCollection)
        .add({
      'type': 'awaiting_payment',
      'recipientId': order.buyerId,
      'vendorId': order.vendorId,
      'orderId': order.id,
      'buyerName': order.buyerName,
      'productTitle': order.postTitle,
      'status': 'unread',
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Vendor adjusts quantity after acceptance (while `awaiting_payment`).
  /// Throws if [paymentLockedAt] is active (buyer is in checkout).
  Future<void> updateQuantityAndBill(OrderModel order, int quantity) async {
    final locked = order.paymentLockedAt;
    if (locked != null &&
        DateTime.now().difference(locked).inMinutes < 5) {
      throw Exception(
          'No se puede ajustar la cantidad mientras el comprador está procesando el pago.');
    }

    final newTotal = order.originalPrice * quantity;
    await FirebaseFirestore.instance
        .collection(AppConstants.ordersCollection)
        .doc(order.id)
        .update({
      'quantity': quantity,
      'finalPrice': newTotal,
    });

    final fmt = newTotal % 1 == 0
        ? newTotal.toStringAsFixed(0)
        : newTotal.toStringAsFixed(2);
    await _addSystemMessage(
        order.id,
        'El vendedor ajustó la cantidad a $quantity. Nuevo total: \$$fmt');
  }

  /// Vendor rejects: `pending → rejected`.
  /// Also auto-deactivates the post so it won't receive new requests.
  Future<void> rejectOrder(OrderModel order) async {
    await FirebaseFirestore.instance
        .collection(AppConstants.ordersCollection)
        .doc(order.id)
        .update({'status': OrderStatus.rejected.name});

    // Auto-deactivate the associated post.
    if (order.postId.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection(AppConstants.postsCollection)
          .doc(order.postId)
          .update({'isActive': false});
    }

    await _addSystemMessage(
        order.id, 'El vendedor no pudo aceptar este pedido.');
  }

  /// Called after buyer pays: `awaiting_payment → confirmed`.
  /// Sets `deliveryDeadlineAt` to 1 hour from now.
  Future<void> markPaid(OrderModel order) async {
    final deadline = DateTime.now().add(const Duration(hours: 1));
    await FirebaseFirestore.instance
        .collection(AppConstants.ordersCollection)
        .doc(order.id)
        .update({
      'status': OrderStatus.confirmed.name,
      'confirmedAt': Timestamp.fromDate(DateTime.now()),
      'deliveryDeadlineAt': Timestamp.fromDate(deadline),
    });

    await _addSystemMessage(order.id,
        '¡Pago recibido! El vendedor tiene 1 hora para entregar tu pedido.');

    // Notify vendor that payment was received.
    await FirebaseFirestore.instance
        .collection(AppConstants.notificationsCollection)
        .add({
      'type': 'payment_received',
      'recipientId': order.vendorId,
      'vendorId': order.vendorId,
      'orderId': order.id,
      'buyerName': order.buyerName,
      'productTitle': order.postTitle,
      'status': 'unread',
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Vendor marks delivered: `confirmed → delivered`.
  Future<void> markDelivered(OrderModel order) async {
    await FirebaseFirestore.instance
        .collection(AppConstants.ordersCollection)
        .doc(order.id)
        .update({
      'status': OrderStatus.delivered.name,
      'deliveredAt': Timestamp.fromDate(DateTime.now()),
    });
    await _addSystemMessage(
        order.id, '¡El vendedor marcó el pedido como entregado!');

    // Notify buyer to leave a review.
    await FirebaseFirestore.instance
        .collection(AppConstants.notificationsCollection)
        .add({
      'type': 'order_delivered',
      'recipientId': order.buyerId,
      'buyerId': order.buyerId,
      'vendorId': order.vendorId,
      'orderId': order.id,
      'buyerName': order.buyerName,
      'productTitle': order.postTitle,
      'status': 'unread',
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Auto-refund simulation: vendor missed the 1-hour deadline.
  /// Sets order to `cancelled`, flags the vendor.
  Future<void> autoRefundExpired(OrderModel order) async {
    await FirebaseFirestore.instance
        .collection(AppConstants.ordersCollection)
        .doc(order.id)
        .update({
      'status': OrderStatus.cancelled.name,
      'isFlagged': true,
    });

    // Increment vendor flag count in user document.
    await FirebaseFirestore.instance
        .collection(AppConstants.usersCollection)
        .doc(order.vendorId)
        .update({'flagCount': FieldValue.increment(1)});

    await _addSystemMessage(
        order.id,
        'El tiempo de entrega expiró. El pedido fue cancelado y se '
        'procesó el reembolso automático.');
  }

  // ── Post re-activation ────────────────────────────────────────────────────

  /// Re-activates the post that was deactivated when this order was rejected.
  /// Notifies the buyer so they can place a new order.
  Future<void> reactivatePost(OrderModel order) async {
    if (order.postId.isEmpty) return;

    await FirebaseFirestore.instance
        .collection(AppConstants.postsCollection)
        .doc(order.postId)
        .update({'isActive': true});

    // Mark the order so the "Reactivar" button no longer appears.
    await FirebaseFirestore.instance
        .collection(AppConstants.ordersCollection)
        .doc(order.id)
        .update({'postReactivated': true});

    await _addSystemMessage(
        order.id,
        'El vendedor reactivó la publicación. ¡Ya puedes hacer un nuevo pedido!');

    await FirebaseFirestore.instance
        .collection(AppConstants.notificationsCollection)
        .add({
      'type': 'post_reactivated',
      'recipientId': order.buyerId,
      'vendorId': order.vendorId,
      'orderId': order.id,
      'buyerName': order.buyerName,
      'productTitle': order.postTitle,
      'status': 'unread',
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ── Payment lock ───────────────────────────────────────────────────────────

  /// Called when the buyer enters the payment page.
  /// Sets [paymentLockedAt] so the vendor's quantity panel is disabled.
  Future<void> lockPayment(String orderId) async {
    await FirebaseFirestore.instance
        .collection(AppConstants.ordersCollection)
        .doc(orderId)
        .update({'paymentLockedAt': FieldValue.serverTimestamp()});
  }

  /// Called when the buyer leaves the payment page (back, error, or success).
  /// On success the order moves to `confirmed` so the lock is irrelevant,
  /// but we delete it anyway to keep Firestore tidy.
  Future<void> unlockPayment(String orderId) async {
    await FirebaseFirestore.instance
        .collection(AppConstants.ordersCollection)
        .doc(orderId)
        .update({'paymentLockedAt': FieldValue.delete()});
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
