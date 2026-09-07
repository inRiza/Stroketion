import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';

enum AppButtonVariant { primary, secondary, neutral, outline, text, inverse, ghost }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.isExpanded = true,
    this.icon,
    this.lightStyle = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool isExpanded;
  final IconData? icon;
  final bool lightStyle;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: _spinnerColor(),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 10),
              ],
              Text(label),
            ],
          );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.button),
    );

    Widget button;

    switch (variant) {
      case AppButtonVariant.primary:
      case AppButtonVariant.secondary:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.45),
            disabledForegroundColor: AppColors.white.withValues(alpha: 0.85),
            elevation: 0,
            shape: shape,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: child,
        );
      case AppButtonVariant.inverse:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.white,
            foregroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.white.withValues(alpha: 0.7),
            disabledForegroundColor: AppColors.primary.withValues(alpha: 0.5),
            elevation: 0,
            shape: shape,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: child,
        );
      case AppButtonVariant.ghost:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.14),
            foregroundColor: AppColors.white,
            disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
            disabledForegroundColor: AppColors.white.withValues(alpha: 0.5),
            elevation: 0,
            shape: shape,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: child,
        );
      case AppButtonVariant.neutral:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.ctaMuted,
            foregroundColor: AppColors.textPrimary,
            disabledBackgroundColor: AppColors.ctaMuted.withValues(alpha: 0.7),
            disabledForegroundColor: AppColors.textSecondary,
            elevation: 0,
            shape: shape,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: child,
        );
      case AppButtonVariant.outline:
        button = OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            backgroundColor: AppColors.white,
            side: BorderSide(
              color: lightStyle ? Colors.transparent : AppColors.border,
              width: 1.2,
            ),
            shape: shape,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: child,
        );
      case AppButtonVariant.text:
        button = TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.textSecondary,
            ),
          ),
          child: child,
        );
    }

    if (isExpanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }

  Color _spinnerColor() {
    switch (variant) {
      case AppButtonVariant.primary:
      case AppButtonVariant.secondary:
      case AppButtonVariant.ghost:
        return AppColors.white;
      case AppButtonVariant.inverse:
      case AppButtonVariant.outline:
      case AppButtonVariant.text:
      case AppButtonVariant.neutral:
        return AppColors.primary;
    }
  }
}
