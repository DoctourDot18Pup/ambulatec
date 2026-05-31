import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/services/google_web_button.dart' as web_button;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/auth_controller.dart';
import '../data/auth_provider.dart';
import '../data/user_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSub;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _authSub = GoogleSignIn.instance.authenticationEvents.listen(
        (event) {
          if (event is GoogleSignInAuthenticationEventSignIn) {
            ref
                .read(authControllerProvider.notifier)
                .signInFromAccount(event.user);
          }
        },
        onError: (Object e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e.toString()),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

    final controllerLoading = ref.watch(authControllerProvider).isLoading;
    final firebaseUser = ref.watch(authStateProvider).asData?.value;
    ref.watch(userProvider); // keep provider alive; router reacts to its changes

    // Show spinner whenever:
    // • The sign-in operation is in progress (controllerLoading), OR
    // • Firebase has a user but Firestore hasn't resolved yet (isLoading), OR
    // • Firebase has a user but Firestore responded with null (network error or
    //   missing document) — in this case the router will redirect to /role-select
    //   once it re-evaluates; show spinner instead of the Google button to avoid
    //   a confusing flash of the sign-in screen.
    final isLoading = controllerLoading || firebaseUser != null;

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

                  // ── Sign-in button ──────────────────────────────────────
                  if (isLoading)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.accentGold),
                      ),
                    )
                  else if (kIsWeb)
                    // Web: Google renders its own button; auth events handled
                    // via the stream subscription in initState.
                    web_button.renderButton()
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.bgPrimary,
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () => ref
                            .read(authControllerProvider.notifier)
                            .signInWithGoogle(),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
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
