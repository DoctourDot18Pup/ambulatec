/// Application-wide constants for AmbulaTec.
class AppConstants {
  AppConstants._();

  // ── Timeouts & durations ──────────────────────────────────────────────────
  static const int orderConfirmationTimeoutMinutes = 10;
  static const int chatExpirationHours = 24;

  // ── Firestore collections ─────────────────────────────────────────────────
  static const String usersCollection = 'users';
  static const String postsCollection = 'posts';
  static const String ordersCollection = 'orders';
  static const String chatsCollection = 'chats';
  static const String reviewsCollection = 'reviews';

  // ── Storage paths ─────────────────────────────────────────────────────────
  static const String vendorIdStoragePath = 'vendor_ids';
  static const String postImagesStoragePath = 'post_images';
  static const String userAvatarsStoragePath = 'user_avatars';

  // ── Offer durations (minutes) ─────────────────────────────────────────────
  static const List<int> offerDurations = [15, 30, 60];

  // ── Cloudinary ────────────────────────────────────────────────────────────
  static const String cloudinaryCloudName = 'dpjozkpnr';
  static const String cloudinaryUploadPreset = 'ambulatec_uploads';
  static const String cloudinaryUploadUrl =
      'https://api.cloudinary.com/v1_1/dpjozkpnr/image/upload';

  // ── Notifications (Firestore-based in-app) ────────────────────────────────
  static const String notificationsCollection = 'notifications';

  // ── FCM Web Push (replace with real VAPID key from Firebase Console →
  //    Project Settings → Cloud Messaging → Web Push certificates) ──────────
  static const String fcmVapidKey = 'BIJNDzStcZT9X54n8TUPKYlikLYOZVk-O5pVTnj9gGN_WGmDcvXMVmTR3PRzzr7X7XgNWfcet8SvoHUJVlQ_CbI';
}
