import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// A compact chip that counts down to [expiresAt], updating every second.
///
/// Uses [StreamBuilder] over [Stream.periodic] — no `setState` required.
///
/// Colour transitions:
/// * > 60 s remaining → [AppColors.accentGold]
/// * ≤ 60 s remaining → [AppColors.error]
/// * Expired          → [AppColors.error] + label "Expirado"
///
/// Usage:
/// ```dart
/// CountdownChipWidget(expiresAt: post.offerExpiresAt!)
/// ```
class CountdownChipWidget extends StatelessWidget {
  final DateTime expiresAt;

  const CountdownChipWidget({super.key, required this.expiresAt});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: Stream.periodic(
        const Duration(seconds: 1),
        (_) {
          final d = expiresAt.difference(DateTime.now());
          return d.isNegative ? Duration.zero : d;
        },
      ),
      builder: (_, snap) {
        final remaining = snap.data ??
            (expiresAt.difference(DateTime.now()).isNegative
                ? Duration.zero
                : expiresAt.difference(DateTime.now()));

        final expired = remaining == Duration.zero;
        final urgent = remaining.inSeconds <= 60 && !expired;
        final color =
            (expired || urgent) ? AppColors.error : AppColors.accentGold;

        final label = expired
            ? 'Expirado'
            : remaining.inHours >= 1
                ? 'Termina en ${remaining.inHours}:'
                    '${(remaining.inMinutes.remainder(60)).toString().padLeft(2, '0')}:'
                    '${(remaining.inSeconds.remainder(60)).toString().padLeft(2, '0')}'
                : 'Termina en '
                    '${remaining.inMinutes.toString().padLeft(2, '0')}:'
                    '${(remaining.inSeconds.remainder(60)).toString().padLeft(2, '0')}';

        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_outlined, size: 12, color: color),
              const SizedBox(width: 5),
              Text(label,
                  style: AppTextStyles.caption
                      .copyWith(color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        );
      },
    );
  }
}
