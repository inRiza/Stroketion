import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../features/settings/server_settings_screen.dart';
import '../../models/user_role.dart';
import '../../routes/app_routes.dart';
import '../../widgets/auth_gradient_layout.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/role_card.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  UserRole? _selectedRole;

  void _goToLogin() {
    Navigator.pushNamed(context, AppRoutes.login, arguments: _selectedRole);
  }

  void _goToRegister() {
    Navigator.pushNamed(context, AppRoutes.register, arguments: _selectedRole);
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selectedRole != null;

    return AuthGradientLayout(
      topTrailing: IconButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ServerSettingsScreen()),
          );
        },
        icon: const Icon(Icons.settings_outlined, color: AppColors.white),
        tooltip: 'Pengaturan server',
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthHeroText(
              title: AppStrings.selectRole,
              subtitle: AppStrings.selectRoleSubtitle,
            ),
            const SizedBox(height: 28),
            RoleCard(
              title: AppStrings.patient,
              description: AppStrings.patientDesc,
              icon: Icons.person_outline_rounded,
              isSelected: _selectedRole == UserRole.patient,
              onTap: () => setState(() => _selectedRole = UserRole.patient),
            ),
            const SizedBox(height: 12),
            RoleCard(
              title: AppStrings.caregiver,
              description: AppStrings.caregiverDesc,
              icon: Icons.family_restroom_outlined,
              isSelected: _selectedRole == UserRole.caregiver,
              onTap: () => setState(() => _selectedRole = UserRole.caregiver),
            ),
            const Spacer(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: hasSelection
                  ? Column(
                      key: const ValueKey('actions'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppButton(
                          label: AppStrings.login,
                          icon: Icons.login_rounded,
                          variant: AppButtonVariant.inverse,
                          onPressed: _goToLogin,
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          label: AppStrings.register,
                          variant: AppButtonVariant.ghost,
                          onPressed: _goToRegister,
                        ),
                        const SizedBox(height: 16),
                      ],
                    )
                  : const SizedBox(key: ValueKey('empty'), height: 8),
            ),
          ],
        ),
      ),
    );
  }
}
