import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../feed/domain/post_model.dart';

// ── OrderDraft ─────────────────────────────────────────────────────────────

/// Transient draft that carries order data from PostDetailPage to
/// OrderSummaryPage. Cleared after confirmation or cancellation.
class OrderDraft {
  final PostModel post;
  final int quantity;
  final String deliveryNote;
  final Uint8List? deliveryImageBytes;
  final String? deliveryImageUrl;

  const OrderDraft({
    required this.post,
    this.quantity = 1,
    required this.deliveryNote,
    this.deliveryImageBytes,
    this.deliveryImageUrl,
  });

  OrderDraft copyWith({
    PostModel? post,
    int? quantity,
    String? deliveryNote,
    Uint8List? deliveryImageBytes,
    String? deliveryImageUrl,
  }) {
    return OrderDraft(
      post: post ?? this.post,
      quantity: quantity ?? this.quantity,
      deliveryNote: deliveryNote ?? this.deliveryNote,
      deliveryImageBytes: deliveryImageBytes ?? this.deliveryImageBytes,
      deliveryImageUrl: deliveryImageUrl ?? this.deliveryImageUrl,
    );
  }
}

// ── Provider ───────────────────────────────────────────────────────────────

/// Global (non-autoDispose) so the draft survives navigation between
/// PostDetailPage and OrderSummaryPage.
final currentOrderProvider = StateProvider<OrderDraft?>((ref) => null);
