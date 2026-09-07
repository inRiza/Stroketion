import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class WaveBackground extends StatelessWidget {
  const WaveBackground({
    super.key,
    required this.child,
    this.fullScreen = false,
  });

  final Widget child;
  final bool fullScreen;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: AppColors.primary),
        CustomPaint(
          painter: _WavePainter(fullScreen: fullScreen),
          size: Size.infinite,
        ),
        child,
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter({required this.fullScreen});

  final bool fullScreen;

  @override
  void paint(Canvas canvas, Size size) {
    if (fullScreen) {
      _paintFullScreenWaves(canvas, size);
    } else {
      _paintHeaderWaves(canvas, size);
    }
  }

  void _paintFullScreenWaves(Canvas canvas, Size size) {
    final wave1 = Paint()..color = AppColors.waveDark.withValues(alpha: 0.35);
    final wave2 = Paint()..color = AppColors.waveMid.withValues(alpha: 0.25);

    final path1 = Path()
      ..moveTo(0, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.48,
        size.width * 0.65,
        size.height * 0.58,
      )
      ..quadraticBezierTo(
        size.width * 0.9,
        size.height * 0.66,
        size.width,
        size.height * 0.52,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path1, wave1);

    final path2 = Path()
      ..moveTo(0, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.65,
        size.width * 0.75,
        size.height * 0.74,
      )
      ..quadraticBezierTo(
        size.width,
        size.height * 0.8,
        size.width,
        size.height * 0.68,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path2, wave2);
  }

  void _paintHeaderWaves(Canvas canvas, Size size) {
    final paint1 = Paint()..color = AppColors.waveDark;
    final paint2 = Paint()..color = AppColors.waveMid;
    final paint3 = Paint()..color = AppColors.primary;

    final path1 = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.75,
        size.width * 0.5,
        size.height * 0.65,
      )
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.55,
        0,
        size.height * 0.7,
      )
      ..close();
    canvas.drawPath(path1, paint1);

    final path2 = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.45)
      ..quadraticBezierTo(
        size.width * 0.7,
        size.height * 0.65,
        size.width * 0.45,
        size.height * 0.55,
      )
      ..quadraticBezierTo(
        size.width * 0.2,
        size.height * 0.45,
        0,
        size.height * 0.6,
      )
      ..close();
    canvas.drawPath(path2, paint2);

    final path3 = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.35)
      ..quadraticBezierTo(
        size.width * 0.65,
        size.height * 0.55,
        size.width * 0.4,
        size.height * 0.45,
      )
      ..quadraticBezierTo(
        size.width * 0.15,
        size.height * 0.35,
        0,
        size.height * 0.5,
      )
      ..close();
    canvas.drawPath(path3, paint3);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.fullScreen != fullScreen;
}
