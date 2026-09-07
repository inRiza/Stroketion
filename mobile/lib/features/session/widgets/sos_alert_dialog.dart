import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/emergency_alert_service.dart';
import '../../../widgets/ui/app_button.dart';
import '../../../widgets/ui/app_confirm_dialog.dart';

typedef SosAlertCallback = Future<void> Function(bool callSos);

Future<void> showSosAlertDialog({
  required BuildContext context,
  required String reason,
  Duration timeout = const Duration(seconds: 15),
  required SosAlertCallback onResolved,
}) async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Darurat',
    barrierColor: Colors.black.withValues(alpha: 0.65),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, __) => _PatientSosAlertDialog(
      reason: reason,
      timeout: timeout,
      onResolved: onResolved,
    ),
    transitionBuilder: (ctx, anim, _, child) {
      return ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      );
    },
  );
}

class _PatientSosAlertDialog extends StatefulWidget {
  const _PatientSosAlertDialog({
    required this.reason,
    required this.timeout,
    required this.onResolved,
  });

  final String reason;
  final Duration timeout;
  final SosAlertCallback onResolved;

  @override
  State<_PatientSosAlertDialog> createState() => _PatientSosAlertDialogState();
}

class _PatientSosAlertDialogState extends State<_PatientSosAlertDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late int _secondsLeft;
  Timer? _timer;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _secondsLeft = widget.timeout.inSeconds;
    EmergencyAlertService.instance.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_resolved) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        _finish(callSos: true);
      }
    });
  }

  Future<void> _finish({required bool callSos}) async {
    if (_resolved) return;
    _resolved = true;
    _timer?.cancel();
    await EmergencyAlertService.instance.stop();
    if (mounted) Navigator.of(context).pop();
    await widget.onResolved(callSos);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    EmergencyAlertService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reason = cleanAlertText(widget.reason);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.sizeOf(context).width * 0.88,
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          decoration: appDialogDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.08).animate(
                  CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                ),
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sos, color: AppColors.primary, size: 38),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Risiko tinggi',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              if (reason.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  reason,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                '$_secondsLeft',
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  color: AppColors.primary,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'detik',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 22),
              AppButton(
                label: 'Hubungi SOS',
                onPressed: () => _finish(callSos: true),
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Saya baik-baik saja',
                variant: AppButtonVariant.neutral,
                onPressed: () => _finish(callSos: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showCaregiverSosAlertDialog({
  required BuildContext context,
  required String patientName,
  required String message,
  required Future<void> Function() onAcknowledged,
}) {
  return showEmergencyStyledAlert(
    context: context,
    title: 'Darurat pasien',
    message: cleanAlertText('$patientName memicu SOS. $message'),
    primaryLabel: 'Saya tangani',
    onPrimary: onAcknowledged,
  );
}

Future<void> showEmergencyStyledAlert({
  required BuildContext context,
  required String title,
  required String message,
  required String primaryLabel,
  required Future<void> Function() onPrimary,
  String? secondaryLabel,
  Future<void> Function()? onSecondary,
}) async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Darurat',
    barrierColor: Colors.black.withValues(alpha: 0.65),
    pageBuilder: (ctx, _, __) => _StyledEmergencyDialog(
      title: title,
      message: message,
      primaryLabel: primaryLabel,
      onPrimary: onPrimary,
      secondaryLabel: secondaryLabel,
      onSecondary: onSecondary,
    ),
  );
}

class _StyledEmergencyDialog extends StatefulWidget {
  const _StyledEmergencyDialog({
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final Future<void> Function() onPrimary;
  final String? secondaryLabel;
  final Future<void> Function()? onSecondary;

  @override
  State<_StyledEmergencyDialog> createState() => _StyledEmergencyDialogState();
}

class _StyledEmergencyDialogState extends State<_StyledEmergencyDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    EmergencyAlertService.instance.start();
  }

  Future<void> _close({required bool primary}) async {
    if (_closing) return;
    _closing = true;
    await EmergencyAlertService.instance.stop();
    if (mounted) Navigator.of(context).pop();
    if (primary) {
      await widget.onPrimary();
    } else {
      await widget.onSecondary?.call();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    EmergencyAlertService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.sizeOf(context).width * 0.88,
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          decoration: appDialogDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.08).animate(
                  CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                ),
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sos, color: AppColors.primary, size: 38),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 22),
              AppButton(
                label: widget.primaryLabel,
                onPressed: () => _close(primary: true),
              ),
              if (widget.secondaryLabel != null) ...[
                const SizedBox(height: 10),
                AppButton(
                  label: widget.secondaryLabel!,
                  variant: AppButtonVariant.neutral,
                  onPressed: () => _close(primary: false),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
