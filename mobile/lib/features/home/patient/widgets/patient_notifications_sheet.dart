import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/link_models.dart';
import '../../../../services/link_service.dart';
import '../../../../widgets/ui/empty_state.dart';

class PatientNotificationsSheet extends StatefulWidget {
  const PatientNotificationsSheet({super.key});

  @override
  State<PatientNotificationsSheet> createState() => _PatientNotificationsSheetState();
}

class _PatientNotificationsSheetState extends State<PatientNotificationsSheet> {
  final _linkService = LinkService();
  List<LinkedCaregiver> _caregivers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _linkService.getMyCaregivers();
      if (mounted) setState(() => _caregivers = items);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _caregivers.where((c) => c.needsPatientApproval).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Notifikasi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              if (pending > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$pending menunggu',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Status hubungan dengan caregiver',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (_caregivers.isEmpty)
            const EmptyState(
              icon: Icons.notifications_none_outlined,
              title: 'Belum ada permintaan',
              subtitle: 'Hubungkan caregiver dari tab Kontak',
              padding: EdgeInsets.symmetric(vertical: 16),
            )
          else
            ..._caregivers.map((c) => _CaregiverStatusTile(
                  caregiver: c,
                  linkService: _linkService,
                  onChanged: _load,
                )),
        ],
      ),
    );
  }
}

class _CaregiverStatusTile extends StatelessWidget {
  const _CaregiverStatusTile({
    required this.caregiver,
    required this.linkService,
    required this.onChanged,
  });

  final LinkedCaregiver caregiver;
  final LinkService linkService;
  final VoidCallback onChanged;

  Future<void> _approve(BuildContext context) async {
    try {
      await linkService.approveLink(caregiver.linkId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Caregiver berhasil ditambahkan')),
        );
        onChanged();
      }
    } catch (_) {}
  }

  Future<void> _reject(BuildContext context) async {
    try {
      await linkService.rejectLink(caregiver.linkId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permintaan ditolak')),
        );
        onChanged();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final needsAction = caregiver.needsPatientApproval;
    final waiting = caregiver.waitingCaregiverApproval;
    final statusLabel = needsAction
        ? 'Caregiver ingin terhubung'
        : waiting
            ? 'Menunggu persetujuan caregiver'
            : 'Disetujui';
    final statusColor = needsAction
        ? AppColors.primaryDark
        : waiting
            ? AppColors.primary
            : Colors.green.shade700;
    final statusBg = statusColor.withValues(alpha: 0.12);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                needsAction
                    ? Icons.person_add_alt_1_outlined
                    : waiting
                        ? Icons.hourglass_top_outlined
                        : Icons.check_circle_outline,
                color: statusColor,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caregiver.fullName ?? caregiver.email,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (caregiver.relationship != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        caregiver.relationship!,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (needsAction) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _reject(context),
                    child: const Text('Tolak'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _approve(context),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    child: const Text('Terima'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
