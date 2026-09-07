import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/link_models.dart';
import '../../../../services/api_client.dart';
import '../../../../services/link_service.dart';
import '../../../../widgets/ui/app_button.dart';
import '../../../../widgets/ui/app_text_field.dart';
import '../../../../widgets/ui/empty_state.dart';
import '../../../link/qr_scan_screen.dart';

class PatientCaregiverSection extends StatefulWidget {
  const PatientCaregiverSection({super.key});

  @override
  State<PatientCaregiverSection> createState() => _PatientCaregiverSectionState();
}

class _PatientCaregiverSectionState extends State<PatientCaregiverSection> {
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

  Future<void> _scanCaregiver() async {
    final userId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const QrScanScreen(title: 'Scan QR Caregiver'),
      ),
    );
    if (userId == null || !mounted) return;

    try {
      final profile = await _linkService.getUserProfile(userId);
      if (!mounted) return;
      await _confirmAndRequest(profile);
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _addByPhone() async {
    final lookup = await showModalBottomSheet<CaregiverLookup>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PhoneLookupSheet(linkService: _linkService),
    );

    if (lookup != null && mounted) {
      await _confirmAndRequest(
        UserProfile(
          id: lookup.id,
          email: lookup.email,
          fullName: lookup.fullName,
          phone: lookup.phone,
          role: 'caregiver',
        ),
      );
      await _load();
    }
  }

  Future<void> _confirmAndRequest(UserProfile profile) async {
    final result = await showDialog<Object?>(
      context: context,
      builder: (_) => _ConfirmCaregiverDialog(profile: profile),
    );

    if (result == null || result == false || !mounted) return;

    final relationship = result is String ? result : null;

    try {
      await _linkService.requestCaregiver(
        caregiverId: profile.id,
        relationship: relationship,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permintaan dikirim, menunggu persetujuan caregiver')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _approveCaregiver(LinkedCaregiver caregiver) async {
    try {
      await _linkService.approveLink(caregiver.linkId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Caregiver berhasil ditambahkan')),
        );
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _rejectCaregiver(LinkedCaregiver caregiver) async {
    try {
      await _linkService.rejectLink(caregiver.linkId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permintaan caregiver ditolak')),
        );
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  String _statusLabel(LinkedCaregiver c) {
    if (c.needsPatientApproval) return 'Perlu persetujuan';
    if (c.waitingCaregiverApproval) return 'Menunggu';
    return 'Aktif';
  }

  Color _statusColor(LinkedCaregiver c) {
    if (c.needsPatientApproval) return AppColors.primaryDark;
    if (c.waitingCaregiverApproval) return AppColors.primary;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Caregiver Terhubung',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'Caregiver yang memantau kondisi Anda',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Center(child: CircularProgressIndicator(color: AppColors.primary))
        else if (_caregivers.isEmpty)
          const EmptyState(
            icon: Icons.family_restroom_outlined,
            title: 'Belum ada caregiver terhubung',
            subtitle: 'Scan QR atau cari via nomor telepon',
            padding: EdgeInsets.symmetric(vertical: 20),
          )
        else
          ..._caregivers.map(
            (c) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.fullName ?? c.email,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            if (c.phone != null)
                              Text(
                                c.phone!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(c).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _statusLabel(c),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(c),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (c.needsPatientApproval) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Tolak',
                            variant: AppButtonVariant.outline,
                            isExpanded: true,
                            onPressed: () => _rejectCaregiver(c),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppButton(
                            label: 'Terima',
                            variant: AppButtonVariant.secondary,
                            isExpanded: true,
                            onPressed: () => _approveCaregiver(c),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Scan QR',
                variant: AppButtonVariant.outline,
                isExpanded: true,
                onPressed: _scanCaregiver,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                label: 'Cari Nomor',
                variant: AppButtonVariant.secondary,
                isExpanded: true,
                onPressed: _addByPhone,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _PhoneLookupSheet extends StatefulWidget {
  const _PhoneLookupSheet({required this.linkService});

  final LinkService linkService;

  @override
  State<_PhoneLookupSheet> createState() => _PhoneLookupSheetState();
}

class _PhoneLookupSheetState extends State<_PhoneLookupSheet> {
  final _phoneController = TextEditingController();
  bool _searching = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final phone = _phoneController.text.trim();

    if (phone.length < 10) {
      setState(() => _errorMessage = 'Nomor telepon minimal 10 digit');
      return;
    }

    if (_searching) return;

    setState(() {
      _searching = true;
      _errorMessage = null;
    });

    try {
      final found = await widget.linkService.lookupCaregiverByPhone(phone);
      if (mounted) Navigator.pop(context, found);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cari Caregiver',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _phoneController,
            label: 'Nomor Telepon',
            hint: '08xxxxxxxxxx',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
          ),
          if (_searching) ...[
            const SizedBox(height: 16),
            const _CaregiverSearchSkeleton(),
          ],
          if (_errorMessage != null && !_searching) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          AppButton(
            label: 'Cari',
            variant: AppButtonVariant.secondary,
            isLoading: _searching,
            onPressed: _searching ? null : _search,
          ),
        ],
      ),
    );
  }
}

class _CaregiverSearchSkeleton extends StatelessWidget {
  const _CaregiverSearchSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.border,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 12,
                  width: 120,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmCaregiverDialog extends StatefulWidget {
  const _ConfirmCaregiverDialog({required this.profile});

  final UserProfile profile;

  @override
  State<_ConfirmCaregiverDialog> createState() => _ConfirmCaregiverDialogState();
}

class _ConfirmCaregiverDialogState extends State<_ConfirmCaregiverDialog> {
  final _relationController = TextEditingController();

  @override
  void dispose() {
    _relationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Konfirmasi Caregiver'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConfirmRow(label: 'Nama', value: widget.profile.fullName ?? '-'),
            _ConfirmRow(label: 'Telepon', value: widget.profile.phone ?? '-'),
            _ConfirmRow(label: 'Email', value: widget.profile.email),
            const SizedBox(height: 12),
            AppTextField(
              controller: _relationController,
              label: 'Hubungan',
              hint: 'Contoh: Anak, Suami, Istri',
              prefixIcon: Icons.family_restroom_outlined,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () {
            final relation = _relationController.text.trim();
            Navigator.pop(context, relation.isEmpty ? true : relation);
          },
          child: const Text('Konfirmasi', style: TextStyle(color: AppColors.primary)),
        ),
      ],
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
