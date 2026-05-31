import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';

// ── Model ──────────────────────────────────────────────────────────────────

/// A single support ticket submitted from the help sheet or a chat report.
class SupportReport {
  final String id;
  final String userName;
  final String userEmail;
  final String topic;
  final String option;
  final String details;
  final String status; // 'open' | 'resolved'
  final DateTime? createdAt;

  /// Order context — present only when the report was opened from a chat.
  final String? orderId;
  final String? reportedUserName;

  const SupportReport({
    required this.id,
    required this.userName,
    required this.userEmail,
    required this.topic,
    required this.option,
    required this.details,
    required this.status,
    required this.createdAt,
    this.orderId,
    this.reportedUserName,
  });

  factory SupportReport.fromMap(String id, Map<String, dynamic> map) {
    return SupportReport(
      id: id,
      userName: map['userName'] as String? ?? '',
      userEmail: map['userEmail'] as String? ?? '',
      topic: map['topic'] as String? ?? '',
      option: map['option'] as String? ?? '',
      details: map['details'] as String? ?? '',
      status: map['status'] as String? ?? 'open',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      orderId: map['orderId'] as String?,
      reportedUserName: map['reportedUserName'] as String?,
    );
  }

  bool get isOpen => status == 'open';
}

// ── Provider ───────────────────────────────────────────────────────────────

/// Streams every support ticket, newest first (sorted client-side so no
/// composite index is required).
final supportReportsProvider =
    StreamProvider<List<SupportReport>>((ref) {
  return FirebaseFirestore.instance
      .collection(AppConstants.supportCollection)
      .snapshots()
      .map((snap) {
        final list = snap.docs
            .map((d) => SupportReport.fromMap(d.id, d.data()))
            .toList()
          ..sort((a, b) {
            final ad = a.createdAt ?? DateTime(0);
            final bd = b.createdAt ?? DateTime(0);
            return bd.compareTo(ad);
          });
        return list;
      });
});

// ── Helper ─────────────────────────────────────────────────────────────────

/// Toggles a ticket between `open` and `resolved`.
Future<void> setReportStatus(String reportId, String status) async {
  await FirebaseFirestore.instance
      .collection(AppConstants.supportCollection)
      .doc(reportId)
      .update({'status': status});
}
