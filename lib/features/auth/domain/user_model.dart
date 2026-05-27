import 'package:cloud_firestore/cloud_firestore.dart';

/// Vendor verification status values.
enum VendorStatus { pending, approved, rejected }

/// Firestore document model for the `users` collection.
class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;

  /// Possible values: 'buyer', 'vendor'. Can hold both simultaneously.
  final List<String> roles;

  /// Null when the user has not applied for a vendor account.
  final VendorStatus? vendorStatus;

  final DateTime createdAt;
  final bool onboardingCompleted;

  /// Vendor's live availability. One of: 'active', 'busy', 'offline'.
  /// Defaults to 'active'. Only relevant when the user is an approved vendor.
  final String vendorAvailability;

  /// Average rating across all [ReviewModel] documents for this vendor.
  /// Defaults to `0.0`. Updated by [ReviewNotifier.submitReview].
  final double vendorRating;

  /// Total number of reviews this vendor has received.
  final int totalReviews;

  /// `true` only when set manually in Firestore. Grants access to `/admin`.
  final bool isAdmin;

  const UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    required this.roles,
    this.vendorStatus,
    required this.createdAt,
    required this.onboardingCompleted,
    this.vendorAvailability = 'active',
    this.vendorRating = 0.0,
    this.totalReviews = 0,
    this.isAdmin = false,
  });

  // ── Serialisation ──────────────────────────────────────────────────────────

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      roles: List<String>.from(map['roles'] as List? ?? []),
      vendorStatus: map['vendorStatus'] != null
          ? VendorStatus.values.firstWhere(
              (e) => e.name == map['vendorStatus'],
              orElse: () => VendorStatus.pending,
            )
          : null,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      onboardingCompleted: map['onboardingCompleted'] as bool? ?? false,
      vendorAvailability:
          map['vendorAvailability'] as String? ?? 'active',
      vendorRating: (map['vendorRating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: map['totalReviews'] as int? ?? 0,
      isAdmin: map['isAdmin'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'roles': roles,
      'vendorStatus': vendorStatus?.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'onboardingCompleted': onboardingCompleted,
      'vendorAvailability': vendorAvailability,
      'vendorRating': vendorRating,
      'totalReviews': totalReviews,
      'isAdmin': isAdmin,
    };
  }

  // ── Immutable update ───────────────────────────────────────────────────────

  UserModel copyWith({
    String? uid,
    String? displayName,
    String? email,
    String? photoUrl,
    List<String>? roles,
    VendorStatus? vendorStatus,
    DateTime? createdAt,
    bool? onboardingCompleted,
    bool clearVendorStatus = false,
    String? vendorAvailability,
    double? vendorRating,
    int? totalReviews,
    bool? isAdmin,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      roles: roles ?? this.roles,
      vendorStatus:
          clearVendorStatus ? null : (vendorStatus ?? this.vendorStatus),
      createdAt: createdAt ?? this.createdAt,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      vendorAvailability: vendorAvailability ?? this.vendorAvailability,
      vendorRating: vendorRating ?? this.vendorRating,
      totalReviews: totalReviews ?? this.totalReviews,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}
