import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/current_order_provider.dart';
import '../providers/payment_provider.dart';

class OrderConfirmedPage extends ConsumerWidget {
  const OrderConfirmedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(currentOrderProvider);
    final orderId = ref.watch(confirmedOrderIdProvider);

    final vendorName = draft?.post.vendorName ?? '';
    final deliveryNote = draft?.deliveryNote ?? '';
    final shortId = orderId != null && orderId.length >= 6
        ? orderId.substring(0, 6).toUpperCase()
        : (orderId?.toUpperCase() ?? '------');

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // ── Success icon ────────────────────────────────────
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Title ───────────────────────────────────────────
                  Text(
                    '¡Solicitud enviada!',
                    style: AppTextStyles.h2
                        .copyWith(color: AppColors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // ── Subtitle ────────────────────────────────────────
                  Text(
                    vendorName.isNotEmpty
                        ? '$vendorName revisará tu solicitud y te avisará si puede aceptarla.'
                        : 'El vendedor revisará tu pedido y te avisará por el chat.',
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // ── Order ID chip ───────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: AppColors.borderOverlay),
                    ),
                    child: Text(
                      'ORDEN #AT-$shortId',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.accentGold,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Delivery card ────────────────────────────────────
                  if (deliveryNote.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.borderOverlay),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              color: AppColors.accentGold,
                              size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              deliveryNote,
                              style: AppTextStyles.body.copyWith(
                                  color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const Spacer(flex: 3),

                  // ── Chat button ──────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: orderId != null
                          ? () => context.go('/chat/$orderId')
                          : null,
                      child: const Text('Ver chat con vendedor'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Back to feed ─────────────────────────────────────
                  TextButton(
                    onPressed: () {
                      // Clear order state before leaving
                      ref
                          .read(currentOrderProvider.notifier)
                          .state = null;
                      ref.read(paymentProvider.notifier).reset();
                      ref
                          .read(confirmedOrderIdProvider.notifier)
                          .state = null;
                      context.go('/home');
                    },
                    child: Text(
                      'Volver al inicio',
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
