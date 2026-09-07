import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class SpeechWaveform extends StatelessWidget {
  const SpeechWaveform({
    super.key,
    required this.samples,
    required this.speechActive,
    required this.speechLevel,
    required this.statusLabel,
    this.offline = false,
  });

  final List<double> samples;
  final bool speechActive;
  final double speechLevel;
  final String statusLabel;
  final bool offline;

  static const _barCount = 40;

  @override
  Widget build(BuildContext context) {
    final label = offline ? statusLabel : statusLabel;
    final icon = offline
        ? Icons.cloud_off_outlined
        : speechActive
            ? Icons.mic
            : Icons.mic_off_outlined;
    final color = offline
        ? AppColors.textSecondary
        : speechActive
            ? AppColors.primary
            : AppColors.textSecondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              Text(
                '${speechLevel.toStringAsFixed(0)} dBFS',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 72,
              width: double.infinity,
              child: CustomPaint(
                painter: _WaveformPainter(
                  samples: samples,
                  active: speechActive && !offline,
                  barCount: _barCount,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.samples,
    required this.active,
    required this.barCount,
  });

  final List<double> samples;
  final bool active;
  final int barCount;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    const gap = 2.0;
    final totalGap = gap * (barCount - 1);
    final barWidth = max(2.0, (size.width - totalGap) / barCount);

    for (var i = 0; i < barCount; i++) {
      final value = i < samples.length ? samples[i] : 0.06;
      final barHeight =
          (value * size.height * 0.82).clamp(3.0, size.height * 0.82);
      final x = i * (barWidth + gap);
      final y = (size.height - barHeight) / 2;

      final paint = Paint()
        ..color = active
            ? AppColors.primary.withValues(alpha: 0.35 + value * 0.65)
            : AppColors.border;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.active != active ||
        oldDelegate.barCount != barCount;
  }
}
