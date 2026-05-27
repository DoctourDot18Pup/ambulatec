import 'package:cloud_firestore/cloud_firestore.dart';

// ── Enums ──────────────────────────────────────────────────────────────────

enum VendorAvailability { active, busy, offline }

enum OfferType { twoForOne, percent, special }

// ── Model ──────────────────────────────────────────────────────────────────

class PostModel {
  final String id;
  final String vendorId;
  final String vendorName;
  final String vendorCareer;
  final String? vendorPhotoUrl;
  final VendorAvailability vendorStatus;
  final String title;
  final String description;
  final List<String> mediaUrls;
  final String category;
  final double price;
  final double? originalPrice;
  final bool hasOffer;
  final OfferType? offerType;
  final int? discountPercent;
  final DateTime? offerExpiresAt;
  final DateTime createdAt;
  final bool isActive;

  const PostModel({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.vendorCareer,
    this.vendorPhotoUrl,
    required this.vendorStatus,
    required this.title,
    required this.description,
    required this.mediaUrls,
    required this.category,
    required this.price,
    this.originalPrice,
    required this.hasOffer,
    this.offerType,
    this.discountPercent,
    this.offerExpiresAt,
    required this.createdAt,
    required this.isActive,
  });

  // ── Factory ────────────────────────────────────────────────────────────────

  factory PostModel.fromMap(String id, Map<String, dynamic> map) {
    VendorAvailability parseStatus(String? s) {
      switch (s) {
        case 'busy':
          return VendorAvailability.busy;
        case 'offline':
          return VendorAvailability.offline;
        default:
          return VendorAvailability.active;
      }
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

    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.parse(v);
      return DateTime.now();
    }

    return PostModel(
      id: id,
      vendorId: map['vendorId'] as String? ?? '',
      vendorName: map['vendorName'] as String? ?? '',
      vendorCareer: map['vendorCareer'] as String? ?? '',
      vendorPhotoUrl: map['vendorPhotoUrl'] as String?,
      vendorStatus: parseStatus(map['vendorStatus'] as String?),
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      mediaUrls: List<String>.from(map['mediaUrls'] as List? ?? []),
      category: map['category'] as String? ?? 'otros',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      originalPrice: (map['originalPrice'] as num?)?.toDouble(),
      hasOffer: map['hasOffer'] as bool? ?? false,
      offerType: parseOfferType(map['offerType'] as String?),
      discountPercent: map['discountPercent'] as int?,
      offerExpiresAt: map['offerExpiresAt'] != null
          ? parseDate(map['offerExpiresAt'])
          : null,
      createdAt: parseDate(map['createdAt']),
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  // ── toMap ──────────────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'vendorId': vendorId,
        'vendorName': vendorName,
        'vendorCareer': vendorCareer,
        'vendorPhotoUrl': vendorPhotoUrl,
        'vendorStatus': vendorStatus.name,
        'title': title,
        'description': description,
        'mediaUrls': mediaUrls,
        'category': category,
        'price': price,
        'originalPrice': originalPrice,
        'hasOffer': hasOffer,
        'offerType': offerType?.name,
        'discountPercent': discountPercent,
        'offerExpiresAt': offerExpiresAt != null
            ? Timestamp.fromDate(offerExpiresAt!)
            : null,
        'createdAt': Timestamp.fromDate(createdAt),
        'isActive': isActive,
      };

  // ── copyWith ───────────────────────────────────────────────────────────────

  PostModel copyWith({
    String? id,
    String? vendorId,
    String? vendorName,
    String? vendorCareer,
    String? vendorPhotoUrl,
    VendorAvailability? vendorStatus,
    String? title,
    String? description,
    List<String>? mediaUrls,
    String? category,
    double? price,
    double? originalPrice,
    bool? hasOffer,
    OfferType? offerType,
    int? discountPercent,
    DateTime? offerExpiresAt,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return PostModel(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      vendorCareer: vendorCareer ?? this.vendorCareer,
      vendorPhotoUrl: vendorPhotoUrl ?? this.vendorPhotoUrl,
      vendorStatus: vendorStatus ?? this.vendorStatus,
      title: title ?? this.title,
      description: description ?? this.description,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      category: category ?? this.category,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      hasOffer: hasOffer ?? this.hasOffer,
      offerType: offerType ?? this.offerType,
      discountPercent: discountPercent ?? this.discountPercent,
      offerExpiresAt: offerExpiresAt ?? this.offerExpiresAt,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  // ── Computed ───────────────────────────────────────────────────────────────

  String get offerBadgeText {
    if (!hasOffer) return '';
    switch (offerType) {
      case OfferType.twoForOne:
        return '2×1';
      case OfferType.percent:
        return '-${discountPercent ?? 0}%';
      case OfferType.special:
        return 'Especial';
      case null:
        return '';
    }
  }
}
