import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/adaptive_scaffold.dart';
import '../../../shared/widgets/rating_stars_widget.dart';
import '../../auth/data/auth_controller.dart';
import '../../auth/domain/user_model.dart';
import '../../orders/domain/order_model.dart';
import '../../orders/providers/orders_provider.dart';
import '../../vendor/providers/vendor_posts_provider.dart';
import '../domain/review_model.dart';
import '../providers/profile_controller.dart';
import '../providers/profile_provider.dart';
import '../providers/vendor_reviews_provider.dart';

// ── Page ───────────────────────────────────────────────────────────────────

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AdaptiveScaffold(
      currentIndex: 4,
      body: _ProfileBody(),
    );
  }
}

// ── Body ───────────────────────────────────────────────────────────────────

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);

    return userAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accentGold)),
      error: (e, _) => Center(
          child: Text('Error: $e',
              style: AppTextStyles.body.copyWith(color: AppColors.error))),
      data: (user) {
        if (user == null) {
          return Center(
            child: Text('Sin sesión activa',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary)),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth:
                        constraints.maxWidth >= 1024 ? 560 : double.infinity),
                child: _ProfileContent(user: user),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Content ────────────────────────────────────────────────────────────────

class _ProfileContent extends ConsumerWidget {
  final UserModel user;
  const _ProfileContent({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isApprovedVendor = user.roles.contains('vendor') &&
        user.vendorStatus == VendorStatus.approved;

    final ordersAsync = ref.watch(ordersProvider);
    final totalDelivered = ordersAsync.asData?.value
            .where((o) => o.status == OrderStatus.delivered)
            .length ??
        0;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          // ── Header ──────────────────────────────────────────────
          _Header(user: user),
          const SizedBox(height: 24),

          // ── Vendor section ───────────────────────────────────────
          if (isApprovedVendor) ...[
            _VendorSection(user: user, totalDelivered: totalDelivered),
            const SizedBox(height: 24),
          ],

          // ── Vendor reviews ───────────────────────────────────────
          if (isApprovedVendor) ...[
            _VendorReviewsList(vendorId: user.uid),
            const SizedBox(height: 24),
          ],

          // ── Options list ─────────────────────────────────────────
          _OptionsList(user: user),
        ],
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final UserModel user;
  const _Header({required this.user});

  @override
  Widget build(BuildContext context) {
    final initials = user.displayName.isNotEmpty
        ? user.displayName
            .split(' ')
            .where((s) => s.isNotEmpty)
            .take(2)
            .map((s) => s[0].toUpperCase())
            .join()
        : '?';

    return Column(
      children: [
        // Avatar
        CircleAvatar(
          radius: 40,
          backgroundColor: AppColors.accentGreen,
          backgroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty
              ? CachedNetworkImageProvider(user.photoUrl!)
              : null,
          child:
              (user.photoUrl == null || user.photoUrl!.isEmpty)
                  ? Text(initials,
                      style:
                          AppTextStyles.h2.copyWith(color: Colors.white))
                  : null,
        ),
        const SizedBox(height: 14),

        // Name
        Text(
          user.displayName,
          style: AppTextStyles.h2.copyWith(color: AppColors.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),

        // Email
        Text(
          user.email,
          style: AppTextStyles.body
              .copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),

        // Role badges
        Wrap(
          spacing: 8,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            if (user.roles.contains('buyer'))
              _RoleBadge(
                label: 'Comprador',
                color: AppColors.accentGreen,
              ),
            if (user.roles.contains('vendor'))
              _RoleBadge(
                label: 'Vendedor',
                color: AppColors.accentGold,
              ),
            if (user.isAdmin)
              _RoleBadge(
                label: 'Admin',
                color: AppColors.error,
              ),
          ],
        ),
      ],
    );
  }
}

// ── Role badge ─────────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _RoleBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(label,
          style: AppTextStyles.caption
              .copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Vendor section ─────────────────────────────────────────────────────────

class _VendorSection extends ConsumerWidget {
  final UserModel user;
  final int totalDelivered;
  const _VendorSection(
      {required this.user, required this.totalDelivered});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(vendorPostsProvider);
    final posts = postsAsync.asData?.value ?? [];

    final joinMonth = _monthName(user.createdAt.month);
    final joinYear = user.createdAt.year;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOverlay),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stats row ──────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.star_rounded,
                  color: AppColors.accentGold, size: 16),
              const SizedBox(width: 4),
              Text(
                user.vendorRating > 0
                    ? user.vendorRating.toStringAsFixed(1)
                    : 'Sin reseñas',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textPrimary),
              ),
              if (user.totalReviews > 0) ...[
                Text('  ·  ',
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textSecondary)),
                Text('${user.totalReviews} reseñas',
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textSecondary)),
              ],
              Text('  ·  ',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary)),
              Text('$totalDelivered ventas',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary)),
              Text('  ·  ',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary)),
              Flexible(
                child: Text(
                  'desde $joinMonth $joinYear',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Menu permanente ────────────────────────────────────────
          Row(
            children: [
              Text('Menú permanente',
                  style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              GestureDetector(
                onTap: () => context.go('/create-post'),
                child: Text('Agregar',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.accentGold)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (posts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Aún no tienes publicaciones activas.',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary),
              ),
            )
          else
            ...posts.map((post) => _PostRow(
                  title: post.title,
                  price: post.price,
                )),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      '',
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];
    return months[month];
  }
}

class _PostRow extends StatelessWidget {
  final String title;
  final double price;
  const _PostRow({required this.title, required this.price});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis),
          ),
          Text(
            '\$${price.toStringAsFixed(price % 1 == 0 ? 0 : 2)}',
            style: AppTextStyles.body
                .copyWith(color: AppColors.accentGold),
          ),
        ],
      ),
    );
  }
}

// ── Options list ───────────────────────────────────────────────────────────

class _OptionsList extends ConsumerWidget {
  final UserModel user;
  const _OptionsList({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void soon() => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Próximamente'),
            behavior: SnackBarBehavior.floating,
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOverlay),
      ),
      child: Column(
        children: [
          if (user.roles.contains('vendor')) ...[
            _OptionTile(
              icon: Icons.star_outline_rounded,
              label: 'Mis reseñas',
              onTap: () => context.push('/my-reviews'),
            ),
            _divider(),
          ],
          _OptionTile(
            icon: Icons.edit_outlined,
            label: 'Editar perfil',
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: AppColors.bgCard,
              shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => _EditProfileSheet(user: user),
            ),
          ),
          _divider(),
          _OptionTile(
            icon: Icons.credit_card_outlined,
            label: 'Métodos de pago',
            onTap: soon,
          ),
          _divider(),
          _OptionTile(
            icon: Icons.notifications_outlined,
            label: 'Notificaciones',
            onTap: () => context.push('/notifications'),
          ),
          _divider(),
          _OptionTile(
            icon: Icons.help_outline,
            label: 'Ayuda y soporte',
            onTap: soon,
          ),
          if (user.isAdmin) ...[
            _divider(),
            _OptionTile(
              icon: Icons.admin_panel_settings_outlined,
              label: 'Panel de administrador',
              onTap: () => context.go('/admin'),
            ),
          ],
          _divider(),
          _OptionTile(
            icon: Icons.logout,
            label: 'Cerrar sesión',
            textColor: AppColors.error,
            onTap: () => _confirmSignOut(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(
      height: 1, thickness: 1, color: AppColors.borderOverlay);

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text('¿Cerrar sesión?',
            style: AppTextStyles.h3
                .copyWith(color: AppColors.textPrimary)),
        content: Text(
          'Tendrás que volver a iniciar sesión con tu cuenta de Google.',
          style: AppTextStyles.body
              .copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? textColor;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: AppTextStyles.body.copyWith(color: color)),
            ),
            Icon(Icons.chevron_right, size: 18,
                color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Vendor reviews list ────────────────────────────────────────────────────

class _VendorReviewsList extends ConsumerWidget {
  final String vendorId;
  const _VendorReviewsList({required this.vendorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(vendorReviewsProvider(vendorId));
    return reviewsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accentGold)),
      error: (e, _) => Text('Error al cargar reseñas: $e',
          style: AppTextStyles.caption.copyWith(color: AppColors.error)),
      data: (reviews) {
        if (reviews.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MIS RESEÑAS',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            ...reviews.map((r) => _ReviewDetailTile(review: r)),
          ],
        );
      },
    );
  }
}

// ── Edit profile sheet ─────────────────────────────────────────────────────

class _EditProfileSheet extends ConsumerStatefulWidget {
  final UserModel user;
  const _EditProfileSheet({required this.user});

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  Uint8List? _pickedBytes;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.displayName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _pickedBytes = bytes);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    await ref.read(profileControllerProvider.notifier).updateProfile(
          uid: widget.user.uid,
          displayName: name,
          imageBytes: _pickedBytes,
        );

    if (!mounted) return;
    if (ref.read(profileControllerProvider) is AsyncData) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(profileControllerProvider, (_, state) {
      state.whenOrNull(
        error: (e, _) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        ),
      );
    });

    final isLoading = ref.watch(profileControllerProvider).isLoading;

    final initials = widget.user.displayName.isNotEmpty
        ? widget.user.displayName
            .split(' ')
            .where((s) => s.isNotEmpty)
            .take(2)
            .map((s) => s[0].toUpperCase())
            .join()
        : '?';

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.borderOverlay,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Text('Editar perfil',
              style:
                  AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 28),

          // ── Avatar picker ──────────────────────────────────────────
          GestureDetector(
            onTap: isLoading ? null : _pickImage,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.accentGreen,
                  backgroundImage: _pickedBytes != null
                      ? MemoryImage(_pickedBytes!)
                      : (widget.user.photoUrl?.isNotEmpty == true
                          ? CachedNetworkImageProvider(widget.user.photoUrl!)
                          : null),
                  child: (_pickedBytes == null &&
                          (widget.user.photoUrl == null ||
                              widget.user.photoUrl!.isEmpty))
                      ? Text(initials,
                          style: AppTextStyles.h2
                              .copyWith(color: Colors.white))
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppColors.accentGold,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_outlined,
                        size: 14, color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Name field ─────────────────────────────────────────────
          TextFormField(
            controller: _nameCtrl,
            enabled: !isLoading,
            style:
                AppTextStyles.body.copyWith(color: AppColors.textPrimary),
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre completo'),
          ),
          const SizedBox(height: 32),

          // ── Actions ────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: isLoading ? null : _save,
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.bgPrimary),
                          ),
                        )
                      : const Text('Guardar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewDetailTile extends StatelessWidget {
  final ReviewModel review;
  const _ReviewDetailTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOverlay),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.postTitle.isNotEmpty ? review.postTitle : 'Pedido',
                  style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              RatingStarsWidget(rating: review.rating.toDouble(), size: 13),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.accentGreen,
                backgroundImage: review.buyerPhotoUrl.isNotEmpty
                    ? NetworkImage(review.buyerPhotoUrl)
                    : null,
                child: review.buyerPhotoUrl.isEmpty
                    ? Text(
                        review.buyerName.isNotEmpty
                            ? review.buyerName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10),
                      )
                    : null,
              ),
              const SizedBox(width: 6),
              Text(
                review.buyerName.isNotEmpty ? review.buyerName : 'Comprador',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
              const Spacer(),
              Text(
                '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: review.tags
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentGold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(t,
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.accentGold, fontSize: 10)),
                      ))
                  .toList(),
            ),
          ],
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.comment!,
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}
