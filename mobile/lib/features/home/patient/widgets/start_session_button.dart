import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';

class StartSessionButton extends StatelessWidget {
  const StartSessionButton({super.key, required this.onStart});

  final VoidCallback onStart;

  static const _illustrationAsset = 'assets/illustrations/start_session.svg';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onStart,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              const _SessionIllustration(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Mulai Sesi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Pilih lokasi dan aktivitas, lalu mulai monitoring',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.35),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionIllustration extends StatelessWidget {
  const _SessionIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: SvgPicture.asset(
        StartSessionButton._illustrationAsset,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const _PlayFallback(),
        semanticsLabel: 'Ilustrasi beraktivitas',
      ),
    );
  }
}

class _PlayFallback extends StatelessWidget {
  const _PlayFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Center(
        child: Icon(Icons.directions_walk_rounded, color: AppColors.primary, size: 40),
      ),
    );
  }
}
