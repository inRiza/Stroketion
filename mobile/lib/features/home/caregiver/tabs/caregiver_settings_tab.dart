import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routes/app_routes.dart';
import '../../../../services/auth_service.dart';
import '../../../../widgets/ui/settings_list.dart';
import '../../../link/patient_qr_screen.dart';
import '../../../settings/server_settings_screen.dart';

class CaregiverSettingsTab extends StatelessWidget {
  const CaregiverSettingsTab({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthService().logout();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.roleSelection,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Pengaturan',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          SettingsList(
            items: [
              SettingsItem(
                icon: Icons.settings_ethernet,
                title: 'Alamat server',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ServerSettingsScreen()),
                  );
                },
              ),
              SettingsItem(
                icon: Icons.qr_code_2,
                title: 'QR Profil Saya',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PatientQrScreen()),
                  );
                },
              ),
              SettingsItem(
                icon: Icons.logout,
                title: 'Keluar',
                isDestructive: true,
                onTap: () => _logout(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
