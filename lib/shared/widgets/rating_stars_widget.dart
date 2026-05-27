import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Displays a 5-star rating widget in two modes:
///
/// **Display mode** (`onRatingChanged == null`):
///   Shows a read-only row of stars that supports decimal values.
///   4.7 → 4 full stars, 1 half star. Built with `Icons.star_half` at 0.3+.
///
/// **Selection mode** (`onRatingChanged != null`):
///   Shows tappable stars; calls [onRatingChanged] with the new 1-5 value.
///   Optionally animates the selected star with [AnimatedScale].
///
/// Usage:
/// ```dart
/// // Display
/// RatingStarsWidget(rating: vendor.vendorRating, size: 14)
///
/// // Selection
/// RatingStarsWidget(
///   rating: selectedRating.toDouble(),
///   onRatingChanged: (v) => ref.read(_ratingProvider.notifier).state = v,
/// )
/// ```
class RatingStarsWidget extends StatelessWidget {
  /// Current rating value (0–5). Supports decimals in display mode.
  final double rating;

  /// Called with the tapped index (1–5) in selection mode.
  /// If `null`, the widget is read-only.
  final void Function(int)? onRatingChanged;

  /// Diameter of each star icon. Defaults to 16.
  final double size;

  /// Filled star colour. Defaults to [AppColors.accentGold].
  final Color? filledColor;

  /// Empty star colour. Defaults to [AppColors.textSecondary].
  final Color? emptyColor;

  const RatingStarsWidget({
    super.key,
    required this.rating,
    this.onRatingChanged,
    this.size = 16,
    this.filledColor,
    this.emptyColor,
  });

  @override
  Widget build(BuildContext context) {
    final filled = filledColor ?? AppColors.accentGold;
    final empty = emptyColor ?? AppColors.textSecondary;
    final isSelectable = onRatingChanged != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starIndex = i + 1;

        // ── Icon choice ──────────────────────────────────────────────────────
        IconData icon;
        Color color;

        if (isSelectable) {
          // Selection mode: full or empty only
          icon = i < rating.round()
              ? Icons.star_rounded
              : Icons.star_outline_rounded;
          color = i < rating.round() ? filled : empty;
        } else {
          // Display mode: full / half / empty based on decimal value
          if (rating >= starIndex) {
            icon = Icons.star_rounded;
            color = filled;
          } else if (rating >= starIndex - 0.7) {
            icon = Icons.star_half_rounded;
            color = filled;
          } else {
            icon = Icons.star_outline_rounded;
            color = empty;
          }
        }

        // ── Widget ───────────────────────────────────────────────────────────
        final star = Icon(icon, size: size, color: color);

        if (!isSelectable) return star;

        return GestureDetector(
          onTap: () => onRatingChanged!(starIndex),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: size * 0.1),
            child: AnimatedScale(
              scale: i < rating.round() ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: star,
            ),
          ),
        );
      }),
    );
  }
}
