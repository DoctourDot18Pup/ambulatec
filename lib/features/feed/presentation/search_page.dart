import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/adaptive_scaffold.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/rating_stars_widget.dart';
import '../../auth/domain/user_model.dart';
import '../domain/post_model.dart';
import '../providers/search_provider.dart';

// ── Categories metadata ────────────────────────────────────────────────────

const _categoryMeta = [
  (id: 'comida', label: 'Comida', icon: Icons.fastfood_outlined),
  (id: 'bebidas', label: 'Bebidas', icon: Icons.local_drink_outlined),
  (id: 'postres', label: 'Postres', icon: Icons.cake_outlined),
  (id: 'snacks', label: 'Snacks', icon: Icons.cookie_outlined),
  (id: 'otros', label: 'Otros', icon: Icons.category_outlined),
  (id: 'todos', label: 'Ver todo', icon: Icons.apps_outlined),
];

// ── Page ───────────────────────────────────────────────────────────────────

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: ref.read(searchQueryProvider),
    );
    _focus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);

    return AdaptiveScaffold(
      currentIndex: 2,
      body: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          backgroundColor: AppColors.bgSurface,
          elevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
              cursorColor: AppColors.accentGold,
              decoration: InputDecoration(
                hintText: 'Buscar productos o vendedores…',
                hintStyle:
                    AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.bgCard,
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.textSecondary, size: 20),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close,
                            color: AppColors.textSecondary, size: 18),
                        onPressed: () {
                          _ctrl.clear();
                          ref.read(searchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
              onChanged: (v) =>
                  ref.read(searchQueryProvider.notifier).state = v,
            ),
          ),
        ),
        body: query.trim().length < 2
            ? _InitialState(query: query)
            : const _SearchResults(),
      ),
    );
  }
}

// ── Initial state (empty query) ────────────────────────────────────────────

class _InitialState extends ConsumerWidget {
  final String query;
  const _InitialState({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorsAsync = ref.watch(activeVendorsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Categories grid ───────────────────────────────────────────
        Text('CATEGORÍAS',
            style:
                AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.4,
          children: _categoryMeta.map((cat) {
            return _CategoryTile(
              icon: cat.icon,
              label: cat.label,
              onTap: () {
                ref.read(searchQueryProvider.notifier).state = cat.id == 'todos'
                    ? ''
                    : cat.label.toLowerCase();
              },
            );
          }).toList(),
        ),

        // ── Active vendors horizontal list ────────────────────────────
        const SizedBox(height: 24),
        Text('VENDEDORES ACTIVOS',
            style:
                AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        vendorsAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accentGold)),
          error: (_, _) => const SizedBox.shrink(),
          data: (vendors) {
            if (vendors.isEmpty) {
              return Text(
                'No hay vendedores activos en este momento.',
                style:
                    AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              );
            }
            return SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: vendors.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) =>
                    _VendorChip(vendor: vendors[i]),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── Search results ─────────────────────────────────────────────────────────

class _SearchResults extends ConsumerWidget {
  const _SearchResults();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(searchResultsProvider);

    return resultsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accentGold)),
      error: (e, _) => Center(
          child: Text('$e',
              style: AppTextStyles.body.copyWith(color: AppColors.error))),
      data: (results) {
        if (results.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.search_off_outlined,
            title: 'Sin resultados',
            subtitle: 'Prueba con otro término de búsqueda.',
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Posts ───────────────────────────────────────────────────
            if (results.posts.isNotEmpty) ...[
              Text('PRODUCTOS',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              ...results.posts.map((p) => _PostResultTile(post: p)),
              const SizedBox(height: 20),
            ],

            // ── Vendors ─────────────────────────────────────────────────
            if (results.vendors.isNotEmpty) ...[
              Text('VENDEDORES',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              ...results.vendors.map((v) => _VendorResultTile(vendor: v)),
            ],
          ],
        );
      },
    );
  }
}

// ── Category tile ──────────────────────────────────────────────────────────

class _CategoryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderOverlay),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.accentGold, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Vendor chip (horizontal list) ─────────────────────────────────────────

class _VendorChip extends ConsumerWidget {
  final UserModel vendor;
  const _VendorChip({required this.vendor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () =>
          ref.read(searchQueryProvider.notifier).state = vendor.displayName,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.accentGreen,
              backgroundImage: vendor.photoUrl != null
                  ? NetworkImage(vendor.photoUrl!)
                  : null,
              child: vendor.photoUrl == null
                  ? Text(
                      vendor.displayName.isNotEmpty
                          ? vendor.displayName[0].toUpperCase()
                          : '?',
                      style: AppTextStyles.body
                          .copyWith(color: Colors.white, fontSize: 20),
                    )
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              vendor.displayName.split(' ').first,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Post result tile ───────────────────────────────────────────────────────

class _PostResultTile extends StatelessWidget {
  final PostModel post;
  const _PostResultTile({required this.post});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/post/${post.id}'),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderOverlay),
          ),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: post.mediaUrls.isNotEmpty
                    ? Image.network(
                        post.mediaUrls.first,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _placeholderBox(),
                      )
                    : _placeholderBox(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.title,
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      post.vendorName,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '\$${post.price.toStringAsFixed(post.price % 1 == 0 ? 0 : 2)}',
                style: AppTextStyles.body.copyWith(
                    color: AppColors.accentGold,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderBox() => Container(
        width: 56,
        height: 56,
        color: AppColors.bgSurface,
        child: const Icon(Icons.image_outlined,
            color: AppColors.textSecondary, size: 22),
      );
}

// ── Vendor result tile ─────────────────────────────────────────────────────

class _VendorResultTile extends ConsumerWidget {
  final UserModel vendor;
  const _VendorResultTile({required this.vendor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/vendor/${vendor.uid}'),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderOverlay),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.accentGreen,
                backgroundImage: vendor.photoUrl != null
                    ? NetworkImage(vendor.photoUrl!)
                    : null,
                child: vendor.photoUrl == null
                    ? Text(
                        vendor.displayName.isNotEmpty
                            ? vendor.displayName[0].toUpperCase()
                            : '?',
                        style: AppTextStyles.body
                            .copyWith(color: Colors.white),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vendor.displayName,
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.textPrimary),
                    ),
                    if (vendor.vendorRating > 0)
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
                        ],
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: AppColors.textSecondary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
