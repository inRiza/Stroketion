import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/emergency_contact.dart';
import '../../../services/sos_service.dart';
import '../../../widgets/ui/app_button.dart';

/// Dialog berantai: telepon kontak SOS berurutan prioritas.
Future<void> showSosCallChainDialog({
  required BuildContext context,
  required SosService sosService,
}) async {
  final contacts = await sosService.getCallList();
  if (!context.mounted || contacts.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada kontak SOS. Tambahkan di tab Kontak.')),
      );
    }
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _SosCallChainSheet(
      contacts: contacts,
      sosService: sosService,
    ),
  );
}

class _SosCallChainSheet extends StatefulWidget {
  const _SosCallChainSheet({
    required this.contacts,
    required this.sosService,
  });

  final List<EmergencyContact> contacts;
  final SosService sosService;

  @override
  State<_SosCallChainSheet> createState() => _SosCallChainSheetState();
}

class _SosCallChainSheetState extends State<_SosCallChainSheet>
    with WidgetsBindingObserver {
  int _index = 0;
  bool _awaitingAnswer = false;

  EmergencyContact get _current => widget.contacts[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _dialCurrent());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingAnswer) {
      setState(() => _awaitingAnswer = false);
    }
  }

  Future<void> _dialCurrent() async {
    setState(() => _awaitingAnswer = true);
    await widget.sosService.dialContact(_current);
  }

  void _answered() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('SOS: ${_current.name} dihubungi')),
    );
  }

  Future<void> _tryNext() async {
    if (_index + 1 >= widget.contacts.length) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua kontak SOS sudah dihubungi')),
      );
      return;
    }
    setState(() => _index++);
    await _dialCurrent();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sos, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Memanggil SOS (${_index + 1}/${widget.contacts.length})',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _current.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          Text(
            _current.phone,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Prioritas ${_current.priority}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          const Text(
            'Apakah kontak ini menjawab?',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Ya, sudah dihubungi',
            onPressed: _answered,
          ),
          const SizedBox(height: 10),
          AppButton(
            label: _index + 1 < widget.contacts.length
                ? 'Tidak, hubungi berikutnya'
                : 'Tidak ada yang menjawab',
            variant: AppButtonVariant.neutral,
            onPressed: _tryNext,
          ),
        ],
      ),
    );
  }
}
