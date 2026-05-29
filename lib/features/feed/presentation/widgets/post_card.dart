import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/post_model.dart';
import '../../data/following_provider.dart';

// ── Status dot color ───────────────────────────────────────────────────────

Color _statusColor(VendorAvailability status) {
  switch (status) {
    case VendorAvailability.active:
      return AppColors.success;
    case VendorAvailability.busy:
      return AppColors.accentGold;
    case VendorAvailability.offline:
      return AppColors.textSecondary;
  }
}

// ── PostCard ───────────────────────────────────────────────────────────────

class PostCard extends ConsumerWidget {
  final PostModel post;
  final VoidCallback onTap;

  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingAsync = ref.watch(followingProvider);
    final followedSet =
        (followingAsync.asData?.value ?? []).toSet();
    final isFollowing = followedSet.contains(post.vendorId);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderOverlay),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Vendor header ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  // Avatar
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.bgSurface,
                        backgroundImage: post.vendorPhotoUrl != null
                            ? CachedNetworkImageProvider(
                                post.vendorPhotoUrl!)
                            : null,
                        child: post.vendorPhotoUrl == null
                            ? Text(
                                post.vendorName.isNotEmpty
                                    ? post.vendorName[0].toUpperCase()
                                    : '?',
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textPrimary),
                              )
                            : null,
                      ),
                      // Status dot
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _statusColor(post.vendorStatus),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.bgCard,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.push('/vendor/${post.vendorId}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.vendorName,
                            style: AppTextStyles.body.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            post.vendorCareer,
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isFollowing)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accentGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.accentGold.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'Siguiendo',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.accentGold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Image with offer badge ──────────────────────────────────
            if (post.mediaUrls.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 180,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: post.mediaUrls.first,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        color: AppColors.bgSurface,
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      errorWidget: (_, _, _) => Container(
                        color: AppColors.bgSurface,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    // Offer badge overlay
                    if (post.hasOffer && post.offerBadgeText.isNotEmpty)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentGold,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            post.offerBadgeText,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.bgPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // ── Title & price footer ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      post.title,
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${post.price.toStringAsFixed(post.price % 1 == 0 ? 0 : 2)}',
                        style: AppTextStyles.h3
                            .copyWith(color: AppColors.accentGold),
                      ),
                      if (post.originalPrice != null &&
                          post.originalPrice! > post.price)
                        Text(
                          '\$${post.originalPrice!.toStringAsFixed(post.originalPrice! % 1 == 0 ? 0 : 2)}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
          ),
          // ── Inactive overlay ──────────────────────────────────────
          if (!post.isActive)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderOverlay),
                    ),
                    child: Text(
                      'No disponible',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
