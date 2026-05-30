import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

// ── Page state ────────────────────────────────────────────────────────────

final _onboardingPageIndexProvider =
    StateProvider.autoDispose<int>((ref) => 0);

// ── Slide data ────────────────────────────────────────────────────────────

class _Slide {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;

  const _Slide({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
  });
}

const _slides = [
  _Slide(
    icon: Icons.storefront_outlined,
    title: 'Encuentra lo que\nse vende hoy',
    subtitle:
        'Productos frescos de tus compañeros, listos para comer en el campus.',
    buttonLabel: 'Continuar',
  ),
  _Slide(
    icon: Icons.shield_outlined,
    title: 'Paga seguro, recibe\nen el campus',
    subtitle: 'Pago protegido y entrega directa en el punto que elijas.',
    buttonLabel: 'Continuar',
  ),
  _Slide(
    icon: Icons.sell_outlined,
    title: '¿Vendes algo?\nEmpieza hoy',
    subtitle:
        'Publica tu menú en minutos. Recibe pedidos sin salir del salón.',
    buttonLabel: 'Empezar',
  ),
];

// ── Widget ─────────────────────────────────────────────────────────────────

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  late final PageController _pageController;

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

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _finish() async {
    await ref.read(routerNotifierProvider).markOnboardingSeen();
    if (mounted) context.go('/login');
  }

  void _next(int currentIndex) {
    if (currentIndex < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(_onboardingPageIndexProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Stack(
          children: [
            // ── PageView ───────────────────────────────────────────────────
            PageView.builder(
              controller: _pageController,
              onPageChanged: (i) =>
                  ref.read(_onboardingPageIndexProvider.notifier).state = i,
              itemCount: _slides.length,
              itemBuilder: (context, index) =>
                  _SlidePage(slide: _slides[index]),
            ),

            // ── Bottom overlay (dots + button) ─────────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _DotsIndicator(
                          count: _slides.length,
                          current: currentIndex,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => _next(currentIndex),
                          child: Text(_slides[currentIndex].buttonLabel),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── "Omitir" button (top-right) ────────────────────────────────
            Positioned(
              top: 8,
              right: 16,
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  'Omitir',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Slide page ──────────────────────────────────────────────────────────────

class _SlidePage extends StatelessWidget {
  final _Slide slide;
  const _SlidePage({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 180),
      child: Column(
        children: [
          // Illustration placeholder
          Expanded(
            child: Center(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.borderOverlay),
                ),
                child: Icon(
                  slide.icon,
                  size: 80,
                  color: AppColors.accentGold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Title
          Text(
            slide.title,
            style: AppTextStyles.h1.copyWith(color: AppColors.textPrimary),
            textAlign: TextAlign.left,
          ),
          const SizedBox(height: 12),
          // Subtitle
          Text(
            slide.subtitle,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.left,
          ),
        ],
      ),
    );
  }
}

// ── Dots indicator ──────────────────────────────────────────────────────────

class _DotsIndicator extends StatelessWidget {
  final int count;
  final int current;
  const _DotsIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? AppColors.accentGold : AppColors.bgCard,
            borderRadius: BorderRadius.circular(4),
            border: isActive
                ? null
                : Border.all(color: AppColors.borderOverlay),
          ),
        );
      }),
    );
  }
}
