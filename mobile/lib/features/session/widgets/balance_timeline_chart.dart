import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/session_timeline.dart';

class BalanceTimelineChart extends StatelessWidget {
  const BalanceTimelineChart({
    super.key,
    required this.timeline,
    this.height = 140,
    this.borderless = false,
  });

  final List<MotionTimelinePoint> timeline;
  final double height;
  final bool borderless;

  @override
  Widget build(BuildContext context) {
    if (timeline.isEmpty) {
      return Container(
        height: height + 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: borderless ? null : Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Belum ada data grafik',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      );
    }

    final impactCount = timeline.where((p) => p.isImpact).length;
    final fallCount = timeline.where((p) => p.isFall).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: borderless ? null : Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Grafik Balance',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (impactCount > 0 || fallCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (impactCount > 0) '$impactCount guncangan',
                if (fallCount > 0) '$fallCount kemungkinan jatuh',
              ].join(' · '),
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: height,
            width: double.infinity,
            child: CustomPaint(
              painter: _TimelinePainter(timeline: timeline),
            ),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _LegendItem(color: AppColors.chartBalance, label: 'Gerak balance (SVM)'),
              _LegendItem(color: AppColors.warning, label: 'Guncangan'),
              _LegendItem(color: AppColors.error, label: 'Kemungkinan jatuh'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({required this.timeline});

  final List<MotionTimelinePoint> timeline;

  @override
  void paint(Canvas canvas, Size size) {
    if (timeline.isEmpty) return;

    const padLeft = 8.0;
    const padRight = 8.0;
    const padTop = 8.0;
    const padBottom = 18.0;

    final chartW = size.width - padLeft - padRight;
    final chartH = size.height - padTop - padBottom;
    final maxT = timeline.last.offsetSec.clamp(1, 999999);

    var minV = timeline.first.svm;
    var maxV = timeline.first.svm;
    for (final p in timeline) {
      minV = minV < p.svm ? minV : p.svm;
      maxV = maxV > p.svm ? maxV : p.svm;
    }
    minV = minV < 8.0 ? minV : 8.0;
    maxV = maxV > 12.0 ? maxV : 12.0;
    final range = (maxV - minV).clamp(2.0, 999.0);

    double yForSvm(double svm) => padTop + chartH * (1 - ((svm - minV) / range));
    double xForSec(int sec) => padLeft + (sec / maxT) * chartW;

    final baselineY = yForSvm(9.8);
    canvas.drawLine(
      Offset(padLeft, baselineY),
      Offset(padLeft + chartW, baselineY),
      Paint()
        ..color = AppColors.border
        ..strokeWidth = 1,
    );

    // area fill di bawah garis balance
    final fillPath = Path();
    for (var i = 0; i < timeline.length; i++) {
      final p = timeline[i];
      final x = xForSec(p.offsetSec);
      final y = yForSvm(p.svm);
      if (i == 0) {
        fillPath.moveTo(x, y);
      } else {
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(xForSec(timeline.last.offsetSec), padTop + chartH);
    fillPath.lineTo(xForSec(timeline.first.offsetSec), padTop + chartH);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..color = AppColors.chartBalance.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );

    // garis gerak balance — biru
    final path = Path();
    for (var i = 0; i < timeline.length; i++) {
      final p = timeline[i];
      final x = xForSec(p.offsetSec);
      final y = yForSvm(p.svm);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.chartBalance
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // marker guncangan — tiang oranye dari baseline
    for (final p in timeline) {
      if (!p.isImpact && !p.isFall) continue;
      final x = xForSec(p.offsetSec);
      final y = yForSvm(p.svm);
      final color = p.isFall ? AppColors.error : AppColors.warning;

      canvas.drawLine(
        Offset(x, baselineY),
        Offset(x, y - 6),
        Paint()
          ..color = color.withValues(alpha: 0.55)
          ..strokeWidth = 2,
      );
      canvas.drawCircle(
        Offset(x, y),
        p.isFall ? 5.5 : 4.5,
        Paint()..color = color,
      );
      canvas.drawCircle(
        Offset(x, y),
        p.isFall ? 8 : 7,
        Paint()
          ..color = color.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    _drawLabel(canvas, '0s', padLeft, size.height - 2);
    _drawLabel(canvas, '${maxT}s', padLeft + chartW - 20, size.height - 2);
    _drawLabel(canvas, 'SVM', padLeft, padTop - 2);
  }

  void _drawLabel(Canvas canvas, String text, double x, double y) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 10,
          color: AppColors.textSecondary.withValues(alpha: 0.8),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y - tp.height));
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) {
    return oldDelegate.timeline != timeline;
  }
}
