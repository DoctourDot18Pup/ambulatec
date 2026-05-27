import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/adaptive_scaffold.dart';
import '../../auth/data/auth_controller.dart';
import '../../auth/domain/user_model.dart';
import '../../orders/domain/order_model.dart';
import '../../orders/providers/orders_provider.dart';
import '../../vendor/providers/vendor_posts_provider.dart';
import '../providers/profile_provider.dart';

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
          _OptionTile(
            icon: Icons.edit_outlined,
            label: 'Editar perfil',
            onTap: soon,
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
            onTap: soon,
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
