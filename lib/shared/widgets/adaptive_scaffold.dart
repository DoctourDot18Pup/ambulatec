import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/auth/data/user_provider.dart';
import '../../features/feed/data/category_filter_provider.dart';

// ── Nav item model ─────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}

const _vendorNavItems = [
  _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Inicio', route: '/home'),
  _NavItem(icon: Icons.storefront_outlined, activeIcon: Icons.storefront, label: 'Dashboard', route: '/dashboard'),
  _NavItem(icon: Icons.search_outlined, activeIcon: Icons.search, label: 'Buscar', route: '/search'),
  _NavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'Pedidos', route: '/orders'),
  _NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Perfil', route: '/profile'),
];

const _buyerNavItems = [
  _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Inicio', route: '/home'),
  _NavItem(icon: Icons.people_outline, activeIcon: Icons.people, label: 'Vendedores', route: '/vendors'),
  _NavItem(icon: Icons.search_outlined, activeIcon: Icons.search, label: 'Buscar', route: '/search'),
  _NavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'Pedidos', route: '/orders'),
  _NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Perfil', route: '/profile'),
];

// ── AdaptiveScaffold ───────────────────────────────────────────────────────

/// Wraps [body] with either a mobile BottomNavigationBar (< 1024 px)
/// or a desktop sidebar (≥ 1024 px).
///
/// [currentIndex] maps to [_navItems]:
///   0 = home, 1 = dashboard, 2 = search, 3 = orders, 4 = profile
///
/// [showCategoryFilter] enables the category chips section in the sidebar.
/// [showVendorFab] adds a "+" FAB for vendors on mobile.
class AdaptiveScaffold extends ConsumerWidget {
  final Widget body;
  final int currentIndex;
  final bool showCategoryFilter;
  final bool showVendorFab;

  const AdaptiveScaffold({
    super.key,
    required this.body,
    this.currentIndex = 0,
    this.showCategoryFilter = false,
    this.showVendorFab = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userModel = ref.watch(userProvider).asData?.value;
    final navItems = (userModel?.roles.contains('vendor') ?? false)
        ? _vendorNavItems
        : _buyerNavItems;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;
        return isDesktop
            ? _DesktopLayout(
                body: body,
                currentIndex: currentIndex,
                showCategoryFilter: showCategoryFilter,
                navItems: navItems,
              )
            : _MobileLayout(
                body: body,
                currentIndex: currentIndex,
                showVendorFab: showVendorFab,
                navItems: navItems,
              );
      },
    );
  }
}

// ── Mobile layout ──────────────────────────────────────────────────────────

class _MobileLayout extends ConsumerWidget {
  final Widget body;
  final int currentIndex;
  final bool showVendorFab;
  final List<_NavItem> navItems;

  const _MobileLayout({
    required this.body,
    required this.currentIndex,
    required this.showVendorFab,
    required this.navItems,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userModel = ref.watch(userProvider).asData?.value;
    final isVendor = userModel?.roles.contains('vendor') ?? false;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: body,
      floatingActionButton: (showVendorFab && isVendor)
          ? FloatingActionButton(
              backgroundColor: AppColors.accentGold,
              foregroundColor: AppColors.bgPrimary,
              onPressed: () => context.go('/create-post'),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => context.go(navItems[index].route),
        backgroundColor: AppColors.bgSurface,
        selectedItemColor: AppColors.accentGold,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle:
            AppTextStyles.caption.copyWith(fontSize: 10),
        unselectedLabelStyle:
            AppTextStyles.caption.copyWith(fontSize: 10),
        items: navItems
            .map(
              (item) => BottomNavigationBarItem(
                icon: Icon(item.icon),
                activeIcon: Icon(item.activeIcon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

// ── Desktop layout ─────────────────────────────────────────────────────────

class _DesktopLayout extends ConsumerWidget {
  final Widget body;
  final int currentIndex;
  final bool showCategoryFilter;
  final List<_NavItem> navItems;

  const _DesktopLayout({
    required this.body,
    required this.currentIndex,
    required this.showCategoryFilter,
    required this.navItems,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userModel = ref.watch(userProvider).asData?.value;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Row(
        children: [
          // ── Sidebar ──────────────────────────────────────────────────────
          SizedBox(
            width: 240,
            child: _Sidebar(
              currentIndex: currentIndex,
              showCategoryFilter: showCategoryFilter,
              navItems: navItems,
              userModel: userModel,
            ),
          ),
          // ── Divider ───────────────────────────────────────────────────────
          Container(
            width: 1,
            color: AppColors.borderOverlay,
          ),
          // ── Main content ──────────────────────────────────────────────────
          Expanded(child: body),
        ],
      ),
    );
  }
}

// ── Sidebar ────────────────────────────────────────────────────────────────

class _Sidebar extends ConsumerWidget {
  final int currentIndex;
  final bool showCategoryFilter;
  final List<_NavItem> navItems;
  final dynamic userModel;

  const _Sidebar({
    required this.currentIndex,
    required this.showCategoryFilter,
    required this.navItems,
    required this.userModel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(categoryFilterProvider);

    return Container(
      color: AppColors.bgSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Logo ─────────────────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Ambula',
                    style: AppTextStyles.h3
                        .copyWith(color: AppColors.textPrimary),
                  ),
                  TextSpan(
                    text: 'Tec',
                    style: AppTextStyles.h3
                        .copyWith(color: AppColors.accentGold),
                  ),
                ],
              ),
            ),
          ),

          // ── Nav items ─────────────────────────────────────────────────────
          ...List.generate(navItems.length, (i) {
            final item = navItems[i];
            final selected = i == currentIndex;
            return _SidebarNavItem(
              icon: selected ? item.activeIcon : item.icon,
              label: item.label,
              selected: selected,
              onTap: () => context.go(item.route),
            );
          }),

          // ── Categories section ────────────────────────────────────────────
          if (showCategoryFilter) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'CATEGORÍAS',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 8),
            ...kCategories.map((cat) {
              final isSelected = cat == selectedCategory;
              return _SidebarCategoryItem(
                label: _categoryLabel(cat),
                selected: isSelected,
                onTap: () =>
                    ref.read(categoryFilterProvider.notifier).state = cat,
              );
            }),
          ],

          const Spacer(),

          // ── User info at bottom ───────────────────────────────────────────
          if (userModel != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.bgCard,
                    backgroundImage: userModel.photoUrl != null
                        ? NetworkImage(userModel.photoUrl as String)
                        : null,
                    child: userModel.photoUrl == null
                        ? const Icon(Icons.person,
                            color: AppColors.textSecondary, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (userModel.displayName as String)
                              .split(' ')
                              .first,
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          (userModel.roles as List).contains('vendor')
                              ? 'Vendedor'
                              : 'Comprador',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'todos':
        return 'Todos';
      case 'comida':
        return 'Comida';
      case 'bebidas':
        return 'Bebidas';
      case 'postres':
        return 'Postres';
      case 'snacks':
        return 'Snacks';
      case 'otros':
        return 'Otros';
      default:
        return cat;
    }
  }
}

// ── Sidebar nav item ───────────────────────────────────────────────────────

class _SidebarNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accentGold.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected
                  ? AppColors.accentGold
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppTextStyles.body.copyWith(
                color: selected
                    ? AppColors.accentGold
                    : AppColors.textSecondary,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sidebar category item ──────────────────────────────────────────────────

class _SidebarCategoryItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarCategoryItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accentGold.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(
            color:
                selected ? AppColors.accentGold : AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
