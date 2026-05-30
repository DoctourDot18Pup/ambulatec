import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/data/user_provider.dart';
import '../../feed/domain/post_model.dart';

// ── Page-scoped providers ──────────────────────────────────────────────────

class _StringNotifier extends Notifier<String> {
  final String _initial;
  _StringNotifier([this._initial = '']);
  @override
  String build() => _initial;
  void update(String value) => state = value;
}

class _StringComidaNotifier extends Notifier<String> {
  @override
  String build() => 'comida';
  void update(String value) => state = value;
}

class _ImagesNotifier extends Notifier<List<Uint8List>> {
  @override
  List<Uint8List> build() => [];
  void update(List<Uint8List> value) => state = value;
}

class _BoolNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void update(bool value) => state = value;
}

class _OfferTypeNotifier extends Notifier<OfferType?> {
  @override
  OfferType? build() => null;
  void update(OfferType? value) => state = value;
}

class _IntNotifier extends Notifier<int> {
  @override
  int build() => 1;
  void update(int value) => state = value;
}

class _ExtrasNotifier extends Notifier<List<PostExtra>> {
  @override
  List<PostExtra> build() => [];
  void update(List<PostExtra> value) => state = value;
}

final _titleProvider =
    NotifierProvider.autoDispose<_StringNotifier, String>(_StringNotifier.new);
final _descriptionProvider =
    NotifierProvider.autoDispose<_StringNotifier, String>(_StringNotifier.new);
final _priceProvider =
    NotifierProvider.autoDispose<_StringNotifier, String>(_StringNotifier.new);
final _categoryProvider =
    NotifierProvider.autoDispose<_StringComidaNotifier, String>(_StringComidaNotifier.new);
final _mediaImagesProvider =
    NotifierProvider.autoDispose<_ImagesNotifier, List<Uint8List>>(_ImagesNotifier.new);
final _hasOfferProvider =
    NotifierProvider.autoDispose<_BoolNotifier, bool>(_BoolNotifier.new);
final _offerTypeProvider =
    NotifierProvider.autoDispose<_OfferTypeNotifier, OfferType?>(_OfferTypeNotifier.new);
// Duration index: 0=15min, 1=30min, 2=60min, 3=custom
final _offerDurationIndexProvider =
    NotifierProvider.autoDispose<_IntNotifier, int>(_IntNotifier.new);
final _customDurationProvider =
    NotifierProvider.autoDispose<_StringNotifier, String>(_StringNotifier.new);
final _discountPercentProvider =
    NotifierProvider.autoDispose<_StringNotifier, String>(_StringNotifier.new);
final _specialPriceProvider =
    NotifierProvider.autoDispose<_StringNotifier, String>(_StringNotifier.new);
final _isUploadingProvider =
    NotifierProvider.autoDispose<_BoolNotifier, bool>(_BoolNotifier.new);
final _extrasProvider =
    NotifierProvider.autoDispose<_ExtrasNotifier, List<PostExtra>>(_ExtrasNotifier.new);

final _formValidProvider = Provider.autoDispose<bool>((ref) {
  final title = ref.watch(_titleProvider);
  final price = ref.watch(_priceProvider);
  final images = ref.watch(_mediaImagesProvider);
  final hasOffer = ref.watch(_hasOfferProvider);
  final offerType = ref.watch(_offerTypeProvider);
  final discountPct = ref.watch(_discountPercentProvider);
  final specialPrice = ref.watch(_specialPriceProvider);

  if (title.trim().isEmpty ||
      double.tryParse(price) == null ||
      images.isEmpty) {
    return false;
  }
  if (hasOffer) {
    if (offerType == null) return false;
    if (offerType == OfferType.percent &&
        (int.tryParse(discountPct) == null ||
            (int.tryParse(discountPct) ?? 0) <= 0)) {
      return false;
    }
    if (offerType == OfferType.special &&
        double.tryParse(specialPrice) == null) {
      return false;
    }
  }
  return true;
});

// ── Page ───────────────────────────────────────────────────────────────────

class CreatePostPage extends ConsumerWidget {
  const CreatePostPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUploading = ref.watch(_isUploadingProvider);
    final isValid = ref.watch(_formValidProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => context.go('/dashboard'),
        ),
        title: Text(
          'Nueva publicación',
          style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: isUploading
                ? null
                : () => _publish(context, ref, draft: true),
            child: Text(
              'Borrador',
              style: AppTextStyles.body.copyWith(
                color: isUploading
                    ? AppColors.textSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: const SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 120),
              child: _FormBody(),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _PublishBar(isValid: isValid, isUploading: isUploading),
    );
  }

  Future<void> _publish(
    BuildContext context,
    WidgetRef ref, {
    bool draft = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userModel = ref.read(userProvider).asData?.value;
    final images = ref.read(_mediaImagesProvider);
    final title = ref.read(_titleProvider);
    final description = ref.read(_descriptionProvider);
    final priceText = ref.read(_priceProvider);
    final category = ref.read(_categoryProvider);
    final hasOffer = ref.read(_hasOfferProvider);
    final offerType = ref.read(_offerTypeProvider);
    final durationIndex = ref.read(_offerDurationIndexProvider);
    final customDuration = ref.read(_customDurationProvider);
    final discountPctText = ref.read(_discountPercentProvider);
    final specialPriceText = ref.read(_specialPriceProvider);
    final extras = ref.read(_extrasProvider);

    ref.read(_isUploadingProvider.notifier).update(true);

    try {
      // ── Upload images to Cloudinary ──────────────────────────────────
      final service = CloudinaryService();
      final folder = 'posts/${user.uid}';
      final urls = await Future.wait(
        images.map((bytes) => service.uploadImage(bytes, folder)),
      );

      // ── Price calculations ───────────────────────────────────────────
      final basePrice = double.parse(priceText);
      double finalPrice;
      double? originalPrice;
      int? discountPct;

      if (hasOffer && offerType == OfferType.percent) {
        discountPct = int.tryParse(discountPctText) ?? 0;
        finalPrice = basePrice * (1 - discountPct / 100);
        originalPrice = basePrice;
      } else if (hasOffer && offerType == OfferType.special) {
        finalPrice = double.tryParse(specialPriceText) ?? basePrice;
        originalPrice = basePrice;
      } else {
        finalPrice = basePrice;
        originalPrice = null;
      }

      // ── Offer expiry ─────────────────────────────────────────────────
      DateTime? offerExpiresAt;
      if (hasOffer && offerType != null) {
        const durations = [15, 30, 60];
        final minutes = durationIndex < 3
            ? durations[durationIndex]
            : (int.tryParse(customDuration) ?? 30);
        offerExpiresAt = DateTime.now().add(Duration(minutes: minutes));
      }

      // ── Build PostModel ──────────────────────────────────────────────
      final post = PostModel(
        id: '',
        vendorId: user.uid,
        vendorName: userModel?.displayName ?? '',
        vendorCareer: '',
        vendorPhotoUrl: userModel?.photoUrl,
        vendorStatus: VendorAvailability.active,
        title: title.trim(),
        description: description.trim(),
        mediaUrls: urls,
        category: category,
        price: finalPrice,
        originalPrice: originalPrice,
        hasOffer: hasOffer && offerType != null,
        offerType: offerType,
        discountPercent: discountPct,
        offerExpiresAt: offerExpiresAt,
        createdAt: DateTime.now(),
        isActive: !draft,
        extras: extras,
      );

      await FirebaseFirestore.instance
          .collection(AppConstants.postsCollection)
          .add(post.toMap());

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(draft
              ? 'Borrador guardado'
              : '¡Publicación creada con éxito!'),
          backgroundColor:
              draft ? AppColors.textSecondary : AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go('/dashboard');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      ref.read(_isUploadingProvider.notifier).update(false);
    }
  }
}

// ── Publish bar ────────────────────────────────────────────────────────────

class _PublishBar extends ConsumerWidget {
  final bool isValid;
  final bool isUploading;

  const _PublishBar({required this.isValid, required this.isUploading});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppColors.bgPrimary,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: ElevatedButton(
        onPressed: (isValid && !isUploading)
            ? () => CreatePostPage()._publish(context, ref)
            : null,
        child: isUploading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.bgPrimary)),
              )
            : const Text('Publicar'),
      ),
    );
  }
}

// ── Form body ──────────────────────────────────────────────────────────────

class _FormBody extends ConsumerWidget {
  const _FormBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasOffer = ref.watch(_hasOfferProvider);
    final offerType = ref.watch(_offerTypeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Media grid ───────────────────────────────────────────────
        _MediaGrid(),
        const SizedBox(height: 8),
        Text(
          'Hasta 5 fotos. Mejor con luz natural.',
          style:
              AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),

        // ── Title ────────────────────────────────────────────────────
        _buildLabel('TÍTULO'),
        const SizedBox(height: 6),
        TextFormField(
          style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
          onChanged: (v) =>
              ref.read(_titleProvider.notifier).update(v),
          maxLength: 60,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(counterText: ''),
        ),
        const SizedBox(height: 16),

        // ── Description ───────────────────────────────────────────────
        _buildLabel('DESCRIPCIÓN'),
        const SizedBox(height: 6),
        TextFormField(
          style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
          onChanged: (v) =>
              ref.read(_descriptionProvider.notifier).update(v),
          maxLines: 3,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(counterText: ''),
        ),
        const SizedBox(height: 16),

        // ── Price + category ──────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('PRECIO'),
                  const SizedBox(height: 6),
                  TextFormField(
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textPrimary),
                    onChanged: (v) =>
                        ref.read(_priceProvider.notifier).update(v),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    decoration: const InputDecoration(
                      prefixText: '\$ ',
                      suffixText: 'MXN',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('CATEGORÍA'),
                  const SizedBox(height: 6),
                  _CategoryDropdown(),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Offer toggle ──────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderOverlay),
          ),
          child: SwitchListTile(
            title: Text('Incluir oferta limitada',
                style:
                    AppTextStyles.body.copyWith(color: AppColors.textPrimary)),
            subtitle: Text('Aparece destacada con badge dorado.',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
            value: hasOffer,
            activeThumbColor: AppColors.accentGold,
            onChanged: (v) {
              ref.read(_hasOfferProvider.notifier).update(v);
              if (!v) {
                ref.read(_offerTypeProvider.notifier).update(null);
              }
            },
          ),
        ),

        // ── Offer details (animated) ──────────────────────────────────
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: _OfferDetails(),
          crossFadeState: hasOffer
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),

        // Extra field for percent/special
        if (hasOffer && offerType == OfferType.percent) ...[
          const SizedBox(height: 12),
          _buildLabel('PORCENTAJE DE DESCUENTO'),
          const SizedBox(height: 6),
          TextFormField(
            style:
                AppTextStyles.body.copyWith(color: AppColors.textPrimary),
            onChanged: (v) =>
                ref.read(_discountPercentProvider.notifier).update(v),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              suffixText: '%',
              hintText: '40',
            ),
          ),
        ],
        if (hasOffer && offerType == OfferType.special) ...[
          const SizedBox(height: 12),
          _buildLabel('PRECIO ESPECIAL'),
          const SizedBox(height: 6),
          TextFormField(
            style:
                AppTextStyles.body.copyWith(color: AppColors.textPrimary),
            onChanged: (v) =>
                ref.read(_specialPriceProvider.notifier).update(v),
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                  RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: const InputDecoration(
              prefixText: '\$ ',
              suffixText: 'MXN',
            ),
          ),
        ],

        const SizedBox(height: 24),

        // ── Extras / condiments ───────────────────────────────────────
        const _ExtrasPanel(),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
    );
  }
}

// ── Media grid ─────────────────────────────────────────────────────────────

class _MediaGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = ref.watch(_mediaImagesProvider);
    final isUploading = ref.watch(_isUploadingProvider);

    return Column(
      children: [
        if (isUploading)
          const LinearProgressIndicator(
            color: AppColors.accentGold,
            backgroundColor: AppColors.bgCard,
          ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 5,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            // Add slot
            if (images.length < 5)
              GestureDetector(
                onTap: () => _pickImage(ref),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.borderOverlay, style: BorderStyle.solid),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add,
                          color: AppColors.textSecondary, size: 22),
                    ],
                  ),
                ),
              ),
            // Filled slots
            ...images.asMap().entries.map((entry) {
              final idx = entry.key;
              final bytes = entry.value;
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(bytes, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () {
                        final list =
                            List<Uint8List>.from(ref.read(_mediaImagesProvider));
                        list.removeAt(idx);
                        ref.read(_mediaImagesProvider.notifier).update(list);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                            color: AppColors.error, shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            size: 10, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  Future<void> _pickImage(WidgetRef ref) async {
    try {
      final file = await ImagePicker().pickImage(
          source: ImageSource.gallery, imageQuality: 85);
      if (file != null) {
        final bytes = await file.readAsBytes();
        final list =
            List<Uint8List>.from(ref.read(_mediaImagesProvider));
        if (list.length < 5) {
          list.add(bytes);
          ref.read(_mediaImagesProvider.notifier).update(list);
        }
      }
    } catch (_) {}
  }
}

// ── Category dropdown ──────────────────────────────────────────────────────

class _CategoryDropdown extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_categoryProvider);
    return DropdownButtonFormField<String>(
      initialValue: selected,
      dropdownColor: AppColors.bgCard,
      style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
      decoration: const InputDecoration(),
      items: const [
        DropdownMenuItem(value: 'comida', child: Text('Comida')),
        DropdownMenuItem(value: 'bebidas', child: Text('Bebidas')),
        DropdownMenuItem(value: 'snacks', child: Text('Snacks')),
        DropdownMenuItem(value: 'postres', child: Text('Dulces')),
        DropdownMenuItem(value: 'otros', child: Text('Otros')),
      ],
      onChanged: (v) {
        if (v != null) ref.read(_categoryProvider.notifier).update(v);
      },
    );
  }
}

// ── Offer details ──────────────────────────────────────────────────────────

class _OfferDetails extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offerType = ref.watch(_offerTypeProvider);
    final durationIndex = ref.watch(_offerDurationIndexProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Offer type chips ──────────────────────────────────────────
          Text('Tipo de oferta',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _OfferTypeChip(
                label: '2×1',
                type: OfferType.twoForOne,
                selected: offerType == OfferType.twoForOne,
              ),
              _OfferTypeChip(
                label: '% descuento',
                type: OfferType.percent,
                selected: offerType == OfferType.percent,
              ),
              _OfferTypeChip(
                label: 'Precio especial',
                type: OfferType.special,
                selected: offerType == OfferType.special,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Duration chips ────────────────────────────────────────────
          Text('Duración de la oferta',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (int i = 0; i < 4; i++)
                ChoiceChip(
                  label: Text(_durationLabel(i)),
                  selected: durationIndex == i,
                  onSelected: (_) =>
                      ref.read(_offerDurationIndexProvider.notifier).update(i),
                  selectedColor: AppColors.accentGold,
                  backgroundColor: AppColors.bgCard,
                  labelStyle: AppTextStyles.caption.copyWith(
                    color: durationIndex == i
                        ? AppColors.bgPrimary
                        : AppColors.textSecondary,
                  ),
                  side: BorderSide(
                    color: durationIndex == i
                        ? AppColors.accentGold
                        : AppColors.borderOverlay,
                  ),
                ),
            ],
          ),

          // Custom duration field
          if (durationIndex == 3) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: 160,
              child: TextFormField(
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textPrimary),
                onChanged: (v) =>
                    ref.read(_customDurationProvider.notifier).update(v),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  hintText: 'Minutos',
                  suffixText: 'min',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _durationLabel(int index) {
    switch (index) {
      case 0:
        return '15 min';
      case 1:
        return '30 min';
      case 2:
        return '1 h';
      default:
        return 'Personalizado';
    }
  }
}

class _OfferTypeChip extends ConsumerWidget {
  final String label;
  final OfferType type;
  final bool selected;

  const _OfferTypeChip({
    required this.label,
    required this.type,
    required this.selected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) =>
          ref.read(_offerTypeProvider.notifier).update(selected ? null : type),
      selectedColor: AppColors.accentGold,
      backgroundColor: AppColors.bgCard,
      labelStyle: AppTextStyles.caption.copyWith(
        color: selected ? AppColors.bgPrimary : AppColors.textSecondary,
      ),
      side: BorderSide(
        color: selected ? AppColors.accentGold : AppColors.borderOverlay,
      ),
    );
  }
}

// ── Extras panel ───────────────────────────────────────────────────────────

class _GroupState {
  final String id;
  final TextEditingController labelController;
  final List<TextEditingController> optionControllers;
  bool isMultiple;

  _GroupState({required this.id})
      : labelController = TextEditingController(),
        optionControllers = [
          TextEditingController(),
          TextEditingController(),
        ],
        isMultiple = false;

  void addOption() =>
      optionControllers.add(TextEditingController());

  void removeOption(int i) {
    optionControllers[i].dispose();
    optionControllers.removeAt(i);
  }

  void dispose() {
    labelController.dispose();
    for (final c in optionControllers) {
      c.dispose();
    }
  }
}

class _ExtrasPanel extends ConsumerStatefulWidget {
  const _ExtrasPanel();

  @override
  ConsumerState<_ExtrasPanel> createState() => _ExtrasPanelState();
}

class _ExtrasPanelState extends ConsumerState<_ExtrasPanel> {
  final List<_GroupState> _groups = [];
  int _nextId = 0;

  @override
  void dispose() {
    for (final g in _groups) {
      g.dispose();
    }
    super.dispose();
  }

  void _syncProvider() {
    ref.read(_extrasProvider.notifier).update(_groups
        .map((g) => PostExtra(
              id: g.id,
              label: g.labelController.text.trim(),
              isMultiple: g.isMultiple,
              options: g.optionControllers
                  .map((c) => c.text.trim())
                  .where((s) => s.isNotEmpty)
                  .toList(),
            ))
        .where((e) => e.label.isNotEmpty && e.options.isNotEmpty)
        .toList());
  }

  void _addGroup() {
    setState(() {
      _groups.add(_GroupState(id: 'extra_${_nextId++}'));
    });
  }

  void _removeGroup(int i) {
    setState(() {
      _groups[i].dispose();
      _groups.removeAt(i);
    });
    _syncProvider();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'PERSONALIZACIONES',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _addGroup,
              icon: const Icon(Icons.add, size: 16,
                  color: AppColors.accentGold),
              label: Text('Agregar grupo',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.accentGold)),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
          ],
        ),
        if (_groups.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Text(
              'Opcional. Agrega opciones como tamaño, salsas, extras.',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
        for (int i = 0; i < _groups.length; i++) ...[
          const SizedBox(height: 12),
          _GroupCard(
            group: _groups[i],
            onRemove: () => _removeGroup(i),
            onChanged: _syncProvider,
          ),
        ],
      ],
    );
  }
}

class _GroupCard extends StatefulWidget {
  final _GroupState group;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _GroupCard({
    required this.group,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  @override
  Widget build(BuildContext context) {
    final g = widget.group;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOverlay),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Label + delete ──────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: g.labelController,
                  onChanged: (_) => widget.onChanged(),
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Nombre del grupo (ej: Tamaño)',
                    hintStyle: AppTextStyles.body
                        .copyWith(color: AppColors.textSecondary),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 0, vertical: 8),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                          color: AppColors.accentGold.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.error, size: 18),
                onPressed: widget.onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Single / multiple toggle ─────────────────────────────────
          Row(
            children: [
              Text('Selección múltiple',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
              const Spacer(),
              Switch(
                value: g.isMultiple,
                activeThumbColor: AppColors.accentGold,
                onChanged: (v) {
                  setState(() => g.isMultiple = v);
                  widget.onChanged();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Options ──────────────────────────────────────────────────
          Text('Opciones',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          for (int j = 0; j < g.optionControllers.length; j++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: g.optionControllers[j],
                      onChanged: (_) => widget.onChanged(),
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Opción ${j + 1}',
                        hintStyle: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              BorderSide(color: AppColors.borderOverlay),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              BorderSide(color: AppColors.borderOverlay),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                              color:
                                  AppColors.accentGold.withValues(alpha: 0.6)),
                        ),
                      ),
                    ),
                  ),
                  if (g.optionControllers.length > 2) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        setState(() => g.removeOption(j));
                        widget.onChanged();
                      },
                      child: const Icon(Icons.remove_circle_outline,
                          color: AppColors.error, size: 18),
                    ),
                  ],
                ],
              ),
            ),

          // ── Add option ───────────────────────────────────────────────
          TextButton.icon(
            onPressed: () {
              setState(() => g.addOption());
            },
            icon: const Icon(Icons.add, size: 14,
                color: AppColors.textSecondary),
            label: Text('Agregar opción',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          ),
        ],
      ),
    );
  }
}
