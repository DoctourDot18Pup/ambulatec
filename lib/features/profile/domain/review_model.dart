import 'package:cloud_firestore/cloud_firestore.dart';

/// A buyer's post-delivery review of a vendor.
///
/// Documents are stored in the top-level `reviews` collection.
/// One review per `orderId` — enforced by [ReviewNotifier.hasReviewed].
class ReviewModel {
  final String id;
  final String orderId;
  final String vendorId;
  final String buyerId;
  final String buyerName;
  final String buyerPhotoUrl;

  /// Title of the ordered post (stored for vendor detail view).
  final String postTitle;

  /// Star rating between 1 and 5.
  final int rating;

  /// Labels the buyer selected (e.g. "Puntual", "Amable").
  final List<String> tags;

  /// Free-text comment (optional, max 200 chars).
  final String? comment;

  final DateTime createdAt;

  const ReviewModel({
    required this.id,
    required this.orderId,
    required this.vendorId,
    required this.buyerId,
    required this.buyerName,
    required this.buyerPhotoUrl,
    this.postTitle = '',
    required this.rating,
    required this.tags,
    this.comment,
    required this.createdAt,
  });

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'orderId': orderId,
        'vendorId': vendorId,
        'buyerId': buyerId,
        'buyerName': buyerName,
        'buyerPhotoUrl': buyerPhotoUrl,
        if (postTitle.isNotEmpty) 'postTitle': postTitle,
        'rating': rating,
        'tags': tags,
        if (comment != null && comment!.isNotEmpty) 'comment': comment,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory ReviewModel.fromMap(Map<String, dynamic> map, String id) {
    return ReviewModel(
      id: id,
      orderId: map['orderId'] as String? ?? '',
      vendorId: map['vendorId'] as String? ?? '',
      buyerId: map['buyerId'] as String? ?? '',
      buyerName: map['buyerName'] as String? ?? '',
      buyerPhotoUrl: map['buyerPhotoUrl'] as String? ?? '',
      postTitle: map['postTitle'] as String? ?? '',
      rating: map['rating'] as int? ?? 0,
      tags: List<String>.from(map['tags'] as List? ?? []),
      comment: map['comment'] as String?,
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
