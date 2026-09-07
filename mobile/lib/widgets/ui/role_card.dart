import 'package:flutter/material.dart';

import '../auth_gradient_layout.dart';

class RoleCard extends StatelessWidget {
  const RoleCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AuthSelectionTile(
      label: title,
      description: description,
      icon: icon,
      isSelected: isSelected,
      onTap: onTap,
    );
  }
}
