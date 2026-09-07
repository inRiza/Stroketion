import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/ui/app_bottom_nav.dart';
import 'caregiver/tabs/caregiver_beranda_tab.dart';
import 'caregiver/tabs/caregiver_patients_tab.dart';
import 'caregiver/tabs/caregiver_settings_tab.dart';
import 'caregiver/widgets/caregiver_notifications_sheet.dart';
import 'caregiver/widgets/caregiver_sos_listener.dart';
import '../../services/link_service.dart';

class CaregiverHomeScreen extends StatefulWidget {
  const CaregiverHomeScreen({super.key});

  @override
  State<CaregiverHomeScreen> createState() => _CaregiverHomeScreenState();
}

class _CaregiverHomeScreenState extends State<CaregiverHomeScreen> {
  int _navIndex = 0;
  int _pendingCount = 0;
  final _linkService = LinkService();

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    try {
      final items = await _linkService.getPendingNotifications();
      if (mounted) setState(() => _pendingCount = items.length);
    } catch (_) {}
  }

  void _openNotifications() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const CaregiverNotificationsSheet(),
    ).then((_) => _loadPendingCount());
  }

  @override
  Widget build(BuildContext context) {
    return CaregiverSosListener(
      child: Scaffold(
        backgroundColor: _navIndex == 0 ? AppColors.white : AppColors.background,
        appBar: _navIndex == 0
            ? null
            : AppBar(
                title: Text(_navTitle),
                automaticallyImplyLeading: false,
                actions: [
                  Badge(
                    isLabelVisible: _pendingCount > 0,
                    label: Text('$_pendingCount'),
                    child: IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: _openNotifications,
                    ),
                  ),
                ],
              ),
        body: IndexedStack(
          index: _navIndex,
          children: [
            CaregiverBerandaTab(onOpenNotifications: _openNotifications),
            const CaregiverPatientsTab(),
            const CaregiverSettingsTab(),
          ],
        ),
        bottomNavigationBar: AppBottomNav(
          selectedIndex: _navIndex,
          onSelected: (i) => setState(() => _navIndex = i),
          destinations: const [
            AppBottomNavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Beranda',
            ),
            AppBottomNavItem(
              icon: Icons.people_outline,
              activeIcon: Icons.people_rounded,
              label: 'Pasien',
            ),
            AppBottomNavItem(
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings_rounded,
              label: 'Pengaturan',
            ),
          ],
        ),
      ),
    );
  }

  String get _navTitle {
    switch (_navIndex) {
      case 0:
        return 'Beranda';
      case 1:
        return 'Pasien';
      default:
        return 'Pengaturan';
    }
  }
}
