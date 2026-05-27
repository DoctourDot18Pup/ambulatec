import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/data/auth_controller.dart';
import '../../auth/domain/vendor_verification_data.dart';

// ── Form state providers (autoDispose = scoped to this page) ──────────────

final _fullNameProvider = StateProvider.autoDispose<String>((ref) => '');
final _careerProvider = StateProvider.autoDispose<String>((ref) => '');
final _controlNumberProvider =
    StateProvider.autoDispose<String>((ref) => '');
final _frontImageProvider =
    StateProvider.autoDispose<XFile?>((ref) => null);
final _backImageProvider =
    StateProvider.autoDispose<XFile?>((ref) => null);
final _submittedProvider = StateProvider.autoDispose<bool>((ref) => false);
final _submittedAtProvider =
    StateProvider.autoDispose<DateTime?>((ref) => null);

final _formValidProvider = Provider.autoDispose<bool>((ref) {
  final fullName = ref.watch(_fullNameProvider);
  final career = ref.watch(_careerProvider);
  final controlNumber = ref.watch(_controlNumberProvider);
  final front = ref.watch(_frontImageProvider);
  final back = ref.watch(_backImageProvider);
  return fullName.trim().isNotEmpty &&
      career.trim().isNotEmpty &&
      controlNumber.trim().length == 8 &&
      front != null &&
      back != null;
});

// ── Date helper ───────────────────────────────────────────────────────────

String _formatDate(DateTime dt) {
  const months = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return 'Enviada · ${dt.day} ${months[dt.month - 1]}, $h:$m';
}

// ── Page ──────────────────────────────────────────────────────────────────

class VendorVerifyPage extends ConsumerWidget {
  const VendorVerifyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSubmitted = ref.watch(_submittedProvider);
    return isSubmitted ? const _PendingView() : const _FormView();
  }
}

// ── Form view ──────────────────────────────────────────────────────────────

class _FormView extends ConsumerWidget {
  const _FormView();

  Future<void> _pickImage(
    BuildContext context,
    WidgetRef ref,
    AutoDisposeStateProvider<XFile?> provider,
  ) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file != null) {
        ref.read(provider.notifier).state = file;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo seleccionar la imagen: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final fullName = ref.read(_fullNameProvider);
    final career = ref.read(_careerProvider);
    final controlNumber = ref.read(_controlNumberProvider);
    final front = ref.read(_frontImageProvider);
    final back = ref.read(_backImageProvider);

    if (front == null || back == null) return;

    final data = VendorVerificationData(
      fullName: fullName,
      career: career,
      controlNumber: controlNumber,
      idFrontPath: front.path,
      idBackPath: back.path,
    );

    await ref
        .read(authControllerProvider.notifier)
        .submitVendorVerification(data);

    if (!context.mounted) return;
    final authState = ref.read(authControllerProvider);
    authState.whenOrNull(
      error: (error, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      data: (_) {
        ref.read(_submittedAtProvider.notifier).state = DateTime.now();
        ref.read(_submittedProvider.notifier).state = true;
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isValid = ref.watch(_formValidProvider);
    final isLoading = ref.watch(authControllerProvider).isLoading;
    final frontImage = ref.watch(_frontImageProvider);
    final backImage = ref.watch(_backImageProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verificación',
              style:
                  AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
            ),
            Text(
              'Paso 1 de 2',
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info text
                  Text(
                    'Solo estudiantes activos pueden vender. '
                    'Tus datos no se publican.',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),

                  // ── Full name ───────────────────────────────────────
                  _buildLabel('NOMBRE COMPLETO'),
                  const SizedBox(height: 6),
                  TextFormField(
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textPrimary),
                    onChanged: (v) =>
                        ref.read(_fullNameProvider.notifier).state = v,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: ''),
                  ),
                  const SizedBox(height: 16),

                  // ── Career ──────────────────────────────────────────
                  _buildLabel('CARRERA'),
                  const SizedBox(height: 6),
                  TextFormField(
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textPrimary),
                    onChanged: (v) =>
                        ref.read(_careerProvider.notifier).state = v,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: ''),
                  ),
                  const SizedBox(height: 16),

                  // ── Control number ──────────────────────────────────
                  _buildLabel('NÚMERO DE CONTROL'),
                  const SizedBox(height: 6),
                  TextFormField(
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textPrimary),
                    onChanged: (v) =>
                        ref.read(_controlNumberProvider.notifier).state = v,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      helperText: '8 dígitos, como aparece en tu credencial.',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Image upload cards ──────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _ImageUploadCard(
                          label: 'Frente de credencial',
                          file: frontImage,
                          onTap: () => _pickImage(
                              context, ref, _frontImageProvider),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ImageUploadCard(
                          label: 'Reverso de credencial',
                          file: backImage,
                          onTap: () => _pickImage(
                              context, ref, _backImageProvider),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // ── Submit button ───────────────────────────────────
                  ElevatedButton(
                    onPressed: (isValid && !isLoading)
                        ? () => _submit(context, ref)
                        : null,
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
                        : const Text('Enviar para revisión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
    );
  }
}

// ── Image upload card ──────────────────────────────────────────────────────

class _ImageUploadCard extends StatelessWidget {
  final String label;
  final XFile? file;
  final VoidCallback onTap;

  const _ImageUploadCard({
    required this.label,
    required this.file,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasFile = file != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasFile ? AppColors.success : AppColors.borderOverlay,
            width: hasFile ? 1.5 : 1,
          ),
        ),
        child: hasFile
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: AppColors.success, size: 28),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      file!.name,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.success),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_outlined,
                      color: AppColors.textSecondary, size: 28),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      label,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Pending view ───────────────────────────────────────────────────────────

class _PendingView extends ConsumerWidget {
  const _PendingView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submittedAt =
        ref.watch(_submittedAtProvider) ?? DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        title: Text(
          'Verificación',
          style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // ── Clock icon ────────────────────────────────────
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.bgCard,
                      border: Border.all(
                          color: AppColors.accentGold, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.schedule,
                      size: 48,
                      color: AppColors.accentGold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── "En revisión" chip ────────────────────────────
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderOverlay),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.accentGold,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'En revisión',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Title ─────────────────────────────────────────
                  Text(
                    'Tu solicitud está en revisión',
                    style:
                        AppTextStyles.h2.copyWith(color: AppColors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // ── Subtitle ──────────────────────────────────────
                  Text(
                    'Te notificaremos cuando tu cuenta de vendedor sea aprobada. '
                    'Suele tardar menos de 24 horas.',
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // ── Timestamp ─────────────────────────────────────
                  Text(
                    _formatDate(submittedAt),
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),

                  const Spacer(flex: 3),

                  // ── Ghost button ──────────────────────────────────
                  OutlinedButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Ir al inicio como comprador'),
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
