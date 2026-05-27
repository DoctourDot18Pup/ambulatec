import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../feed/domain/post_model.dart';
import '../domain/order_model.dart';
import '../providers/current_order_provider.dart';
import '../providers/payment_provider.dart';

// ── Page-scoped form providers ─────────────────────────────────────────────

final _cardNumberProvider =
    StateProvider.autoDispose<String>((ref) => '');
final _expiryProvider = StateProvider.autoDispose<String>((ref) => '');
final _cvvProvider = StateProvider.autoDispose<String>((ref) => '');
final _holderNameProvider =
    StateProvider.autoDispose<String>((ref) => '');

final _paymentFormValidProvider = Provider.autoDispose<bool>((ref) {
  final number =
      ref.watch(_cardNumberProvider).replaceAll(' ', '');
  final expiry = ref.watch(_expiryProvider);
  final cvv = ref.watch(_cvvProvider);
  final name = ref.watch(_holderNameProvider);
  return number.length == 16 &&
      _isValidExpiry(expiry) &&
      (cvv.length == 3 || cvv.length == 4) &&
      name.trim().isNotEmpty;
});

// ── Helpers ────────────────────────────────────────────────────────────────

bool _isValidExpiry(String expiry) {
  final cleaned =
      expiry.replaceAll(' ', '').replaceAll('/', '');
  if (cleaned.length != 4) return false;
  final month = int.tryParse(cleaned.substring(0, 2));
  final year = int.tryParse(cleaned.substring(2, 4));
  if (month == null || year == null) return false;
  if (month < 1 || month > 12) return false;
  final now = DateTime.now();
  final expiryDate = DateTime(2000 + year, month + 1);
  return expiryDate.isAfter(now);
}

double _computeTotal(PostModel post, int quantity) {
  if (!post.hasOffer) return post.price * quantity;
  if (post.offerType == OfferType.twoForOne) {
    return post.price * ((quantity + 1) ~/ 2);
  }
  return post.price * quantity;
}

String _fmtPrice(double v) =>
    '\$${v.toStringAsFixed(v % 1 == 0 ? 0 : 2)}';

// ── Page ───────────────────────────────────────────────────────────────────

class PaymentPage extends ConsumerWidget {
  const PaymentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(currentOrderProvider);

    if (draft == null) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: _appBar(context),
        body: Center(
          child: Text('Sin orden activa',
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textSecondary)),
        ),
      );
    }

    final total =
        _computeTotal(draft.post, draft.quantity);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;
        return isDesktop
            ? _DesktopLayout(draft: draft, total: total)
            : _MobileLayout(draft: draft, total: total);
      },
    );
  }

  AppBar _appBar(BuildContext context) => AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: AppColors.textPrimary),
          onPressed: () => context.go('/order-summary'),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pago',
                style: AppTextStyles.h3
                    .copyWith(color: AppColors.textPrimary)),
            Text('Pago seguro · Stripe',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
}

// ── Mobile layout ──────────────────────────────────────────────────────────

class _MobileLayout extends ConsumerWidget {
  final OrderDraft draft;
  final double total;
  const _MobileLayout({required this.draft, required this.total});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payState = ref.watch(paymentProvider);
    final isFormValid = ref.watch(_paymentFormValidProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: AppColors.textPrimary),
          onPressed: () => context.go('/order-summary'),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pago',
                style: AppTextStyles.h3
                    .copyWith(color: AppColors.textPrimary)),
            Text('Pago seguro · Stripe',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            child: Column(
              children: [
                _ProductSummaryCard(draft: draft, total: total),
                const SizedBox(height: 16),
                const _CardForm(showPostalCode: false),
                const SizedBox(height: 16),
                _TotalCard(total: total),
                const SizedBox(height: 12),
                _SecurityNote(),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _PayButton(
              total: total,
              draft: draft,
              isFormValid: isFormValid,
              isLoading: payState.isLoading,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Desktop layout ─────────────────────────────────────────────────────────

class _DesktopLayout extends ConsumerWidget {
  final OrderDraft draft;
  final double total;
  const _DesktopLayout({required this.draft, required this.total});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payState = ref.watch(paymentProvider);
    final isFormValid = ref.watch(_paymentFormValidProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary.withValues(alpha: 0.9),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderOverlay),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Modal header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text('Pago',
                                style: AppTextStyles.h3.copyWith(
                                    color: AppColors.textPrimary)),
                            Text('Pago seguro · Stripe',
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: AppColors.textSecondary),
                        onPressed: () => context.go('/order-summary'),
                      ),
                    ],
                  ),
                ),
                const Divider(color: AppColors.borderOverlay),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _ProductSummaryCard(
                            draft: draft, total: total),
                        const SizedBox(height: 16),
                        const _CardForm(showPostalCode: true),
                        const SizedBox(height: 16),
                        _TotalCard(total: total),
                        const SizedBox(height: 12),
                        _SecurityNote(),
                        const SizedBox(height: 16),
                        _PayButton(
                          total: total,
                          draft: draft,
                          isFormValid: isFormValid,
                          isLoading: payState.isLoading,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Product summary card ───────────────────────────────────────────────────

class _ProductSummaryCard extends StatelessWidget {
  final OrderDraft draft;
  final double total;
  const _ProductSummaryCard(
      {required this.draft, required this.total});

  @override
  Widget build(BuildContext context) {
    final post = draft.post;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOverlay),
      ),
      child: Row(
        children: [
          if (post.mediaUrls.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: post.mediaUrls.first,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                    color: AppColors.bgSurface, width: 60, height: 60),
                errorWidget: (_, _, _) => Container(
                    color: AppColors.bgSurface,
                    width: 60,
                    height: 60,
                    child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: AppColors.textSecondary)),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.vendorName,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(post.title,
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis),
                if (draft.quantity > 1) ...[
                  const SizedBox(height: 2),
                  Text('× ${draft.quantity}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_fmtPrice(total),
                  style: AppTextStyles.h3
                      .copyWith(color: AppColors.accentGold)),
              if (post.hasOffer &&
                  post.originalPrice != null &&
                  post.originalPrice! > post.price)
                Text(
                  _fmtPrice(
                      (post.originalPrice ?? post.price) *
                          draft.quantity),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Card form ──────────────────────────────────────────────────────────────

class _CardForm extends ConsumerWidget {
  final bool showPostalCode;
  const _CardForm({required this.showPostalCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOverlay),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Datos de pago',
              style: AppTextStyles.body.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),

          // Card number
          _fieldLabel('NÚMERO DE TARJETA'),
          const SizedBox(height: 6),
          _CardNumberField(),
          const SizedBox(height: 14),

          // Expiry + CVV row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('VENCIMIENTO'),
                    const SizedBox(height: 6),
                    _ExpiryField(),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('CVV'),
                    const SizedBox(height: 6),
                    _CvvField(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Holder name
          _fieldLabel('NOMBRE DEL TITULAR'),
          const SizedBox(height: 6),
          TextFormField(
            style: AppTextStyles.body
                .copyWith(color: AppColors.textPrimary),
            textCapitalization: TextCapitalization.characters,
            onChanged: (v) =>
                ref.read(_holderNameProvider.notifier).state = v,
            decoration:
                const InputDecoration(hintText: 'COMO APARECE EN LA TARJETA'),
          ),

          // Postal code (desktop only)
          if (showPostalCode) ...[
            const SizedBox(height: 14),
            _fieldLabel('CÓDIGO POSTAL'),
            const SizedBox(height: 6),
            TextFormField(
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textPrimary),
              keyboardType: TextInputType.number,
              maxLength: 5,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly
              ],
              decoration: const InputDecoration(counterText: ''),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(
        text,
        style: AppTextStyles.caption
            .copyWith(color: AppColors.textSecondary),
      );
}

// ── Card number field ──────────────────────────────────────────────────────

class _CardNumberField extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final number = ref.watch(_cardNumberProvider);
    final clean = number.replaceAll(' ', '');
    IconData? brandIcon;
    if (clean.startsWith('4')) brandIcon = Icons.credit_card;
    if (clean.startsWith('5')) brandIcon = Icons.credit_card_outlined;

    return TextFormField(
      style:
          AppTextStyles.body.copyWith(color: AppColors.textPrimary),
      keyboardType: TextInputType.number,
      maxLength: 19, // 16 digits + 3 spaces
      onChanged: (v) =>
          ref.read(_cardNumberProvider.notifier).state = v,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        _CardNumberFormatter(),
      ],
      decoration: InputDecoration(
        hintText: '0000 0000 0000 0000',
        counterText: '',
        suffixIcon: brandIcon != null
            ? Icon(brandIcon, color: AppColors.textSecondary)
            : null,
      ),
    );
  }
}

// ── Expiry field ───────────────────────────────────────────────────────────

class _ExpiryField extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextFormField(
      style:
          AppTextStyles.body.copyWith(color: AppColors.textPrimary),
      keyboardType: TextInputType.number,
      maxLength: 7, // "MM / AA"
      onChanged: (v) =>
          ref.read(_expiryProvider.notifier).state = v,
      inputFormatters: [_ExpiryFormatter()],
      decoration: const InputDecoration(
        hintText: 'MM / AA',
        counterText: '',
      ),
    );
  }
}

// ── CVV field ──────────────────────────────────────────────────────────────

class _CvvField extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextFormField(
      style:
          AppTextStyles.body.copyWith(color: AppColors.textPrimary),
      keyboardType: TextInputType.number,
      maxLength: 4,
      obscureText: true,
      onChanged: (v) => ref.read(_cvvProvider.notifier).state = v,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration:
          const InputDecoration(hintText: '•••', counterText: ''),
    );
  }
}

// ── Total card ─────────────────────────────────────────────────────────────

class _TotalCard extends StatelessWidget {
  final double total;
  const _TotalCard({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOverlay),
      ),
      child: Row(
        children: [
          Text('TOTAL',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary)),
          const Spacer(),
          Text(_fmtPrice(total),
              style: AppTextStyles.h2
                  .copyWith(color: AppColors.accentGold)),
        ],
      ),
    );
  }
}

// ── Security note ──────────────────────────────────────────────────────────

class _SecurityNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_outline,
            size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Pago cifrado de punta a punta. '
            'AmbulaTec nunca ve tus datos.',
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

// ── Pay button ─────────────────────────────────────────────────────────────

class _PayButton extends ConsumerWidget {
  final double total;
  final OrderDraft draft;
  final bool isFormValid;
  final bool isLoading;

  const _PayButton({
    required this.total,
    required this.draft,
    required this.isFormValid,
    required this.isLoading,
  });

  Future<void> _onPay(BuildContext context, WidgetRef ref) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final notifier = ref.read(paymentProvider.notifier);

    // Generate Firestore doc reference before paying (passes orderId to Stripe metadata).
    final orderRef =
        FirebaseFirestore.instance.collection('orders').doc();

    // ── Step 1: Create PaymentIntent ──────────────────────────────
    await notifier.createPaymentIntent(total, orderRef.id);

    final state1 = ref.read(paymentProvider);
    if (state1.error != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(state1.error!),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }

    // ── Step 2: Confirm payment ───────────────────────────────────
    await notifier.confirmPayment(
      CardDetails(
        number: ref.read(_cardNumberProvider),
        expiry: ref.read(_expiryProvider),
        cvv: ref.read(_cvvProvider),
        holderName: ref.read(_holderNameProvider),
      ),
      state1.clientSecret!,
    );

    final state2 = ref.read(paymentProvider);
    if (state2.error != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(state2.error!),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }

    // ── Step 3: Write order to Firestore ──────────────────────────
    final post = draft.post;
    final quantity = draft.quantity;
    final originalTotal = (post.originalPrice ?? post.price) * quantity;

    final order = OrderModel(
      id: orderRef.id,
      buyerId: user.uid,
      buyerName: user.displayName ?? '',
      buyerPhotoUrl: user.photoURL ?? '',
      vendorId: post.vendorId,
      postId: post.id,
      postTitle: post.title,
      postMediaUrls: post.mediaUrls,
      originalPrice: originalTotal,
      finalPrice: total,
      quantity: quantity,
      offerApplied: post.hasOffer,
      offerType: post.offerType,
      deliveryNote: draft.deliveryNote,
      deliveryImageUrl: null,
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
      chatExpiresAt:
          DateTime.now().add(const Duration(hours: 24)),
    );

    await orderRef.set(order.toMap());

    // ── Step 4: Write in-app notification for the vendor ──────────
    // The notification drives the Firestore-based banner shown in
    // _NotificationWrapper. No FCM / Blaze plan required.
    await FirebaseFirestore.instance
        .collection(AppConstants.notificationsCollection)
        .doc(orderRef.id)
        .set({
      'type': 'new_order',
      'recipientId': post.vendorId, // vendor receives this
      'vendorId': post.vendorId,
      'orderId': orderRef.id,
      'buyerName': user.displayName ?? '',
      'productTitle': post.title,
      'status': 'unread',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // ── Step 5: Navigate to confirmation ──────────────────────────
    ref.read(confirmedOrderIdProvider.notifier).state = orderRef.id;

    if (context.mounted) {
      context.go('/order-confirmed');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppColors.bgPrimary,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: ElevatedButton(
        onPressed: (isFormValid && !isLoading)
            ? () => _onPay(context, ref)
            : null,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.bgPrimary),
                ),
              )
            : Text('Pagar ${_fmtPrice(total)}'),
      ),
    );
  }
}

// ── Input formatters ───────────────────────────────────────────────────────

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 16) {
      return oldValue;
    }
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Strip everything except digits
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 4) return oldValue;

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 2) buffer.write(' / ');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
