import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/qr_helper.dart';
import '../../services/link_service.dart';

class PatientQrScreen extends StatefulWidget {
  const PatientQrScreen({super.key});

  @override
  State<PatientQrScreen> createState() => _PatientQrScreenState();
}

class _PatientQrScreenState extends State<PatientQrScreen> {
  final _linkService = LinkService();
  String? _userId;
  String? _name;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await _linkService.getMyProfile();
      if (mounted) {
        setState(() {
          _userId = profile.id;
          _name = profile.fullName ?? profile.email;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('QR Profil Saya')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.sizeOf(context).height * 0.72,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_name != null) ...[
                    Text(
                      _name!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tunjukkan QR ini ke caregiver untuk terhubung',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  if (_userId != null)
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 320),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Center(
                        child: QrImageView(
                          data: QrHelper.userPayload(_userId!),
                          size: 240,
                          backgroundColor: AppColors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: AppColors.primary,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    )
                  else
                    const CircularProgressIndicator(color: AppColors.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
