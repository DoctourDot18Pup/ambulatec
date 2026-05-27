import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Animated status indicator dot.
///
/// * `'active'`  → green dot that pulses continuously (opacity loop).
/// * `'busy'`    → gold dot, static.
/// * `'offline'` → grey dot, static.
///
/// Uses [AnimationController] with `repeat(reverse: true)` and
/// [AnimatedBuilder] — no `setState` required.
///
/// Usage:
/// ```dart
/// StatusDotWidget(status: vendor.vendorAvailability, size: 10)
/// ```
class StatusDotWidget extends StatefulWidget {
  /// One of `'active'`, `'busy'`, or `'offline'`.
  final String status;

  /// Diameter in logical pixels. Defaults to 8.
  final double size;

  const StatusDotWidget({
    super.key,
    required this.status,
    this.size = 8,
  });

  @override
  State<StatusDotWidget> createState() => _StatusDotWidgetState();
}

class _StatusDotWidgetState extends State<StatusDotWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.status == 'active') {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(StatusDotWidget old) {
    super.didUpdateWidget(old);
    if (widget.status == 'active' && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (widget.status != 'active' && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(widget.status);

    if (widget.status != 'active') {
      return _dot(color, 1.0);
    }

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => _dot(color, 0.35 + _ctrl.value * 0.65),
    );
  }

  Widget _dot(Color color, double opacity) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: opacity),
          shape: BoxShape.circle,
        ),
      );

  Color _colorFor(String status) => switch (status) {
        'active' => AppColors.success,
        'busy' => AppColors.accentGold,
        _ => AppColors.textSecondary,
      };
}
