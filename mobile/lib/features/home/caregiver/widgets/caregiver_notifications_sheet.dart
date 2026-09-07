import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/link_models.dart';
import '../../../../services/api_client.dart';
import '../../../../services/link_service.dart';
import '../../../../widgets/ui/app_button.dart';

class CaregiverNotificationsSheet extends StatefulWidget {
  const CaregiverNotificationsSheet({super.key});

  @override
  State<CaregiverNotificationsSheet> createState() =>
      _CaregiverNotificationsSheetState();
}

class _CaregiverNotificationsSheetState extends State<CaregiverNotificationsSheet> {
  final _linkService = LinkService();
  List<PendingNotification> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _linkService.getPendingNotifications();
      if (mounted) setState(() => _notifications = items);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(String linkId) async {
    try {
      await _linkService.approveLink(linkId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pasien disetujui')),
        );
        await _load();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _reject(String linkId) async {
    try {
      await _linkService.rejectLink(linkId);
      if (mounted) await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          const Text(
            'Notifikasi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (_notifications.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Tidak ada permintaan baru',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ..._notifications.map((n) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.patientName ?? 'Pasien',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (n.patientPhone != null)
                        Text(
                          n.patientPhone!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (n.relationship != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Hubungan: ${n.relationship}',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'Tolak',
                              variant: AppButtonVariant.outline,
                              onPressed: () => _reject(n.linkId),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AppButton(
                              label: 'Setujui',
                              variant: AppButtonVariant.secondary,
                              onPressed: () => _approve(n.linkId),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
