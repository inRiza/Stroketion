import '../models/daily_risk_summary.dart';
import '../models/session_timeline.dart';

class SessionRiskPoint {
  const SessionRiskPoint({required this.startedAt, required this.riskLevel});

  final DateTime startedAt;
  final SessionRiskLevel riskLevel;
}

List<DailyRiskSummary> buildWeeklyRiskSummaries(List<SessionRiskPoint> sessions) {
  final today = DateTime.now();
  final startOfToday = DateTime(today.year, today.month, today.day);

  return List.generate(7, (i) {
    final day = startOfToday.subtract(Duration(days: 6 - i));
    var low = 0;
    var medium = 0;
    var high = 0;

    for (final session in sessions) {
      final sessionDay = DateTime(
        session.startedAt.year,
        session.startedAt.month,
        session.startedAt.day,
      );
      if (sessionDay != day) continue;

      switch (session.riskLevel) {
        case SessionRiskLevel.low:
          low++;
        case SessionRiskLevel.medium:
          medium++;
        case SessionRiskLevel.high:
          high++;
      }
    }

    return DailyRiskSummary(
      date: day,
      lowCount: low,
      mediumCount: medium,
      highCount: high,
    );
  });
}
