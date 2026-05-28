import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/adaptive_scaffold.dart';
import '../data/category_filter_provider.dart';
import '../data/filtered_posts_provider.dart';
import '../domain/post_model.dart';
import 'widgets/post_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AdaptiveScaffold(
      currentIndex: 0,
      showCategoryFilter: true,
      showVendorFab: true,
      body: _FeedBody(),
    );
  }
}

// ── Feed body ──────────────────────────────────────────────────────────────

class _FeedBody extends ConsumerWidget {
  const _FeedBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(filteredPostsProvider);
    final selectedCategory = ref.watch(categoryFilterProvider);

    return SafeArea(
      child: Column(
        children: [
          // ── App bar ─────────────────────────────────────────────────────
          _FeedAppBar(selectedCategory: selectedCategory),

          // ── Category chips (mobile only — hidden on desktop via sidebar) ─
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 1024;
              return isMobile
                  ? _CategoryChips(selected: selectedCategory)
                  : const SizedBox.shrink();
            },
          ),

          // ── Post list / grid ─────────────────────────────────────────────
          Expanded(
            child: postsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: AppColors.accentGold,
                ),
              ),
              error: (e, _) => _ErrorView(message: e.toString()),
              data: (posts) {
                if (posts.isEmpty) return const _EmptyView();
                return RefreshIndicator(
                  color: AppColors.accentGold,
                  backgroundColor: AppColors.bgCard,
                  onRefresh: () async {
                    ref.invalidate(filteredPostsProvider);
                  },
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 1024;
                      if (isDesktop) {
                        return _DesktopGrid(posts: posts);
                      }
                      return _MobileList(posts: posts);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Feed app bar ───────────────────────────────────────────────────────────

class _FeedAppBar extends StatelessWidget {
  final String selectedCategory;
  const _FeedAppBar({required this.selectedCategory});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgSurface,
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Row(
        children: [
          Text(
            'AmbulaTec',
            style:
                AppTextStyles.h3.copyWith(color: AppColors.accentGold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search,
                color: AppColors.textSecondary),
            onPressed: () => context.go('/search'),
          ),
        ],
      ),
    );
  }
}

// ── Category chips (mobile) ────────────────────────────────────────────────

class _CategoryChips extends ConsumerWidget {
  final String selected;
  const _CategoryChips({required this.selected});

  String _label(String cat) {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppColors.bgSurface,
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: kCategories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = kCategories[index];
          final isSelected = cat == selected;
          return FilterChip(
            label: Text(_label(cat)),
            selected: isSelected,
            onSelected: (_) {
              ref.read(categoryFilterProvider.notifier).state = cat;
            },
            labelStyle: AppTextStyles.caption.copyWith(
              color: isSelected
                  ? AppColors.bgPrimary
                  : AppColors.textSecondary,
            ),
            backgroundColor: AppColors.bgCard,
            selectedColor: AppColors.accentGold,
            checkmarkColor: AppColors.bgPrimary,
            side: BorderSide(
              color: isSelected
                  ? AppColors.accentGold
                  : AppColors.borderOverlay,
            ),
          );
        },
      ),
    );
  }
}

// ── Mobile list ────────────────────────────────────────────────────────────

class _MobileList extends StatelessWidget {
  final List<PostModel> posts;
  const _MobileList({required this.posts});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: posts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final post = posts[index];
        return PostCard(
          post: post,
          onTap: () => context.go('/post/${post.id}'),
        );
      },
    );
  }
}

// ── Desktop 3-col grid ─────────────────────────────────────────────────────

class _DesktopGrid extends StatelessWidget {
  final List<PostModel> posts;
  const _DesktopGrid({required this.posts});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.88,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return PostCard(
          post: post,
          onTap: () => context.go('/post/${post.id}'),
        );
      },
    );
  }
}

// ── Empty view ─────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.storefront_outlined,
            size: 56,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay publicaciones aquí',
            style:
                AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Sé el primero en publicar algo.',
            style: AppTextStyles.body
                .copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Error view ─────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text(
              'Algo salió mal',
              style:
                  AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
