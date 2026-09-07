import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.labels = const [],
  });

  final int currentStep;
  final int totalSteps;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final progress = currentStep / totalSteps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Langkah $currentStep dari $totalSteps',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.white.withValues(alpha: 0.88),
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.white.withValues(alpha: 0.35),
            color: AppColors.white,
          ),
        ),
        if (labels.isNotEmpty && currentStep <= labels.length) ...[
          const SizedBox(height: 10),
          Text(
            labels[currentStep - 1],
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
        ],
      ],
    );
  }
}
