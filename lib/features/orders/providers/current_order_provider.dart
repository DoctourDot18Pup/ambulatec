import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../feed/domain/post_model.dart';

// ── OrderDraft ─────────────────────────────────────────────────────────────

/// Transient draft that carries order data from PostDetailPage to
/// OrderSummaryPage. Cleared after confirmation or cancellation.
class OrderDraft {
  final PostModel post;
  final String deliveryNote;
  final Uint8List? deliveryImageBytes;
  final String? deliveryImageUrl;
  final Map<String, List<String>> selectedExtras;
  final int quantity;

  const OrderDraft({
    required this.post,
    required this.deliveryNote,
    this.deliveryImageBytes,
    this.deliveryImageUrl,
    this.selectedExtras = const {},
    this.quantity = 1,
  });

  OrderDraft copyWith({
    PostModel? post,
    String? deliveryNote,
    Uint8List? deliveryImageBytes,
    String? deliveryImageUrl,
    Map<String, List<String>>? selectedExtras,
    int? quantity,
  }) {
    return OrderDraft(
      post: post ?? this.post,
      deliveryNote: deliveryNote ?? this.deliveryNote,
      deliveryImageBytes: deliveryImageBytes ?? this.deliveryImageBytes,
      deliveryImageUrl: deliveryImageUrl ?? this.deliveryImageUrl,
      selectedExtras: selectedExtras ?? this.selectedExtras,
      quantity: quantity ?? this.quantity,
    );
  }
}

// ── Provider ───────────────────────────────────────────────────────────────

class _CurrentOrderNotifier extends Notifier<OrderDraft?> {
  @override
  OrderDraft? build() => null;
  void update(OrderDraft? value) => state = value;
}

/// Global (non-autoDispose) so the draft survives navigation between
/// PostDetailPage and OrderSummaryPage.
final currentOrderProvider =
    NotifierProvider<_CurrentOrderNotifier, OrderDraft?>(_CurrentOrderNotifier.new);
