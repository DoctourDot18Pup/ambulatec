import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/auth_controller.dart';

// ── Providers ─────────────────────────────────────────────────────────────

final _buyerSelectedProvider =
    StateProvider.autoDispose<bool>((ref) => false);
final _vendorSelectedProvider =
    StateProvider.autoDispose<bool>((ref) => false);

// ── Page ──────────────────────────────────────────────────────────────────

class RoleSelectPage extends ConsumerWidget {
  const RoleSelectPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buyerSelected = ref.watch(_buyerSelectedProvider);
    final vendorSelected = ref.watch(_vendorSelectedProvider);
    final anySelected = buyerSelected || vendorSelected;
    final isLoading =
        ref.watch(authControllerProvider).isLoading;

    // Show SnackBar on error.
    ref.listen<AsyncValue<void>>(authControllerProvider, (_, state) {
      state.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.toString()),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    });

    Future<void> onContinue() async {
      final roles = <String>[
        if (buyerSelected) 'buyer',
        if (vendorSelected) 'vendor',
      ];
      await ref.read(authControllerProvider.notifier).setRoles(roles);
      if (!context.mounted) return;
      // Router's redirect will handle navigation once Firestore updates.
      if (vendorSelected) {
        context.go('/vendor-verify');
      } else {
        context.go('/home');
      }
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),
                  Text(
                    '¿Cómo quieres\nusar AmbulaTec?',
                    style: AppTextStyles.h2
                        .copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Puedes elegir uno o ambos. Cambia en cualquier momento desde tu perfil.',
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 32),

                  // ── Buyer card ────────────────────────────────────────
                  _RoleCard(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Soy comprador',
                    subtitle:
                        'Descubre lo que se vende hoy en el campus.',
                    selected: buyerSelected,
                    onTap: () => ref
                        .read(_buyerSelectedProvider.notifier)
                        .state = !buyerSelected,
                  ),
                  const SizedBox(height: 12),

                  // ── Vendor card ───────────────────────────────────────
                  _RoleCard(
                    icon: Icons.storefront_outlined,
                    title: 'Quiero vender',
                    subtitle: 'Publica productos y recibe pedidos.',
                    selected: vendorSelected,
                    requiresVerification: true,
                    onTap: () => ref
                        .read(_vendorSelectedProvider.notifier)
                        .state = !vendorSelected,
                  ),

                  const Spacer(),

                  // ── Continue button ───────────────────────────────────
                  ElevatedButton(
                    onPressed: (anySelected && !isLoading) ? onContinue : null,
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.bgPrimary,
                              ),
                            ),
                          )
                        : const Text('Continuar'),
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

// ── Role card ──────────────────────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool requiresVerification;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.requiresVerification = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.accentGold
                : AppColors.borderOverlay,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.accentGold.withValues(alpha: 0.15)
                    : AppColors.bgSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: selected
                    ? AppColors.accentGold
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.h3
                        .copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  if (requiresVerification) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'REQUIERE VERIFICACIÓN',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle,
                color: AppColors.accentGold,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
