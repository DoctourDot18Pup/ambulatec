import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../orders/providers/pending_notifications_provider.dart';
import '../providers/notification_history_provider.dart';
import '../providers/notification_preferences_provider.dart';

class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(notificationPreferencesProvider);
    final historyAsync = ref.watch(notificationHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        leading: BackButton(color: AppColors.textPrimary),
        title: Text('Notificaciones',
            style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
        actions: [
          // Mark all read
          if (historyAsync.asData?.value.any((n) => n.isUnread) == true)
            TextButton(
              onPressed: () => _markAllRead(historyAsync.asData!.value),
              child: Text('Marcar todo',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.accentGold)),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              // ── Toggle ──────────────────────────────────────────────
              _Section(
                title: 'PREFERENCIAS',
                child: _ToggleTile(
                  enabled: enabled,
                  onChanged: (v) => ref
                      .read(notificationPreferencesProvider.notifier)
                      .setEnabled(v),
                ),
              ),
              const SizedBox(height: 28),

              // ── History ─────────────────────────────────────────────
              _Section(
                title: 'HISTORIAL',
                child: historyAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accentGold),
                    ),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error al cargar: $e',
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.error)),
                  ),
                  data: (items) => items.isEmpty
                      ? const _EmptyHistory()
                      : Column(
                          children: items
                              .map((n) => _NotificationTile(
                                    notification: n,
                                    onTap: () =>
                                        _openNotification(context, n),
                                  ))
                              .toList(),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openNotification(BuildContext context, AppNotification n) {
    if (n.isUnread) markNotificationRead(n.id);
    final String route;
    if (n.type == 'order_delivered') {
      route = '/review/${n.orderId}';
    } else if (n.type == 'new_order') {
      route = '/order-alert/${n.orderId}';
    } else {
      route = '/chat/${n.orderId}';
    }
    context.push(route);
  }

  Future<void> _markAllRead(List<AppNotification> notifications) async {
    for (final n in notifications.where((n) => n.isUnread)) {
      await markNotificationRead(n.id);
    }
  }
}

// ── Section wrapper ────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderOverlay),
          ),
          child: child,
        ),
      ],
    );
  }
}

// ── Toggle tile ────────────────────────────────────────────────────────────

class _ToggleTile extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;
  const _ToggleTile({required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        'Notificaciones en la app',
        style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
      ),
      subtitle: Text(
        enabled
            ? 'Recibirás alertas de nuevos pedidos y entregas.'
            : 'Los avisos de pedidos no se mostrarán.',
        style:
            AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
      ),
      value: enabled,
      activeThumbColor: AppColors.accentGold,
      activeTrackColor: AppColors.accentGold.withValues(alpha: 0.4),
      onChanged: onChanged,
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          Icon(Icons.notifications_none_outlined,
              size: 40, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            'Sin notificaciones aún',
            style:
                AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Notification tile ──────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  const _NotificationTile(
      {required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final isDelivered = n.type == 'order_delivered';

    final title = isDelivered ? '¡Tu pedido llegó!' : 'Nuevo pedido';
    final body = isDelivered
        ? 'Califica tu experiencia con ${n.productTitle}'
        : '${n.buyerName} quiere: ${n.productTitle}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Icon ────────────────────────────────────────────────
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: (isDelivered ? AppColors.accentGold : AppColors.accentGreen)
                    .withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDelivered
                    ? Icons.check_circle_outline
                    : Icons.shopping_bag_outlined,
                size: 18,
                color: isDelivered
                    ? AppColors.accentGold
                    : AppColors.accentGreen,
              ),
            ),
            const SizedBox(width: 12),

            // ── Text ────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: n.isUnread
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(n.createdAt),
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // ── Unread dot ──────────────────────────────────────────
            if (n.isUnread)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.accentGold,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'ayer';
    if (diff.inDays < 7) return 'hace ${diff.inDays} días';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
