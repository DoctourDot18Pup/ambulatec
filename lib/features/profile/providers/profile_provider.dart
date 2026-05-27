// Re-export userProvider under a profile-scoped alias for clarity.
//
// ProfilePage and ReviewPage should import from here rather than directly
// from auth/data/user_provider.dart — this keeps the feature boundary clean.
export '../../../features/auth/data/user_provider.dart' show userProvider;
