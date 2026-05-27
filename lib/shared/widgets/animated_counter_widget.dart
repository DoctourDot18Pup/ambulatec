import 'package:flutter/material.dart';

/// Animates smoothly from its previous value to [value] whenever [value]
/// changes, using a [TweenAnimationBuilder].
///
/// Usage:
/// ```dart
/// AnimatedCounterWidget(
///   value: earnings,
///   formatter: (v) => '\$${v.toStringAsFixed(2)}',
///   style: AppTextStyles.h1.copyWith(color: AppColors.accentGold),
/// )
/// ```
class AnimatedCounterWidget extends StatelessWidget {
  /// The target numeric value.
  final double value;

  /// Converts the animated value to the display string.
  final String Function(double) formatter;

  /// Text style applied to the output.
  final TextStyle? style;

  /// How long the animation takes. Defaults to 800 ms.
  final Duration duration;

  /// Animation curve. Defaults to [Curves.easeOutCubic].
  final Curve curve;

  const AnimatedCounterWidget({
    super.key,
    required this.value,
    required this.formatter,
    this.style,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: curve,
      builder: (_, animated, _) {
        return Text(formatter(animated), style: style);
      },
    );
  }
}
