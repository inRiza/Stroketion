import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/daily_risk_summary.dart';

class RiskBarChart extends StatelessWidget {
  const RiskBarChart({
    super.key,
    required this.summaries,
    this.selectedIndex,
    this.onDaySelected,
  });

  final List<DailyRiskSummary> summaries;
  final int? selectedIndex;
  final ValueChanged<int>? onDaySelected;

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(
          child: Text(
            'Belum ada data sesi',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final maxTotal = summaries.map((s) => s.total).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(summaries.length, (index) {
          final summary = summaries[index];
          final isSelected = selectedIndex == index;
          final barMaxHeight = 120.0;

          return Expanded(
            child: GestureDetector(
              onTap: () => onDaySelected?.call(index),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _StackedBar(
                      summary: summary,
                      maxTotal: maxTotal == 0 ? 1 : maxTotal,
                      maxHeight: barMaxHeight,
                      isSelected: isSelected,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _dayLabel(summary.date),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  String _dayLabel(DateTime date) {
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return days[date.weekday - 1];
  }
}

class _StackedBar extends StatelessWidget {
  const _StackedBar({
    required this.summary,
    required this.maxTotal,
    required this.maxHeight,
    required this.isSelected,
  });

  final DailyRiskSummary summary;
  final int maxTotal;
  final double maxHeight;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final scale = summary.total / maxTotal;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      height: maxHeight * scale.clamp(0.08, 1.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: isSelected ? Border.all(color: AppColors.primary, width: 2) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: summary.total == 0
          ? Container(color: AppColors.border)
          : Column(
              children: [
                if (summary.highCount > 0)
                  Expanded(
                    flex: summary.highCount,
                    child: Container(color: AppColors.primary),
                  ),
                if (summary.mediumCount > 0)
                  Expanded(
                    flex: summary.mediumCount,
                    child: Container(color: AppColors.primaryLight),
                  ),
                if (summary.lowCount > 0)
                  Expanded(
                    flex: summary.lowCount,
                    child: Container(color: const Color(0xFF81C784)),
                  ),
              ],
            ),
    );
  }
}
