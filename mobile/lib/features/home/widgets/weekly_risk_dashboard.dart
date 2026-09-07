import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../models/daily_risk_summary.dart';
import '../patient/widgets/risk_bar_chart.dart';

class WeeklyRiskDashboard extends StatelessWidget {
  const WeeklyRiskDashboard({
    super.key,
    required this.summaries,
    required this.selectedDayIndex,
    required this.onDaySelected,
    this.title = 'Ringkasan Minggu Ini',
    this.subtitle = 'Distribusi risiko per hari',
  });

  final List<DailyRiskSummary> summaries;
  final int selectedDayIndex;
  final ValueChanged<int> onDaySelected;
  final String title;
  final String subtitle;

  String _formatDate(DateTime date) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final selected = summaries[selectedDayIndex.clamp(0, summaries.length - 1)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              RiskBarChart(
                summaries: summaries,
                selectedIndex: selectedDayIndex,
                onDaySelected: onDaySelected,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _LegendDot(color: Color(0xFF81C784), label: 'Rendah'),
                  SizedBox(width: 16),
                  _LegendDot(color: AppColors.primaryLight, label: 'Sedang'),
                  SizedBox(width: 16),
                  _LegendDot(color: AppColors.primary, label: 'Tinggi'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Progress ${_formatDate(selected.date)}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        _ProgressRow(label: 'Rendah', count: selected.lowCount, color: const Color(0xFF81C784)),
        _ProgressRow(label: 'Sedang', count: selected.mediumCount, color: AppColors.primaryLight),
        _ProgressRow(label: 'Tinggi', count: selected.highCount, color: AppColors.primary),
        if (selected.total == 0)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Belum ada sesi tercatat pada hari ini.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            '$count sesi',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
