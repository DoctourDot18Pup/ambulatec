import 'package:cloud_firestore/cloud_firestore.dart';

class FollowModel {
  final String vendorId;
  final DateTime followedAt;

  const FollowModel({
    required this.vendorId,
    required this.followedAt,
  });

  factory FollowModel.fromMap(String vendorId, Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.parse(v);
      return DateTime.now();
    }

    return FollowModel(
      vendorId: vendorId,
      followedAt: parseDate(map['followedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'followedAt': Timestamp.fromDate(followedAt),
      };
}
