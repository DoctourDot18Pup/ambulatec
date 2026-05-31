import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/profile_provider.dart';

// ── Topic catalogue ────────────────────────────────────────────────────────

class _Topic {
  final IconData icon;
  final String label;
  final List<String> options;
  const _Topic({
    required this.icon,
    required this.label,
    this.options = const [],
  });
}

const _kTopics = [
  _Topic(
    icon: Icons.bug_report_outlined,
    label: 'Reportar un problema',
    options: [
      'No puedo cerrar sesión',
      'No puedo enviar mensajes',
      'No puedo realizar un pedido',
      'Mi pago no se procesó',
      'La app no carga o se cierra',
      'Otro problema técnico',
    ],
  ),
  _Topic(
    icon: Icons.manage_accounts_outlined,
    label: 'Problemas con mi cuenta',
    options: [
      'No puedo actualizar mi perfil',
      'Problemas con verificación de vendedor',
      'No recibo notificaciones',
      'Quiero eliminar mi cuenta',
      'Otro',
    ],
  ),
  _Topic(
    icon: Icons.flag_outlined,
    label: 'Reportar a un usuario',
    options: [
      'Comportamiento inapropiado',
      'El vendedor no entregó el producto',
      'Cobro incorrecto',
      'Información falsa en la publicación',
      'Otro',
    ],
  ),
  _Topic(
    icon: Icons.lightbulb_outline,
    label: 'Sugerencia de mejora',
    options: [],
  ),
  _Topic(
    icon: Icons.help_outline,
    label: 'Otro',
    options: [],
  ),
];

// ── Steps ──────────────────────────────────────────────────────────────────

enum _Step { topic, option, details, success }

// ── Sheet root ─────────────────────────────────────────────────────────────

class SupportSheet extends ConsumerStatefulWidget {
  /// Optional order context. When opened from a chat/order, the report is
  /// linked to this order and the flow starts pre-focused on user/order issues.
  final String? orderId;
  final String? reportedUserId;
  final String? reportedUserName;

  const SupportSheet({
    super.key,
    this.orderId,
    this.reportedUserId,
    this.reportedUserName,
  });

  @override
  ConsumerState<SupportSheet> createState() => _SupportSheetState();
}

class _SupportSheetState extends ConsumerState<SupportSheet> {
  _Step _step = _Step.topic;
  _Topic? _topic;
  String? _option;
  final _detailsCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  void _onTopicSelected(_Topic t) => setState(() {
        _topic = t;
        _option = null;
        _step = t.options.isEmpty ? _Step.details : _Step.option;
      });

  void _onOptionSelected(String o) => setState(() {
        _option = o;
        _step = _Step.details;
      });

  void _back() => setState(() {
        if (_step == _Step.details && (_topic?.options.isNotEmpty ?? false)) {
          _step = _Step.option;
          _option = null;
        } else {
          _step = _Step.topic;
          _topic = null;
          _option = null;
        }
      });

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final user = ref.read(userProvider).asData?.value;
      await FirebaseFirestore.instance
          .collection(AppConstants.supportCollection)
          .add({
        'userId': user?.uid ?? '',
        'userEmail': user?.email ?? '',
        'userName': user?.displayName ?? '',
        'topic': _topic?.label ?? '',
        'option': _option ?? '',
        'details': _detailsCtrl.text.trim(),
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
        // Order context (present only when opened from a chat/order).
        if (widget.orderId != null) 'orderId': widget.orderId,
        if (widget.reportedUserId != null)
          'reportedUserId': widget.reportedUserId,
        if (widget.reportedUserName != null)
          'reportedUserName': widget.reportedUserName,
      });
      if (mounted) setState(() => _step = _Step.success);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al enviar: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _buildCurrentStep(),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case _Step.topic:
        return _TopicStep(
          key: const ValueKey('topic'),
          onSelect: _onTopicSelected,
          contextNote: widget.orderId != null
              ? 'Reporte vinculado a tu pedido'
                  '${widget.reportedUserName != null ? ' con ${widget.reportedUserName}' : ''}.'
              : null,
        );
      case _Step.option:
        return _OptionStep(
          key: const ValueKey('option'),
          topic: _topic!,
          onSelect: _onOptionSelected,
          onBack: _back,
        );
      case _Step.details:
        return _DetailsStep(
          key: const ValueKey('details'),
          topic: _topic!,
          option: _option,
          controller: _detailsCtrl,
          submitting: _submitting,
          onBack: _back,
          onSubmit: _submit,
        );
      case _Step.success:
        return _SuccessStep(
          key: const ValueKey('success'),
          onClose: () => Navigator.of(context).pop(),
        );
    }
  }
}

// ── Step 1 — Topic selection ───────────────────────────────────────────────

class _TopicStep extends StatelessWidget {
  final ValueChanged<_Topic> onSelect;
  final String? contextNote;
  const _TopicStep({super.key, required this.onSelect, this.contextNote});

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Ayuda y soporte',
      subtitle: '¿En qué podemos ayudarte?',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (contextNote != null) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accentGold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.accentGold.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, size: 16, color: AppColors.accentGold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(contextNote!,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.accentGold)),
                  ),
                ],
              ),
            ),
          ],
          ..._kTopics.map((t) => _SelectTile(
                icon: t.icon,
                label: t.label,
                onTap: () => onSelect(t),
              )),
        ],
      ),
    );
  }
}

// ── Step 2 — Option selection ──────────────────────────────────────────────

class _OptionStep extends StatelessWidget {
  final _Topic topic;
  final ValueChanged<String> onSelect;
  final VoidCallback onBack;
  const _OptionStep({
    super.key,
    required this.topic,
    required this.onSelect,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: topic.label,
      subtitle: '¿Cuál es el problema específico?',
      onBack: onBack,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: topic.options
            .map((o) => _SelectTile(
                  label: o,
                  onTap: () => onSelect(o),
                ))
            .toList(),
      ),
    );
  }
}

// ── Step 3 — Details + submit ──────────────────────────────────────────────

class _DetailsStep extends StatelessWidget {
  final _Topic topic;
  final String? option;
  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  const _DetailsStep({
    super.key,
    required this.topic,
    required this.option,
    required this.controller,
    required this.submitting,
    required this.onBack,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Cuéntanos más',
      onBack: onBack,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Selected context tags ──────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Tag(label: topic.label, color: AppColors.accentGold),
              if (option != null) _Tag(label: option!),
            ],
          ),
          const SizedBox(height: 20),

          // ── Details field ──────────────────────────────────────────
          TextFormField(
            controller: controller,
            enabled: !submitting,
            maxLines: 4,
            maxLength: 500,
            style:
                AppTextStyles.body.copyWith(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Describe el problema con el mayor detalle posible (opcional)…',
              counterStyle: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 24),

          // ── Submit ─────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: submitting ? null : onSubmit,
              child: submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.bgPrimary),
                      ),
                    )
                  : const Text('Enviar reporte'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 4 — Success ───────────────────────────────────────────────────────

class _SuccessStep extends StatelessWidget {
  final VoidCallback onClose;
  const _SuccessStep({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: '',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.accentGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                color: Colors.white, size: 36),
          ),
          const SizedBox(height: 20),
          Text(
            '¡Mensaje enviado!',
            style: AppTextStyles.h2.copyWith(color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Recibimos tu reporte. Un administrador\nlo revisará pronto.',
            style:
                AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onClose,
              child: const Text('Cerrar'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Shared layout scaffold ─────────────────────────────────────────────────

class _SheetScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget child;

  const _SheetScaffold({
    required this.title,
    this.subtitle,
    this.onBack,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.borderOverlay,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title row
          Row(
            children: [
              if (onBack != null) ...[
                GestureDetector(
                  onTap: onBack,
                  child: const Icon(Icons.arrow_back_ios_new,
                      size: 18, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 10),
              ],
              if (title.isNotEmpty)
                Expanded(
                  child: Text(title,
                      style: AppTextStyles.h3
                          .copyWith(color: AppColors.textPrimary)),
                ),
            ],
          ),

          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(left: onBack != null ? 28 : 0),
              child: Text(subtitle!,
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary)),
            ),
          ],

          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

// ── Selectable tile ────────────────────────────────────────────────────────

class _SelectTile extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback onTap;

  const _SelectTile({
    required this.label,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderOverlay),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: AppColors.accentGold),
              const SizedBox(width: 12),
            ] else ...[
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 12, left: 2),
                decoration: const BoxDecoration(
                  color: AppColors.textSecondary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
            Expanded(
              child: Text(label,
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textPrimary)),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Context tag chip ───────────────────────────────────────────────────────

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, this.color = AppColors.textSecondary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style:
              AppTextStyles.caption.copyWith(color: color, fontSize: 11)),
    );
  }
}
