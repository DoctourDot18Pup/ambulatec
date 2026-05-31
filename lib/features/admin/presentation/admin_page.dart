import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/domain/user_model.dart';
import '../providers/pending_vendors_provider.dart';
import '../providers/support_reports_provider.dart';

// ── Page ───────────────────────────────────────────────────────────────────

class AdminPage extends ConsumerWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCount =
        ref.watch(pendingVendorsProvider).asData?.value.length ?? 0;
    final openReports = ref
            .watch(supportReportsProvider)
            .asData
            ?.value
            .where((r) => r.isOpen)
            .length ??
        0;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          backgroundColor: AppColors.bgSurface,
          elevation: 0,
          leading: BackButton(
            color: AppColors.textPrimary,
            onPressed: () => context.go('/profile'),
          ),
          title: Text('Panel de administrador',
              style:
                  AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
          bottom: TabBar(
            indicatorColor: AppColors.accentGold,
            labelColor: AppColors.accentGold,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: AppTextStyles.body,
            tabs: [
              Tab(text: 'Vendedores${pendingCount > 0 ? ' ($pendingCount)' : ''}'),
              Tab(text: 'Reportes${openReports > 0 ? ' ($openReports)' : ''}'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _VendorsTab(),
            _ReportsTab(),
          ],
        ),
      ),
    );
  }
}

// ── Vendors tab ────────────────────────────────────────────────────────────

class _VendorsTab extends ConsumerWidget {
  const _VendorsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingVendorsProvider);

    return pendingAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accentGold)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Error al cargar solicitudes: $e',
            style: AppTextStyles.body.copyWith(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (vendors) {
        if (vendors.isEmpty) {
          return const _EmptyState(
            icon: Icons.check_circle_outline,
            label: 'No hay solicitudes pendientes',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: vendors.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _VendorCard(vendor: vendors[i]),
        );
      },
    );
  }
}

// ── Reports tab ────────────────────────────────────────────────────────────

class _ReportsTab extends ConsumerWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(supportReportsProvider);

    return reportsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accentGold)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error al cargar reportes: $e',
              style: AppTextStyles.body.copyWith(color: AppColors.error),
              textAlign: TextAlign.center),
        ),
      ),
      data: (reports) {
        if (reports.isEmpty) {
          return const _EmptyState(
            icon: Icons.inbox_outlined,
            label: 'Sin reportes de usuarios',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _ReportCard(report: reports[i]),
        );
      },
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptyState({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: AppColors.success),
          const SizedBox(height: 16),
          Text(
            label,
            style: AppTextStyles.h3
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Report card ────────────────────────────────────────────────────────────

class _ReportCard extends ConsumerWidget {
  final SupportReport report;
  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = !report.isOpen;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: resolved
              ? AppColors.borderOverlay
              : AppColors.accentGold.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Topic + status ────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(report.topic,
                    style: AppTextStyles.body.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (resolved ? AppColors.success : AppColors.accentGold)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  resolved ? 'Resuelto' : 'Abierto',
                  style: AppTextStyles.caption.copyWith(
                    color:
                        resolved ? AppColors.success : AppColors.accentGold,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (report.option.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(report.option,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
          ],

          // ── Details ───────────────────────────────────────────────
          if (report.details.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(report.details,
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textPrimary)),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.borderOverlay),
          const SizedBox(height: 10),

          // ── Reporter ──────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  report.userName.isNotEmpty
                      ? '${report.userName} · ${report.userEmail}'
                      : report.userEmail,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // ── Order context (chat reports) ──────────────────────────
          if (report.orderId != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.receipt_long_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Pedido #AT-${report.orderId!.substring(0, report.orderId!.length >= 6 ? 6 : report.orderId!.length).toUpperCase()}'
                    '${report.reportedUserName != null ? ' · sobre ${report.reportedUserName}' : ''}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          if (report.createdAt != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.schedule_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(_fmtDateTime(report.createdAt!),
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // ── Toggle status ─────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: Icon(
                  resolved ? Icons.refresh : Icons.check, size: 16),
              label: Text(
                  resolved ? 'Reabrir' : 'Marcar como resuelto'),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    resolved ? AppColors.textSecondary : AppColors.success,
                side: BorderSide(
                    color: resolved
                        ? AppColors.borderOverlay
                        : AppColors.success.withValues(alpha: 0.6)),
              ),
              onPressed: () => setReportStatus(
                  report.id, resolved ? 'open' : 'resolved'),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDateTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} $h:$m';
  }
}

// ── Vendor card ────────────────────────────────────────────────────────────

class _VendorCard extends ConsumerWidget {
  final UserModel vendor;
  const _VendorCard({required this.vendor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verification = vendor.toMap()['vendorVerification'] as Map?;
    final fullName = verification?['fullName'] as String? ??
        vendor.displayName;
    final career = verification?['career'] as String? ?? '';
    final controlNumber =
        verification?['controlNumber'] as String? ?? '';
    final submittedAt =
        (verification?['submittedAt'] as Timestamp?)?.toDate();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOverlay),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Identity row ─────────────────────────────────────────
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.accentGreen,
                child: Text(
                  fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                  style: AppTextStyles.h3
                      .copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fullName,
                        style: AppTextStyles.body.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                    if (career.isNotEmpty)
                      Text(career,
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis),
                    if (controlNumber.isNotEmpty)
                      Text('N.C. $controlNumber',
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Email ─────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.email_outlined,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(vendor.email,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),

          // ── Submitted at ──────────────────────────────────────────
          if (submittedAt != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.schedule_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Solicitud: ${_fmtDate(submittedAt)}',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),

          // ── Credential button ─────────────────────────────────────
          OutlinedButton.icon(
            icon: const Icon(Icons.badge_outlined, size: 16),
            label: const Text('Ver credencial'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.borderOverlay),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              textStyle: AppTextStyles.caption,
            ),
            onPressed: () => _showCredentialDialog(context, vendor),
          ),
          const SizedBox(height: 14),

          // ── Action row ────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.6)),
                  ),
                  onPressed: () =>
                      _confirmReject(context, vendor.uid),
                  child: const Text('Rechazar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _approve(context, vendor.uid),
                  child: const Text('Aprobar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _approve(BuildContext context, String uid) async {
    await FirebaseFirestore.instance
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .update({
      'vendorStatus': VendorStatus.approved.name,
      'roles': FieldValue.arrayUnion(['vendor']),
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Vendedor aprobado'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _confirmReject(BuildContext context, String uid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text('¿Rechazar solicitud?',
            style: AppTextStyles.h3
                .copyWith(color: AppColors.textPrimary)),
        content: Text(
          'El vendedor no podrá acceder al dashboard y recibirá el estado "rechazado".',
          style: AppTextStyles.body
              .copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .update({'vendorStatus': VendorStatus.rejected.name});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Solicitud rechazada'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _showCredentialDialog(BuildContext context, UserModel vendor) {
    final verification =
        vendor.toMap()['vendorVerification'] as Map?;
    final hasCredential = verification != null &&
        (verification['idFrontUrl'] != null ||
            verification['idBackUrl'] != null);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text('Credencial enviada',
            style: AppTextStyles.h3
                .copyWith(color: AppColors.textPrimary)),
        content: Text(
          hasCredential
              ? 'El vendedor subió su credencial durante el proceso '
                  'de verificación. Revisa Firebase Storage → '
                  'vendor_ids/${vendor.uid}/ para acceder a las imágenes.'
              : 'Este vendedor no subió imágenes de credencial.',
          style: AppTextStyles.body
              .copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
