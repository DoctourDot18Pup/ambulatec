import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/auth_controller.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final isLoading =
        ref.watch(authControllerProvider).isLoading;

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
                  const Spacer(flex: 3),

                  // ── Logo ────────────────────────────────────────────────
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderOverlay),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'A',
                      style: AppTextStyles.h1
                          .copyWith(color: AppColors.accentGold),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Brand name ──────────────────────────────────────────
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Ambula',
                          style: AppTextStyles.h1
                              .copyWith(color: AppColors.textPrimary),
                        ),
                        TextSpan(
                          text: 'Tec',
                          style: AppTextStyles.h1
                              .copyWith(color: AppColors.accentGold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Tagline ─────────────────────────────────────────────
                  Text(
                    'Tu mercado en el campus.',
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Solo para estudiantes de TecNM Celaya.',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),

                  const Spacer(flex: 4),

                  // ── Google sign-in button ───────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.bgPrimary,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: isLoading
                          ? null
                          : () => ref
                              .read(authControllerProvider.notifier)
                              .signInWithGoogle(),
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.accentGold,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Google logo placeholder
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF4285F4),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'G',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Inicia sesión con Google',
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.bgPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Legal text ──────────────────────────────────────────
                  Text(
                    'Al continuar, aceptas los Términos y la Política de Privacidad',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
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
