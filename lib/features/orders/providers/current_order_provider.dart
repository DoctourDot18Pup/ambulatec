import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../feed/domain/post_model.dart';
import '../domain/order_model.dart';

// ── OrderDraft ─────────────────────────────────────────────────────────────

/// Transient draft that carries order data from PostDetailPage to
/// OrderSummaryPage. Cleared after confirmation or cancellation.
class OrderDraft {
  final PostModel post;
  final String deliveryNote;
  final Uint8List? deliveryImageBytes;
  final String? deliveryImageUrl;
  final Map<String, List<String>> selectedExtras;

  /// Priced breakdown of [selectedExtras] (group, option, per-unit price).
  final List<OrderExtra> extrasDetail;
  final int quantity;

  const OrderDraft({
    required this.post,
    required this.deliveryNote,
    this.deliveryImageBytes,
    this.deliveryImageUrl,
    this.selectedExtras = const {},
    this.extrasDetail = const [],
    this.quantity = 1,
  });

  /// Sum of per-unit extra surcharges.
  double get extrasPerUnit =>
      extrasDetail.fold(0.0, (sum, e) => sum + e.price);

  OrderDraft copyWith({
    PostModel? post,
    String? deliveryNote,
    Uint8List? deliveryImageBytes,
    String? deliveryImageUrl,
    Map<String, List<String>>? selectedExtras,
    List<OrderExtra>? extrasDetail,
    int? quantity,
  }) {
    return OrderDraft(
      post: post ?? this.post,
      deliveryNote: deliveryNote ?? this.deliveryNote,
      deliveryImageBytes: deliveryImageBytes ?? this.deliveryImageBytes,
      deliveryImageUrl: deliveryImageUrl ?? this.deliveryImageUrl,
      selectedExtras: selectedExtras ?? this.selectedExtras,
      extrasDetail: extrasDetail ?? this.extrasDetail,
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
