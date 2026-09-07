import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import 'app_button.dart';

/// Dialog konfirmasi putih — CTA utama merah, alternatif abu-abu.
Future<bool?> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  String? message,
  String confirmLabel = 'Ya',
  String cancelLabel = 'Batal',
  bool barrierDismissible = true,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => _AppConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
    ),
  );
}

class _AppConfirmDialog extends StatelessWidget {
  const _AppConfirmDialog({
    required this.title,
    this.message,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 10),
              Text(
                message!,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 22),
            AppButton(
              label: confirmLabel,
              onPressed: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 10),
            AppButton(
              label: cancelLabel,
              variant: AppButtonVariant.neutral,
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration appDialogDecoration({double radius = AppRadius.xl}) {
  return BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.14),
        blurRadius: 28,
        offset: const Offset(0, 12),
      ),
    ],
  );
}

String cleanAlertText(String text) {
  return text
      .replaceAll('—', ', ')
      .replaceAll('–', ', ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
