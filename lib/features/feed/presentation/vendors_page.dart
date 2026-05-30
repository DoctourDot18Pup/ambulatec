import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/adaptive_scaffold.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/rating_stars_widget.dart';
import '../../auth/domain/user_model.dart';

// ── Provider ───────────────────────────────────────────────────────────────

final _allVendorsProvider =
    StreamProvider.autoDispose<List<UserModel>>((ref) {
  return FirebaseFirestore.instance
      .collection(AppConstants.usersCollection)
      .where('roles', arrayContains: 'vendor')
      .where('vendorStatus', isEqualTo: 'approved')
      .snapshots()
      .map((snap) {
        final list = snap.docs
            .map((d) => UserModel.fromMap({'uid': d.id, ...d.data()}))
            .toList();
        list.sort((a, b) => b.vendorRating.compareTo(a.vendorRating));
        return list;
      });
});

// ── Page ───────────────────────────────────────────────────────────────────

class VendorsPage extends ConsumerWidget {
  const VendorsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AdaptiveScaffold(
      currentIndex: 1,
      body: _VendorsBody(),
    );
  }
}

class _VendorsBody extends ConsumerWidget {
  const _VendorsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorsAsync = ref.watch(_allVendorsProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Vendedores',
            style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
      ),
      body: vendorsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accentGold)),
        error: (e, _) => Center(
            child: Text('$e',
                style:
                    AppTextStyles.body.copyWith(color: AppColors.error))),
        data: (vendors) {
          if (vendors.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.storefront_outlined,
              title: 'Sin vendedores activos',
              subtitle:
                  'Los vendedores aparecerán aquí una vez que sean aprobados.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: vendors.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _VendorCard(vendor: vendors[i]),
          );
        },
      ),
    );
  }
}

class _VendorCard extends StatelessWidget {
  final UserModel vendor;
  const _VendorCard({required this.vendor});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push('/vendor/${vendor.uid}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderOverlay),
        ),
        child: Row(
          children: [
            // ── Avatar ──────────────────────────────────────────────
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.accentGreen,
              backgroundImage: vendor.photoUrl != null &&
                      vendor.photoUrl!.isNotEmpty
                  ? NetworkImage(vendor.photoUrl!)
                  : null,
              child:
                  (vendor.photoUrl == null || vendor.photoUrl!.isEmpty)
                      ? Text(
                          vendor.displayName.isNotEmpty
                              ? vendor.displayName[0].toUpperCase()
                              : '?',
                          style: AppTextStyles.h3
                              .copyWith(color: Colors.white),
                        )
                      : null,
            ),
            const SizedBox(width: 14),

            // ── Info ─────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vendor.displayName,
                    style: AppTextStyles.body.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (vendor.vendorRating > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        RatingStarsWidget(
                            rating: vendor.vendorRating, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          vendor.vendorRating.toStringAsFixed(1),
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary),
                        ),
                        if (vendor.totalReviews > 0) ...[
                          Text('  ·  ',
                              style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary)),
                          Text('${vendor.totalReviews} reseñas',
                              style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary)),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}
