import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/emergency_contact.dart';
import '../../../../models/link_models.dart';
import '../../../../services/emergency_contact_storage.dart';
import '../../../../services/link_service.dart';
import '../../../../widgets/ui/app_button.dart';
import '../../../../widgets/ui/app_text_field.dart';
import '../../../../widgets/ui/empty_state.dart';
import '../widgets/patient_caregiver_section.dart';

class EmergencyContactsTab extends StatefulWidget {
  const EmergencyContactsTab({super.key});

  @override
  State<EmergencyContactsTab> createState() => _EmergencyContactsTabState();
}

class _EmergencyContactsTabState extends State<EmergencyContactsTab> {
  final _storage = EmergencyContactStorage();
  final _links = LinkService();
  List<EmergencyContact> _sosContacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final contacts = await _storage.getSosContacts();
    if (mounted) {
      setState(() {
        _sosContacts = contacts;
        _loading = false;
      });
    }
  }

  Future<void> _showAddSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddSosSheet(
        onPickCaregiver: _addFromCaregiver,
        onAddManual: _addManual,
      ),
    );
  }

  Future<void> _addFromCaregiver() async {
    Navigator.pop(context);
    List<LinkedCaregiver> caregivers = [];
    try {
      caregivers = (await _links.getMyCaregivers())
          .where((c) => c.isApproved && c.phone != null && c.phone!.length >= 10)
          .toList();
    } catch (_) {}

    if (!mounted) return;
    if (caregivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belum ada caregiver terhubung dengan nomor telepon'),
        ),
      );
      return;
    }

    final picked = await showModalBottomSheet<LinkedCaregiver>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CaregiverPickerSheet(caregivers: caregivers),
    );

    if (picked == null) return;

    final existing = _sosContacts.any((c) => c.caregiverId == picked.id);
    if (existing) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Caregiver ini sudah ada di daftar SOS')),
        );
      }
      return;
    }

    final priority = await _storage.nextSosPriority();
    await _storage.add(EmergencyContact(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: picked.fullName ?? picked.email,
      phone: picked.phone!,
      type: 'sos',
      priority: priority,
      source: 'caregiver',
      caregiverId: picked.id,
    ));
    await _loadContacts();
  }

  Future<void> _addManual() async {
    Navigator.pop(context);
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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
                'Nomor SOS Baru',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Kontak khusus darurat, terpisah dari caregiver',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              AppTextField(
                controller: nameController,
                label: 'Nama',
                hint: 'Nama kontak',
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: phoneController,
                label: 'Nomor Telepon',
                hint: '08xxxxxxxxxx',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Simpan',
                variant: AppButtonVariant.secondary,
                onPressed: () {
                  if (nameController.text.trim().isEmpty ||
                      phoneController.text.trim().length < 10) {
                    return;
                  }
                  Navigator.pop(context, true);
                },
              ),
            ],
          ),
        );
      },
    );

    if (saved == true) {
      final priority = await _storage.nextSosPriority();
      await _storage.add(EmergencyContact(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        type: 'sos',
        priority: priority,
        source: 'manual',
      ));
      await _loadContacts();
    }

    nameController.dispose();
    phoneController.dispose();
  }

  Future<void> _deleteContact(EmergencyContact contact) async {
    await _storage.remove(contact.id);
    await _loadContacts();
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final list = List<EmergencyContact>.from(_sosContacts);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    setState(() => _sosContacts = list);
    await _storage.reorderSos(list);
    await _loadContacts();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kontak',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const PatientCaregiverSection(),
                  const Text(
                    'Kontak Darurat SOS',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Urutan prioritas panggilan saat risiko tinggi. Caregiver terhubung hanya menerima notifikasi.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  if (_loading)
                    const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  else if (_sosContacts.isEmpty)
                    const EmptyState(
                      icon: Icons.contact_phone_outlined,
                      title: 'Belum ada kontak SOS',
                      subtitle: 'Tambahkan dari caregiver atau nomor baru',
                      padding: EdgeInsets.symmetric(vertical: 20),
                    )
                  else
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: _sosContacts.length,
                      onReorder: _onReorder,
                      itemBuilder: (context, index) {
                        final contact = _sosContacts[index];
                        return _SosContactTile(
                          key: ValueKey(contact.id),
                          contact: contact,
                          index: index,
                          onDelete: () => _deleteContact(contact),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: AppButton(
              label: 'Tambah Kontak SOS',
              variant: AppButtonVariant.secondary,
              icon: Icons.add,
              onPressed: _showAddSheet,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddSosSheet extends StatelessWidget {
  const _AddSosSheet({
    required this.onPickCaregiver,
    required this.onAddManual,
  });

  final VoidCallback onPickCaregiver;
  final VoidCallback onAddManual;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tambah Kontak SOS',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pilih dari caregiver yang sudah terhubung atau tambah nomor baru',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Dari Caregiver Terhubung',
            variant: AppButtonVariant.secondary,
            icon: Icons.family_restroom_outlined,
            onPressed: onPickCaregiver,
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Nomor Baru (Khusus SOS)',
            variant: AppButtonVariant.outline,
            icon: Icons.phone_outlined,
            onPressed: onAddManual,
          ),
        ],
      ),
    );
  }
}

class _CaregiverPickerSheet extends StatelessWidget {
  const _CaregiverPickerSheet({required this.caregivers});

  final List<LinkedCaregiver> caregivers;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih Caregiver',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...caregivers.map(
            (c) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: const Icon(Icons.person, color: AppColors.primary, size: 20),
              ),
              title: Text(c.fullName ?? c.email),
              subtitle: Text(c.phone ?? ''),
              onTap: () => Navigator.pop(context, c),
            ),
          ),
        ],
      ),
    );
  }
}

class _SosContactTile extends StatelessWidget {
  const _SosContactTile({
    super.key,
    required this.contact,
    required this.index,
    required this.onDelete,
  });

  final EmergencyContact contact;
  final int index;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: Icon(Icons.drag_handle, color: AppColors.textSecondary),
              ),
            ),
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${contact.priority}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contact.phone,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (contact.source == 'caregiver')
                      const Text(
                        'Dari caregiver terhubung',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: AppColors.textSecondary,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
