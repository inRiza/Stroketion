enum RiskLevel { low, medium, high }

class DailyRiskSummary {
  const DailyRiskSummary({
    required this.date,
    required this.lowCount,
    required this.mediumCount,
    required this.highCount,
  });

  final DateTime date;
  final int lowCount;
  final int mediumCount;
  final int highCount;

  int get total => lowCount + mediumCount + highCount;
}
