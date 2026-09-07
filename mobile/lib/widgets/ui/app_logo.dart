import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum AppLogoVariant {
  onRed,
  onWhite,
}

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    required this.variant,
    this.height = 56,
  });

  final AppLogoVariant variant;
  final double height;

  @override
  Widget build(BuildContext context) {
    final asset = variant == AppLogoVariant.onRed
        ? 'assets/logo/logo_w.svg'
        : 'assets/logo/logo_r.svg';

    return SvgPicture.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
    );
  }
}
