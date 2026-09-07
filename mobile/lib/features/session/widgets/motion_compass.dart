import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class MotionCompass extends StatelessWidget {
  const MotionCompass({
    super.key,
    required this.displayHeadingRadians,
    required this.headingLabel,
    required this.avmIntensity,
  });

  final double displayHeadingRadians;
  final String headingLabel;
  final double avmIntensity;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _CompassPainter(
          headingRadians: displayHeadingRadians,
          avmIntensity: avmIntensity,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: displayHeadingRadians,
                child: Icon(
                  Icons.navigation_rounded,
                  size: 56,
                  color: AppColors.primary.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                headingLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  _CompassPainter({
    required this.headingRadians,
    required this.avmIntensity,
  });

  final double headingRadians;
  final double avmIntensity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.border,
    );

    // left / right guides
    final guidePaint = Paint()
      ..color = AppColors.textSecondary.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    canvas.drawLine(
      center + Offset(-radius + 8, 0),
      center + Offset(-radius + 20, 0),
      guidePaint,
    );
    canvas.drawLine(
      center + Offset(radius - 20, 0),
      center + Offset(radius - 8, 0),
      guidePaint,
    );

    // top = lurus
    canvas.drawLine(
      center + Offset(0, -radius + 4),
      center + Offset(0, -radius + 18),
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.4)
        ..strokeWidth = 2.5,
    );

    if (avmIntensity > 0.02) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * avmIntensity,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..color =
              AppColors.primary.withValues(alpha: 0.25 + avmIntensity * 0.75),
      );
    }

    final dotOffset = center +
        Offset(sin(headingRadians), -cos(headingRadians)) * (radius * 0.78);
    canvas.drawCircle(dotOffset, 8, Paint()..color = AppColors.primary);
  }

  @override
  bool shouldRepaint(covariant _CompassPainter oldDelegate) {
    return oldDelegate.headingRadians != headingRadians ||
        oldDelegate.avmIntensity != avmIntensity;
  }
}
