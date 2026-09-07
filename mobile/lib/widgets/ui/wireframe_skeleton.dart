import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class WireframeSkeleton extends StatelessWidget {
  const WireframeSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.radius = 6,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class SessionHistorySkeleton extends StatelessWidget {
  const SessionHistorySkeleton({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count, (i) {
        return Container(
          margin: EdgeInsets.only(bottom: i == count - 1 ? 0 : 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              WireframeSkeleton(width: 44, height: 44, radius: 22),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WireframeSkeleton(width: double.infinity, height: 14),
                    SizedBox(height: 8),
                    WireframeSkeleton(width: 100, height: 12),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
