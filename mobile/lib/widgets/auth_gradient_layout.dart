import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import 'ui/app_logo.dart';
import 'wave_background.dart';

enum SelectionSurface { onRed, onWhite }

/// Layout auth — background merah bergelombang, konten di atasnya.
class AuthGradientLayout extends StatelessWidget {
  const AuthGradientLayout({
    super.key,
    required this.child,
    this.showLogo = true,
    this.topLeading,
    this.topTrailing,
    this.compactHeader = false,
  });

  final Widget child;
  final bool showLogo;
  final Widget? topLeading;
  final Widget? topTrailing;
  final bool compactHeader;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WaveBackground(
        fullScreen: true,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    if (topLeading != null)
                      topLeading!
                    else
                      const SizedBox(width: 48),
                    const Spacer(),
                    if (topTrailing != null) topTrailing!,
                  ],
                ),
              ),
              if (showLogo) ...[
                _BrandBadge(compact: compactHeader),
                SizedBox(height: compactHeader ? 12 : 20),
              ] else
                const SizedBox(height: 4),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandBadge extends StatelessWidget {
  const _BrandBadge({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 44.0 : 56.0;

    return Center(
      child: AppLogo(
        variant: AppLogoVariant.onRed,
        height: height,
      ),
    );
  }
}

class AuthHeroText extends StatelessWidget {
  const AuthHeroText({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow = AppStrings.appName,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.white.withValues(alpha: 0.82),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.white,
            letterSpacing: -0.4,
            height: 1.15,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.white.withValues(alpha: 0.88),
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

/// Tile seleksi — tanpa shadow. Warna berubah saat dipilih.
class AuthSelectionTile extends StatelessWidget {
  const AuthSelectionTile({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.description,
    this.icon,
    this.centerLabel = false,
    this.stacked = false,
    this.surface = SelectionSurface.onRed,
  });

  final String label;
  final String? description;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool centerLabel;
  final bool stacked;
  final SelectionSurface surface;

  @override
  Widget build(BuildContext context) {
    final onRed = surface == SelectionSurface.onRed;

    final bgColor = onRed
        ? (isSelected ? AppColors.selectionOnRed : AppColors.white)
        : (isSelected ? AppColors.primary : AppColors.white);

    final border = onRed
        ? null
        : Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderSubtle,
            width: 1,
          );

    final titleColor = onRed
        ? AppColors.textPrimary
        : (isSelected ? AppColors.white : AppColors.textPrimary);

    final subtitleColor = onRed
        ? AppColors.textSecondary
        : (isSelected ? AppColors.white.withValues(alpha: 0.88) : AppColors.textSecondary);

    final iconBg = onRed
        ? (isSelected ? AppColors.white : AppColors.primarySoft)
        : (isSelected ? AppColors.white.withValues(alpha: 0.2) : AppColors.primarySoft);

    final iconColor = onRed
        ? AppColors.primary
        : (isSelected ? AppColors.white : AppColors.primary);

    final checkColor = onRed ? AppColors.primary : AppColors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            horizontal: icon != null ? 18 : 16,
            vertical: icon != null ? 16 : 14,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppRadius.button),
            border: border,
          ),
          child: icon != null && stacked
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: iconColor, size: 24),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                  ],
                )
              : icon != null
              ? Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(icon, color: iconColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: titleColor,
                            ),
                          ),
                          if (description != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              description!,
                              style: TextStyle(
                                fontSize: 13,
                                color: subtitleColor,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isSelected ? 1 : 0,
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: checkColor,
                        size: 22,
                      ),
                    ),
                  ],
                )
              : centerLabel
                  ? Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: onRed
                              ? (isSelected ? AppColors.primary : AppColors.textSecondary)
                              : titleColor,
                        ),
                      ),
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: onRed
                            ? (isSelected ? AppColors.primary : AppColors.textSecondary)
                            : titleColor,
                      ),
                    ),
        ),
      ),
    );
  }
}
