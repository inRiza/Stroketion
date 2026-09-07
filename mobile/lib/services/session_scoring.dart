import '../models/monitoring_session_record.dart';
import '../models/session_timeline.dart';

class SessionScoring {
  SessionScoring._();

  static SessionScoreResult compute(MonitoringSessionRecord record) {
    var balance = 100;

    balance -= record.fallEvents * 35;
    balance -= record.impactEvents * 12;
    if (record.maxSvm > 30) {
      balance -= 8;
    } else if (record.maxSvm > 25) {
      balance -= 5;
    }
    if (record.maxAvmDeg > 200) balance -= 8;
    if (record.maxHeadingDeviationDeg > 45) balance -= 5;
    if (record.maxTiltDegrees > 60) balance -= 5;

    balance = balance.clamp(0, 100);
    final speech = record.speechAnalysis != null && !record.speechAnalysis!.offline
        ? record.speechScore
        : _computeLocalSpeechScore(record);
    final overall = computeOverall(balance, speech);

    final risk = computeRisk(
      overall: overall,
      balance: balance,
      speechScore: speech,
      record: record,
    );

    return SessionScoreResult(
      balanceScore: balance,
      speechScore: speech,
      overallScore: overall,
      riskLevel: risk,
    );
  }

  static int _computeLocalSpeechScore(MonitoringSessionRecord record) {
    var speech = 100;
    if (record.durationSeconds > 120 && record.speechDetectedSeconds == 0) {
      speech -= 10;
    } else if (record.durationSeconds > 0) {
      final ratio = record.speechDetectedSeconds / record.durationSeconds;
      if (ratio < 0.05) speech -= 5;
    }
    return speech.clamp(0, 100);
  }

  static int computeOverall(int balance, int speech) {
    return ((balance * 0.65) + (speech * 0.35)).round().clamp(0, 100);
  }

  static SessionRiskLevel computeRisk({
    required int overall,
    required int balance,
    required int speechScore,
    required MonitoringSessionRecord record,
  }) {
    return _riskLevel(
      overall: overall,
      balance: balance,
      record: record,
    );
  }

  static SessionRiskLevel _riskLevel({
    required int overall,
    required int balance,
    required MonitoringSessionRecord record,
  }) {
    final speech = record.speechAnalysis;
    if (speech != null && !speech.offline) {
      if (speech.dysarthriaRisk == 'high' || speech.aphasiaRisk == 'high') {
        return SessionRiskLevel.high;
      }
      if (speech.dysarthriaRisk == 'medium' || speech.aphasiaRisk == 'medium') {
        if (overall < 75 || speech.clinicalSegments.isNotEmpty) {
          return SessionRiskLevel.high;
        }
        return SessionRiskLevel.medium;
      }
    }

    // kemungkinan jatuh = guncangan kuat diikuti tidak bergerak
    if (record.fallEvents > 0 || overall < 45) {
      return SessionRiskLevel.high;
    }
    // guncangan berulang yang sudah menekan skor keseimbangan
    if (record.impactEvents >= 3 && balance < 60) {
      return SessionRiskLevel.high;
    }
    if (balance < 50) {
      return SessionRiskLevel.high;
    }
    if (overall < 70 || record.impactEvents > 0 || record.maxSvm > 25) {
      return SessionRiskLevel.medium;
    }
    return SessionRiskLevel.low;
  }
}
