import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../orders/providers/current_order_provider.dart';
import '../data/following_provider.dart';
import '../data/follow_controller.dart';
import '../data/posts_provider.dart';
import '../domain/post_model.dart';

// ── Page-scoped delivery providers ────────────────────────────────────────

final _deliveryNoteProvider =
    StateProvider.autoDispose<String>((ref) => '');
final _deliveryImageBytesProvider =
    StateProvider.autoDispose<Uint8List?>((ref) => null);

/// Selected options per extra: extraId → Set of selected option strings.
final _selectedExtrasProvider =
    StateProvider.autoDispose<Map<String, Set<String>>>((ref) => {});

final _quantityProvider = StateProvider.autoDispose<int>((ref) => 1);

// ── Offer countdown provider ───────────────────────────────────────────────

final _offerCountdownProvider =
    StreamProvider.autoDispose.family<Duration?, String>((ref, postId) {
  final postsAsync = ref.watch(postsProvider);
  final post = postsAsync.asData?.value
      .where((p) => p.id == postId)
      .firstOrNull;

  if (post == null || !post.hasOffer || post.offerExpiresAt == null) {
    return Stream.value(null);
  }

  return Stream.periodic(const Duration(seconds: 1), (_) {
    final remaining = post.offerExpiresAt!.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  });
});

// ── Page ───────────────────────────────────────────────────────────────────

class PostDetailPage extends ConsumerStatefulWidget {
  final String postId;
  const PostDetailPage({super.key, required this.postId});

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(postsProvider);
    final post = postsAsync.asData?.value
        .where((p) => p.id == widget.postId)
        .firstOrNull;

    if (postsAsync.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body:
            Center(child: CircularProgressIndicator(color: AppColors.accentGold)),
      );
    }

    if (post == null) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          backgroundColor: AppColors.bgSurface,
          elevation: 0,
          leading: BackButton(
            color: AppColors.textPrimary,
            onPressed: () => context.go('/home'),
          ),
        ),
        body: Center(
          child: Text(
            'Publicación no encontrada',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return _DetailView(
      post: post,
      pageController: _pageController,
      currentPage: _currentPage,
      onPageChanged: (p) => setState(() => _currentPage = p),
    );
  }
}

// ── Detail view ────────────────────────────────────────────────────────────

class _DetailView extends ConsumerWidget {
  final PostModel post;
  final PageController pageController;
  final int currentPage;
  final void Function(int) onPageChanged;

  const _DetailView({
    required this.post,
    required this.pageController,
    required this.currentPage,
    required this.onPageChanged,
  });

  Future<void> _pickDeliveryImage(WidgetRef ref) async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file != null) {
        final bytes = await file.readAsBytes();
        ref.read(_deliveryImageBytesProvider.notifier).state = bytes;
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingAsync = ref.watch(followingProvider);
    final isFollowing =
        (followingAsync.asData?.value ?? []).contains(post.vendorId);
    final isFollowLoading =
        ref.watch(followControllerProvider).isLoading;
    final deliveryNote = ref.watch(_deliveryNoteProvider);
    final deliveryImageBytes = ref.watch(_deliveryImageBytesProvider);
    final selectedExtras = ref.watch(_selectedExtrasProvider);
    final quantity = ref.watch(_quantityProvider);
    final canOrder = deliveryNote.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.go('/home'),
        ),
        title: Text(
          post.title,
          style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Image gallery ──────────────────────────────────────
                if (post.mediaUrls.isNotEmpty)
                  SizedBox(
                    height: 280,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        PageView.builder(
                          controller: pageController,
                          itemCount: post.mediaUrls.length,
                          onPageChanged: onPageChanged,
                          itemBuilder: (context, index) {
                            return CachedNetworkImage(
                              imageUrl: post.mediaUrls[index],
                              fit: BoxFit.cover,
                              placeholder: (_, _) => Container(
                                color: AppColors.bgSurface,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.textSecondary),
                                ),
                              ),
                              errorWidget: (_, _, _) => Container(
                                color: AppColors.bgSurface,
                                child: const Icon(
                                    Icons.image_not_supported_outlined,
                                    color: AppColors.textSecondary),
                              ),
                            );
                          },
                        ),
                        if (post.mediaUrls.length > 1)
                          Positioned(
                            bottom: 12,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                post.mediaUrls.length,
                                (i) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  width: i == currentPage ? 16 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: i == currentPage
                                        ? AppColors.accentGold
                                        : AppColors.textSecondary
                                            .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (post.hasOffer && post.offerBadgeText.isNotEmpty)
                          Positioned(
                            top: 14,
                            left: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.accentGold,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                post.offerBadgeText,
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.bgPrimary,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Vendor row ───────────────────────────────────
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.bgCard,
                            backgroundImage: post.vendorPhotoUrl != null
                                ? CachedNetworkImageProvider(
                                    post.vendorPhotoUrl!)
                                : null,
                            child: post.vendorPhotoUrl == null
                                ? Text(
                                    post.vendorName.isNotEmpty
                                        ? post.vendorName[0].toUpperCase()
                                        : '?',
                                    style: AppTextStyles.body
                                        .copyWith(color: AppColors.textPrimary),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(post.vendorName,
                                    style: AppTextStyles.body.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600)),
                                Text(post.vendorCareer,
                                    style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: isFollowLoading
                                ? null
                                : () => ref
                                    .read(followControllerProvider.notifier)
                                    .toggleFollow(post.vendorId),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isFollowing
                                  ? AppColors.textSecondary
                                  : AppColors.accentGold,
                              side: BorderSide(
                                  color: isFollowing
                                      ? AppColors.borderOverlay
                                      : AppColors.accentGold),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              isFollowing ? 'Siguiendo' : 'Seguir',
                              style: AppTextStyles.caption.copyWith(
                                  color: isFollowing
                                      ? AppColors.textSecondary
                                      : AppColors.accentGold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Title ────────────────────────────────────────
                      Text(post.title,
                          style: AppTextStyles.h2
                              .copyWith(color: AppColors.textPrimary)),
                      const SizedBox(height: 8),

                      // ── Description ──────────────────────────────────
                      Text(post.description,
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 20),

                      // ── Price section ────────────────────────────────
                      _PriceSection(post: post),
                      const SizedBox(height: 12),

                      // ── Offer countdown ──────────────────────────────
                      if (post.hasOffer && post.offerExpiresAt != null)
                        _OfferCountdown(postId: post.id),

                      const SizedBox(height: 24),

                      // ── Quantity stepper ─────────────────────────────
                      _QuantityStepper(unitPrice: post.price),
                      const SizedBox(height: 24),

                      // ── Extras selector ──────────────────────────────
                      if (post.extras.isNotEmpty) ...[
                        _ExtrasSelector(post: post),
                        const SizedBox(height: 24),
                      ],

                      // ── Delivery field ───────────────────────────────
                      Text(
                        '¿DÓNDE TE LO ENTREGAMOS?',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.textPrimary),
                        onChanged: (v) =>
                            ref.read(_deliveryNoteProvider.notifier).state =
                                v,
                        decoration: const InputDecoration(
                          hintText: '¿Dónde te lo entregamos?',
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ── Reference photo ───────────────────────────────
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => _pickDeliveryImage(ref),
                            icon: const Icon(Icons.attach_file,
                                size: 16,
                                color: AppColors.textSecondary),
                            label: Text(
                              'Adjuntar foto de referencia',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textSecondary),
                            ),
                            style: TextButton.styleFrom(
                                padding: EdgeInsets.zero),
                          ),
                          if (deliveryImageBytes != null) ...[
                            const SizedBox(width: 8),
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.memory(
                                    deliveryImageBytes,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: GestureDetector(
                                    onTap: () => ref
                                        .read(
                                            _deliveryImageBytesProvider
                                                .notifier)
                                        .state = null,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: AppColors.error,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close,
                                          size: 12,
                                          color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
                ),
              ),
            ),

          // ── Fixed CTA button ─────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: AppColors.bgPrimary,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: ElevatedButton(
                onPressed: canOrder
                    ? () {
                        // Convert Set<String> → List<String> for storage.
                        final extras = selectedExtras.map(
                          (k, v) => MapEntry(k, v.toList()),
                        );
                        ref.read(currentOrderProvider.notifier).state =
                            OrderDraft(
                          post: post,
                          deliveryNote: deliveryNote,
                          deliveryImageBytes: deliveryImageBytes,
                          selectedExtras: extras,
                          quantity: quantity,
                        );
                        context.go('/order-summary');
                      }
                    : null,
                child: const Text('Enviar solicitud'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Price section ──────────────────────────────────────────────────────────

class _PriceSection extends StatelessWidget {
  final PostModel post;
  const _PriceSection({required this.post});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '\$${post.price.toStringAsFixed(post.price % 1 == 0 ? 0 : 2)}',
          style: AppTextStyles.h1.copyWith(color: AppColors.accentGold),
        ),
        if (post.originalPrice != null && post.originalPrice! > post.price) ...[
          const SizedBox(width: 10),
          Text(
            '\$${post.originalPrice!.toStringAsFixed(post.originalPrice! % 1 == 0 ? 0 : 2)}',
            style: AppTextStyles.h3.copyWith(
                color: AppColors.textSecondary,
                decoration: TextDecoration.lineThrough),
          ),
        ],
      ],
    );
  }
}

// ── Extras selector ────────────────────────────────────────────────────────

class _ExtrasSelector extends ConsumerWidget {
  final PostModel post;
  const _ExtrasSelector({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_selectedExtrasProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: post.extras.map((extra) {
        final current = selected[extra.id] ?? <String>{};
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                extra.label.toUpperCase(),
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: extra.options.map((opt) {
                  final isSelected = current.contains(opt);
                  return GestureDetector(
                    onTap: () {
                      final map = Map<String, Set<String>>.from(
                          ref.read(_selectedExtrasProvider));
                      final set = Set<String>.from(map[extra.id] ?? {});
                      if (extra.isMultiple) {
                        isSelected ? set.remove(opt) : set.add(opt);
                      } else {
                        set.clear();
                        if (!isSelected) set.add(opt);
                      }
                      map[extra.id] = set;
                      ref.read(_selectedExtrasProvider.notifier).state = map;
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accentGold.withValues(alpha: 0.18)
                            : AppColors.bgCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accentGold
                              : AppColors.borderOverlay,
                        ),
                      ),
                      child: Text(
                        opt,
                        style: AppTextStyles.body.copyWith(
                          color: isSelected
                              ? AppColors.accentGold
                              : AppColors.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Quantity stepper ───────────────────────────────────────────────────────

class _QuantityStepper extends ConsumerWidget {
  final double unitPrice;
  const _QuantityStepper({required this.unitPrice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qty = ref.watch(_quantityProvider);
    final total = unitPrice * qty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CANTIDAD',
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Row(
          children: [
            _StepButton(
              icon: Icons.remove,
              enabled: qty > 1,
              onTap: () =>
                  ref.read(_quantityProvider.notifier).state = qty - 1,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                '$qty',
                style: AppTextStyles.h2
                    .copyWith(color: AppColors.textPrimary),
              ),
            ),
            _StepButton(
              icon: Icons.add,
              enabled: qty < 99,
              onTap: () =>
                  ref.read(_quantityProvider.notifier).state = qty + 1,
            ),
            const Spacer(),
            if (qty > 1)
              Text(
                'Total: \$${total.toStringAsFixed(total % 1 == 0 ? 0 : 2)}',
                style: AppTextStyles.body.copyWith(
                    color: AppColors.accentGold,
                    fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _StepButton(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color =
        enabled ? AppColors.accentGold : AppColors.textSecondary;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: enabled
                  ? AppColors.accentGold.withValues(alpha: 0.5)
                  : AppColors.borderOverlay),
          color: enabled
              ? AppColors.accentGold.withValues(alpha: 0.1)
              : Colors.transparent,
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ── Offer countdown ────────────────────────────────────────────────────────

class _OfferCountdown extends ConsumerWidget {
  final String postId;
  const _OfferCountdown({required this.postId});

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countdownAsync = ref.watch(_offerCountdownProvider(postId));
    return countdownAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (remaining) {
        if (remaining == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: AppColors.accentGold.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_outlined,
                  size: 16, color: AppColors.accentGold),
              const SizedBox(width: 6),
              Text('Oferta termina en ',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
              Text(_formatDuration(remaining),
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.accentGold,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }
}
