import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../orders/domain/order_model.dart';
import '../domain/message_model.dart';
import '../providers/chat_controller.dart';
import '../providers/chat_provider.dart';

// ── Page ───────────────────────────────────────────────────────────────────

class ChatPage extends ConsumerStatefulWidget {
  final String orderId;
  const ChatPage({super.key, required this.orderId});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  late final TextEditingController _msgCtrl;
  late final ScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    _msgCtrl = TextEditingController();
    _scrollCtrl = ScrollController();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients &&
          _scrollCtrl.position.maxScrollExtent > 0) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text;
    if (text.trim().isEmpty) return;
    _msgCtrl.clear();
    await ref
        .read(chatControllerProvider)
        .sendMessage(widget.orderId, text);
    _scrollToBottom();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final orderAsync = ref.watch(orderByIdProvider(widget.orderId));

    return orderAsync.when(
      loading: () => _blankScaffold(
        child: const Center(
            child: CircularProgressIndicator(
                color: AppColors.accentGold)),
      ),
      error: (e, _) => _blankScaffold(
        child: Center(
          child: Text('Error: $e',
              style: AppTextStyles.body
                  .copyWith(color: AppColors.error)),
        ),
      ),
      data: (order) {
        if (order == null) {
          return _blankScaffold(
            child: Center(
              child: Text('Orden no encontrada',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary)),
            ),
          );
        }

        final isVendor = order.vendorId == currentUid;
        final isClosed = order.status == OrderStatus.delivered ||
            order.status == OrderStatus.rejected ||
            order.status == OrderStatus.cancelled;
        final isExpired =
            order.chatExpiresAt.isBefore(DateTime.now());
        final canSend = !isClosed && !isExpired;

        // Scroll when new messages arrive
        ref.listen(chatMessagesProvider(widget.orderId), (_, _) {
          _scrollToBottom();
        });

        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          appBar: _buildAppBar(order, isVendor),
          body: Column(
            children: [
              // ── Status strip ─────────────────────────────────────
              _StatusStrip(order: order),

              // ── Expiry countdown (only while chat is active) ─────
              if (!isClosed)
                _ExpiryBar(expiresAt: order.chatExpiresAt),

              // ── Messages ─────────────────────────────────────────
              Expanded(
                child: _MessageList(
                  orderId: widget.orderId,
                  currentUid: currentUid,
                  scrollController: _scrollCtrl,
                ),
              ),

              // ── Vendor: mark delivered ───────────────────────────
              if (isVendor && order.status == OrderStatus.confirmed)
                _DeliverButton(order: order),

              // ── Input or closed notice ───────────────────────────
              if (canSend)
                _InputBar(controller: _msgCtrl, onSend: _send)
              else
                _ClosedBar(reason: _closedReason(order, isExpired)),
            ],
          ),
        );
      },
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  AppBar _buildAppBar(OrderModel order, bool isVendor) {
    final other =
        isVendor ? order.buyerName : 'Vendedor';
    return AppBar(
      backgroundColor: AppColors.bgSurface,
      elevation: 0,
      leading: BackButton(
        color: AppColors.textPrimary,
        onPressed: () => context.go('/home'),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.postTitle,
            style:
                AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            other,
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _blankScaffold({required Widget child}) => Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          backgroundColor: AppColors.bgSurface,
          title: Text('Chat',
              style: AppTextStyles.h3
                  .copyWith(color: AppColors.textPrimary)),
          leading: BackButton(
            color: AppColors.textPrimary,
            onPressed: () => context.go('/home'),
          ),
        ),
        body: child,
      );

  String _closedReason(OrderModel order, bool isExpired) {
    if (isExpired) return 'Chat expirado (24 h)';
    switch (order.status) {
      case OrderStatus.delivered:
        return '¡Pedido entregado! Gracias por usar AmbulaTec 🎉';
      case OrderStatus.rejected:
        return 'Pedido rechazado por el vendedor.';
      case OrderStatus.cancelled:
        return 'Pedido cancelado.';
      default:
        return 'Chat cerrado.';
    }
  }
}

// ── Status strip ───────────────────────────────────────────────────────────

class _StatusStrip extends StatelessWidget {
  final OrderModel order;
  const _StatusStrip({required this.order});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _badge(order.status);
    return Container(
      width: double.infinity,
      color: AppColors.bgSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('ORDEN #AT-${order.id.substring(0, 6).toUpperCase()}',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary)),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Text(label,
                style: AppTextStyles.caption
                    .copyWith(color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  (String, Color) _badge(OrderStatus s) => switch (s) {
        OrderStatus.pending => ('En espera', AppColors.accentGold),
        OrderStatus.confirmed => ('Confirmado', AppColors.success),
        OrderStatus.delivered => ('Entregado', AppColors.success),
        OrderStatus.rejected => ('Rechazado', AppColors.error),
        OrderStatus.cancelled => ('Cancelado', AppColors.error),
      };
}

// ── Expiry countdown bar ───────────────────────────────────────────────────

class _ExpiryBar extends ConsumerWidget {
  final DateTime expiresAt;
  const _ExpiryBar({required this.expiresAt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countdownAsync = ref.watch(countdownProvider(expiresAt));
    final remaining = countdownAsync.asData?.value;

    if (remaining == null) return const SizedBox.shrink();
    if (remaining == Duration.zero) {
      return _bar('Chat expirado', AppColors.error);
    }

    final h = remaining.inHours;
    final m = remaining.inMinutes.remainder(60);
    final s = remaining.inSeconds.remainder(60);
    final label = h > 0
        ? 'Chat disponible ${h}h ${m.toString().padLeft(2, '0')}m'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')} para que expire el chat';

    final color = remaining.inMinutes < 30
        ? AppColors.error
        : AppColors.textSecondary;

    return _bar(label, color);
  }

  Widget _bar(String text, Color color) => Container(
        width: double.infinity,
        color: AppColors.bgSurface,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timer_outlined, size: 13, color: color),
            const SizedBox(width: 6),
            Text(text,
                style:
                    AppTextStyles.caption.copyWith(color: color)),
          ],
        ),
      );
}

// ── Messages list ──────────────────────────────────────────────────────────

class _MessageList extends ConsumerWidget {
  final String orderId;
  final String currentUid;
  final ScrollController scrollController;

  const _MessageList({
    required this.orderId,
    required this.currentUid,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final msgsAsync = ref.watch(chatMessagesProvider(orderId));

    return msgsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accentGold)),
      error: (e, _) => Center(
          child: Text('Error al cargar mensajes',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary))),
      data: (msgs) {
        if (msgs.isEmpty) {
          return Center(
            child: Text(
              'Aún no hay mensajes.\n¡Envía el primero!',
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          );
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          itemCount: msgs.length,
          itemBuilder: (_, i) {
            final msg = msgs[i];
            if (msg.isSystem) return _SystemMessage(msg: msg);
            final isMine = msg.senderId == currentUid;
            return _ChatBubble(msg: msg, isMine: isMine);
          },
        );
      },
    );
  }
}

// ── Chat bubble ────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final MessageModel msg;
  final bool isMine;
  const _ChatBubble({required this.msg, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        margin: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // Sender name (only for other party)
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (msg.senderPhotoUrl != null &&
                        msg.senderPhotoUrl!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: CircleAvatar(
                          radius: 10,
                          backgroundImage: CachedNetworkImageProvider(
                              msg.senderPhotoUrl!),
                        ),
                      ),
                    Text(msg.senderName,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),

            // Bubble
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMine
                    ? AppColors.accentGreen
                    : AppColors.bgCard,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft:
                      Radius.circular(isMine ? 16 : 4),
                  bottomRight:
                      Radius.circular(isMine ? 4 : 16),
                ),
                border: isMine
                    ? null
                    : Border.all(color: AppColors.borderOverlay),
              ),
              child: Text(
                msg.text,
                style: AppTextStyles.body.copyWith(
                  color: isMine
                      ? Colors.white
                      : AppColors.textPrimary,
                ),
              ),
            ),

            // Timestamp
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
              child: Text(
                _fmt(msg.createdAt),
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── System message ─────────────────────────────────────────────────────────

class _SystemMessage extends StatelessWidget {
  final MessageModel msg;
  const _SystemMessage({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderOverlay),
          ),
          child: Text(
            msg.text,
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

// ── Deliver button ─────────────────────────────────────────────────────────

class _DeliverButton extends ConsumerWidget {
  final OrderModel order;
  const _DeliverButton({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: AppColors.bgSurface,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Marcar como entregado'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            final ok = await _confirm(context);
            if (ok && context.mounted) {
              await ref
                  .read(chatControllerProvider)
                  .markDelivered(order);
            }
          },
        ),
      ),
    );
  }

  Future<bool> _confirm(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text('¿Confirmar entrega?',
            style: AppTextStyles.h3
                .copyWith(color: AppColors.textPrimary)),
        content: Text(
          'Esto marcará el pedido como entregado y cerrará el chat.',
          style:
              AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// ── Input bar ──────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  const _InputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgSurface,
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        10 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textPrimary),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Escribe un mensaje…',
                hintStyle: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.bgCard,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.accentGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Closed notice ──────────────────────────────────────────────────────────

class _ClosedBar extends StatelessWidget {
  final String reason;
  const _ClosedBar({required this.reason});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.bgSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(
        reason,
        style:
            AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        textAlign: TextAlign.center,
      ),
    );
  }
}
