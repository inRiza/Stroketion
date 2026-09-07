import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/link_models.dart';
import '../../../../services/api_client.dart';
import '../../../../services/link_service.dart';
import '../../../../widgets/ui/app_button.dart';
import '../../../../widgets/ui/empty_state.dart';
import '../../../link/qr_scan_screen.dart';
import '../widgets/linked_patient_card.dart';

class CaregiverPatientsTab extends StatefulWidget {
  const CaregiverPatientsTab({super.key});

  @override
  State<CaregiverPatientsTab> createState() => _CaregiverPatientsTabState();
}

class _CaregiverPatientsTabState extends State<CaregiverPatientsTab> {
  final _linkService = LinkService();
  List<LinkedPatient> _patients = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final patients = await _linkService.getMyPatients();
      if (mounted) setState(() => _patients = patients);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scanPatient() async {
    final userId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const QrScanScreen(title: 'Scan QR Pasien'),
      ),
    );
    if (userId == null || !mounted) return;

    try {
      await _linkService.scanPatient(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permintaan dikirim, menunggu persetujuan pasien')),
        );
        await _load();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Daftar Pasien',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Scan QR pasien',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _patients.isEmpty
                    ? const EmptyState(
                        icon: Icons.people_outline,
                        title: 'Belum ada pasien terhubung',
                        subtitle: 'Scan QR pasien untuk mulai memantau',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.primary,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _patients.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            return LinkedPatientCard(patient: _patients[index]);
                          },
                        ),
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: AppButton(
              label: 'Scan QR Pasien',
              variant: AppButtonVariant.secondary,
              icon: Icons.qr_code_scanner,
              onPressed: _scanPatient,
            ),
          ),
        ],
      ),
    );
  }
}
