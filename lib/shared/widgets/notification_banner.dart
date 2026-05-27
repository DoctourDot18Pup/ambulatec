import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

// ── Controller ─────────────────────────────────────────────────────────────

/// Shows and dismisses in-app notification banners via an [OverlayEntry].
///
/// Only one banner is visible at a time; calling [show] while a banner is
/// visible replaces it.
class NotificationBannerController {
  static OverlayEntry? _current;

  /// Shows a slide-from-top banner in the nearest [Overlay].
  ///
  /// [onTap] is called when the user taps the banner body.
  /// The banner auto-dismisses after [duration] (default 5 s).
  static void show({
    required BuildContext context,
    required String title,
    required String body,
    required VoidCallback onTap,
    Duration duration = const Duration(seconds: 5),
  }) {
    _current?.remove();
    _current = null;

    final entry = OverlayEntry(
      builder: (_) => _NotificationBannerWidget(
        title: title,
        body: body,
        onTap: onTap,
        onDismiss: dismiss,
        duration: duration,
      ),
    );

    _current = entry;
    Overlay.of(context).insert(entry);
  }

  /// Programmatically removes the current banner (if any).
  static void dismiss() {
    _current?.remove();
    _current = null;
  }
}

// ── Banner widget ──────────────────────────────────────────────────────────

class _NotificationBannerWidget extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final Duration duration;

  const _NotificationBannerWidget({
    required this.title,
    required this.body,
    required this.onTap,
    required this.onDismiss,
    required this.duration,
  });

  @override
  State<_NotificationBannerWidget> createState() =>
      _NotificationBannerWidgetState();
}

class _NotificationBannerWidgetState extends State<_NotificationBannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slideAnim;
  Timer? _autoHide;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _ctrl.forward();

    _autoHide = Timer(widget.duration, _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _autoHide?.cancel();
    _ctrl.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _autoHide?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;

    return Positioned(
      top: safeTop + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnim,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _dismiss();
              widget.onTap();
            },
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.accentGold.withValues(alpha: 0.35)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 20,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // ── Icon ──────────────────────────────────────────────
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.accentGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_active_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // ── Text ──────────────────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.body,
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // ── Dismiss ───────────────────────────────────────────
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 18, color: AppColors.textSecondary),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    onPressed: _dismiss,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
