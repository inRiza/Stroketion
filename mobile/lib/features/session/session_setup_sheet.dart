import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../models/monitoring_session_record.dart';
import '../../widgets/auth_gradient_layout.dart';
import '../../widgets/ui/app_button.dart';
import 'active_session_screen.dart';

Future<void> showSessionSetupSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) => const _SessionSetupSheet(),
  );
}

class _SessionSetupSheet extends StatefulWidget {
  const _SessionSetupSheet();

  @override
  State<_SessionSetupSheet> createState() => _SessionSetupSheetState();
}

class _SessionSetupSheetState extends State<_SessionSetupSheet> {
  SessionLocation _location = SessionLocation.home;
  SessionActivity _activity = SessionActivity.daily;

  void _start() {
    final setup = SessionSetup(location: _location, activity: _activity);
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveSessionScreen(setup: setup),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Mulai Sesi',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Sedang di mana?'),
          const SizedBox(height: 10),
          _OptionRow<SessionLocation>(
            value: _location,
            options: SessionLocation.values,
            label: (v) => v.label,
            icon: (v) => v == SessionLocation.home
                ? Icons.home_outlined
                : Icons.park_outlined,
            onChanged: (v) => setState(() => _location = v),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Aktivitas'),
          const SizedBox(height: 10),
          _OptionRow<SessionActivity>(
            value: _activity,
            options: SessionActivity.values,
            label: (v) => v.label,
            icon: (v) => v == SessionActivity.daily
                ? Icons.directions_walk_outlined
                : Icons.fitness_center_outlined,
            onChanged: (v) => setState(() => _activity = v),
          ),
          const SizedBox(height: 28),
          AppButton(
            label: 'Mulai Sesi',
            icon: Icons.play_arrow_rounded,
            onPressed: _start,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({
    required this.value,
    required this.options,
    required this.label,
    required this.icon,
    required this.onChanged,
  });

  final T value;
  final List<T> options;
  final String Function(T) label;
  final IconData Function(T) icon;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.map((opt) {
        final selected = opt == value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: opt != options.last ? 10 : 0),
            child: _SetupOption(
              label: label(opt),
              icon: icon(opt),
              selected: selected,
              onTap: () => onChanged(opt),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SetupOption extends StatelessWidget {
  const _SetupOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AuthSelectionTile(
      label: label,
      icon: icon,
      isSelected: selected,
      onTap: onTap,
      surface: SelectionSurface.onWhite,
      stacked: true,
    );
  }
}
