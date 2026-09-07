import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/ui/app_bottom_nav.dart';
import 'patient/tabs/emergency_contacts_tab.dart';
import 'patient/tabs/patient_beranda_tab.dart';
import 'patient/tabs/patient_settings_tab.dart';
import 'patient/widgets/patient_notifications_sheet.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  int _navIndex = 0;
  final _berandaKey = GlobalKey<PatientBerandaTabState>();

  void _openNotifications() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => const PatientNotificationsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navIndex == 0 ? AppColors.white : AppColors.background,
      appBar: _navIndex == 0
          ? null
          : AppBar(
              title: Text(_navTitle),
              automaticallyImplyLeading: false,
            ),
      body: IndexedStack(
        index: _navIndex,
        children: [
          PatientBerandaTab(
            key: _berandaKey,
            onOpenNotifications: _openNotifications,
          ),
          const EmergencyContactsTab(),
          const PatientSettingsTab(),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _navIndex,
        onSelected: (i) {
          setState(() => _navIndex = i);
          if (i == 0) _berandaKey.currentState?.reloadHistory();
        },
        destinations: const [
          AppBottomNavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Beranda',
          ),
          AppBottomNavItem(
            icon: Icons.contact_phone_outlined,
            activeIcon: Icons.contact_phone_rounded,
            label: 'Kontak',
          ),
          AppBottomNavItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings_rounded,
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }

  String get _navTitle {
    switch (_navIndex) {
      case 0:
        return 'Beranda';
      case 1:
        return 'Kontak';
      default:
        return 'Pengaturan';
    }
  }
}
