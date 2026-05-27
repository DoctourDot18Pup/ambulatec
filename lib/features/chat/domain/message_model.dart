import 'package:cloud_firestore/cloud_firestore.dart';

/// A single chat message stored under
/// `chats/{orderId}/messages/{messageId}`.
class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String text;
  final String? imageUrl;
  final DateTime createdAt;

  /// `true` for auto-generated system events such as
  /// "Pedido confirmado" or "Pedido entregado".
  final bool isSystem;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.text,
    this.imageUrl,
    required this.createdAt,
    this.isSystem = false,
  });

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'senderName': senderName,
        if (senderPhotoUrl != null) 'senderPhotoUrl': senderPhotoUrl,
        'text': text,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'createdAt': Timestamp.fromDate(createdAt),
        'isSystem': isSystem,
      };

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id: id,
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? '',
      senderPhotoUrl: map['senderPhotoUrl'] as String?,
      text: map['text'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isSystem: map['isSystem'] as bool? ?? false,
    );
  }
}
