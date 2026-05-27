import 'package:cloud_firestore/cloud_firestore.dart';
import '../../feed/domain/post_model.dart';
import '../../../core/constants/app_constants.dart';

// ── Enums ──────────────────────────────────────────────────────────────────

enum OrderStatus { pending, confirmed, delivered, cancelled, rejected }

// ── Model ──────────────────────────────────────────────────────────────────

class OrderModel {
  final String id;
  final String buyerId;
  final String buyerName;
  final String buyerPhotoUrl;
  final String vendorId;
  final String postId;
  final String postTitle;
  final List<String> postMediaUrls;
  final double originalPrice;
  final double finalPrice;
  final int quantity;
  final bool offerApplied;
  final OfferType? offerType;
  final String deliveryNote;
  final String? deliveryImageUrl;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final DateTime? deliveredAt;
  final DateTime chatExpiresAt;

  const OrderModel({
    required this.id,
    required this.buyerId,
    required this.buyerName,
    required this.buyerPhotoUrl,
    required this.vendorId,
    required this.postId,
    required this.postTitle,
    required this.postMediaUrls,
    required this.originalPrice,
    required this.finalPrice,
    required this.quantity,
    required this.offerApplied,
    this.offerType,
    required this.deliveryNote,
    this.deliveryImageUrl,
    required this.status,
    required this.createdAt,
    this.confirmedAt,
    this.deliveredAt,
    required this.chatExpiresAt,
  });

  // ── Factory ────────────────────────────────────────────────────────────────

  factory OrderModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.parse(v);
      return DateTime.now();
    }

    DateTime? parseDateOptional(dynamic v) {
      if (v == null) return null;
      return parseDate(v);
    }

    OfferType? parseOfferType(String? s) {
      switch (s) {
        case 'twoForOne':
          return OfferType.twoForOne;
        case 'percent':
          return OfferType.percent;
        case 'special':
          return OfferType.special;
        default:
          return null;
      }
    }

    final createdAt = parseDate(map['createdAt']);

    return OrderModel(
      id: id,
      buyerId: map['buyerId'] as String? ?? '',
      buyerName: map['buyerName'] as String? ?? '',
      buyerPhotoUrl: map['buyerPhotoUrl'] as String? ?? '',
      vendorId: map['vendorId'] as String? ?? '',
      postId: map['postId'] as String? ?? '',
      postTitle: map['postTitle'] as String? ?? '',
      postMediaUrls: List<String>.from(map['postMediaUrls'] as List? ?? []),
      originalPrice: (map['originalPrice'] as num?)?.toDouble() ?? 0,
      finalPrice: (map['finalPrice'] as num?)?.toDouble() ?? 0,
      quantity: map['quantity'] as int? ?? 1,
      offerApplied: map['offerApplied'] as bool? ?? false,
      offerType: parseOfferType(map['offerType'] as String?),
      deliveryNote: map['deliveryNote'] as String? ?? '',
      deliveryImageUrl: map['deliveryImageUrl'] as String?,
      status: OrderStatus.values.firstWhere(
        (e) => e.name == (map['status'] as String? ?? 'pending'),
        orElse: () => OrderStatus.pending,
      ),
      createdAt: createdAt,
      confirmedAt: parseDateOptional(map['confirmedAt']),
      deliveredAt: parseDateOptional(map['deliveredAt']),
      chatExpiresAt: parseDateOptional(map['chatExpiresAt']) ??
          createdAt.add(Duration(hours: AppConstants.chatExpirationHours)),
    );
  }

  // ── toMap ──────────────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'buyerId': buyerId,
        'buyerName': buyerName,
        'buyerPhotoUrl': buyerPhotoUrl,
        'vendorId': vendorId,
        'postId': postId,
        'postTitle': postTitle,
        'postMediaUrls': postMediaUrls,
        'originalPrice': originalPrice,
        'finalPrice': finalPrice,
        'quantity': quantity,
        'offerApplied': offerApplied,
        'offerType': offerType?.name,
        'deliveryNote': deliveryNote,
        'deliveryImageUrl': deliveryImageUrl,
        'status': status.name,
        'createdAt': Timestamp.fromDate(createdAt),
        if (confirmedAt != null)
          'confirmedAt': Timestamp.fromDate(confirmedAt!),
        if (deliveredAt != null)
          'deliveredAt': Timestamp.fromDate(deliveredAt!),
        'chatExpiresAt': Timestamp.fromDate(chatExpiresAt),
      };

  // ── copyWith ───────────────────────────────────────────────────────────────

  OrderModel copyWith({
    String? id,
    String? buyerId,
    String? buyerName,
    String? buyerPhotoUrl,
    String? vendorId,
    String? postId,
    String? postTitle,
    List<String>? postMediaUrls,
    double? originalPrice,
    double? finalPrice,
    int? quantity,
    bool? offerApplied,
    OfferType? offerType,
    String? deliveryNote,
    String? deliveryImageUrl,
    OrderStatus? status,
    DateTime? createdAt,
    DateTime? confirmedAt,
    DateTime? deliveredAt,
    DateTime? chatExpiresAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      buyerId: buyerId ?? this.buyerId,
      buyerName: buyerName ?? this.buyerName,
      buyerPhotoUrl: buyerPhotoUrl ?? this.buyerPhotoUrl,
      vendorId: vendorId ?? this.vendorId,
      postId: postId ?? this.postId,
      postTitle: postTitle ?? this.postTitle,
      postMediaUrls: postMediaUrls ?? this.postMediaUrls,
      originalPrice: originalPrice ?? this.originalPrice,
      finalPrice: finalPrice ?? this.finalPrice,
      quantity: quantity ?? this.quantity,
      offerApplied: offerApplied ?? this.offerApplied,
      offerType: offerType ?? this.offerType,
      deliveryNote: deliveryNote ?? this.deliveryNote,
      deliveryImageUrl: deliveryImageUrl ?? this.deliveryImageUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      chatExpiresAt: chatExpiresAt ?? this.chatExpiresAt,
    );
  }
}
