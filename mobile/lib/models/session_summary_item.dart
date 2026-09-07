import 'monitoring_session_record.dart';
import 'session_timeline.dart';

/// Ringkasan sesi dari API (tanpa timeline lengkap).
class SessionSummaryItem {
  const SessionSummaryItem({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.location,
    required this.activity,
    required this.durationSeconds,
    required this.balanceScore,
    required this.speechScore,
    required this.overallScore,
    required this.riskLevel,
    this.patientName,
    this.patientId,
  });

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final SessionLocation location;
  final SessionActivity activity;
  final int durationSeconds;
  final int balanceScore;
  final int speechScore;
  final int overallScore;
  final SessionRiskLevel riskLevel;
  final String? patientName;
  final String? patientId;

  Duration get duration => Duration(seconds: durationSeconds);

  factory SessionSummaryItem.fromJson(
    Map<String, dynamic> json, {
    String? patientName,
    String? patientId,
  }) {
    return SessionSummaryItem(
      id: json['id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: DateTime.parse(json['ended_at'] as String),
      location: SessionLocation.values.byName(json['location'] as String),
      activity: SessionActivity.values.byName(json['activity'] as String),
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      balanceScore: json['balance_score'] as int? ?? 0,
      speechScore: json['speech_score'] as int? ?? 0,
      overallScore: json['overall_score'] as int? ?? 0,
      riskLevel: SessionRiskLevel.values.byName(
        (json['risk_level'] as String? ?? 'low').toLowerCase(),
      ),
      patientName: patientName,
      patientId: patientId,
    );
  }

  MonitoringSessionRecord toListRecord() {
    return MonitoringSessionRecord(
      id: id,
      startedAt: startedAt,
      endedAt: endedAt,
      location: location,
      activity: activity,
      durationSeconds: durationSeconds,
      avgSvm: 0,
      maxSvm: 0,
      avgAvmDeg: 0,
      maxAvmDeg: 0,
      maxTiltDegrees: 0,
      maxHeadingDeviationDeg: 0,
      fallEvents: 0,
      impactEvents: 0,
      speechDetectedSeconds: 0,
      avgSpeechLevel: 0,
      balanceScore: balanceScore,
      speechScore: speechScore,
      overallScore: overallScore,
      riskLevel: riskLevel,
      timeline: const [],
      route: const [],
      distanceMeters: 0,
      gpsActive: false,
    );
  }
}
