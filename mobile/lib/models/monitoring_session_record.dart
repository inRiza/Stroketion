import 'session_timeline.dart';
import 'speech_analysis.dart';

enum SessionLocation { home, outdoor }

enum SessionActivity { daily, exercise }

extension SessionLocationLabel on SessionLocation {
  String get label {
    switch (this) {
      case SessionLocation.home:
        return 'Di rumah';
      case SessionLocation.outdoor:
        return 'Di luar';
    }
  }
}

extension SessionActivityLabel on SessionActivity {
  String get label {
    switch (this) {
      case SessionActivity.daily:
        return 'Sehari-hari';
      case SessionActivity.exercise:
        return 'Olahraga';
    }
  }
}

class SessionSetup {
  const SessionSetup({
    required this.location,
    required this.activity,
  });

  final SessionLocation location;
  final SessionActivity activity;
}

class MonitoringSessionRecord {
  const MonitoringSessionRecord({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.location,
    required this.activity,
    required this.durationSeconds,
    required this.avgSvm,
    required this.maxSvm,
    required this.avgAvmDeg,
    required this.maxAvmDeg,
    required this.maxTiltDegrees,
    required this.maxHeadingDeviationDeg,
    required this.fallEvents,
    required this.impactEvents,
    required this.speechDetectedSeconds,
    required this.avgSpeechLevel,
    required this.balanceScore,
    required this.speechScore,
    required this.overallScore,
    required this.riskLevel,
    required this.timeline,
    required this.route,
    required this.distanceMeters,
    required this.gpsActive,
    this.speechAnalysis,
  });

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final SessionLocation location;
  final SessionActivity activity;
  final int durationSeconds;
  final double avgSvm;
  final double maxSvm;
  final double avgAvmDeg;
  final double maxAvmDeg;
  final double maxTiltDegrees;
  final double maxHeadingDeviationDeg;
  final int fallEvents;
  final int impactEvents;
  final int speechDetectedSeconds;
  final double avgSpeechLevel;
  final int balanceScore;
  final int speechScore;
  final int overallScore;
  final SessionRiskLevel riskLevel;
  final List<MotionTimelinePoint> timeline;
  final List<RoutePoint> route;
  final double distanceMeters;
  final bool gpsActive;
  final SpeechAnalysisSummary? speechAnalysis;

  Duration get duration => Duration(seconds: durationSeconds);

  Map<String, dynamic> toJson() => {
        'id': id,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt.toIso8601String(),
        'location': location.name,
        'activity': activity.name,
        'duration_seconds': durationSeconds,
        'avg_svm': avgSvm,
        'max_svm': maxSvm,
        'avg_avm_deg': avgAvmDeg,
        'max_avm_deg': maxAvmDeg,
        'max_tilt_degrees': maxTiltDegrees,
        'max_heading_deviation_deg': maxHeadingDeviationDeg,
        'fall_events': fallEvents,
        'impact_events': impactEvents,
        'speech_detected_seconds': speechDetectedSeconds,
        'avg_speech_level': avgSpeechLevel,
        'balance_score': balanceScore,
        'speech_score': speechScore,
        'overall_score': overallScore,
        'risk_level': riskLevel.name,
        'timeline': timeline.map((e) => e.toJson()).toList(),
        'route': route.map((e) => e.toJson()).toList(),
        'distance_meters': distanceMeters,
        'gps_active': gpsActive,
        if (speechAnalysis != null) 'speech_analysis': speechAnalysis!.toJson(),
      };

  factory MonitoringSessionRecord.fromJson(Map<String, dynamic> json) {
    final timelineRaw = json['timeline'] as List<dynamic>? ?? [];
    final routeRaw = json['route'] as List<dynamic>? ?? [];

    return MonitoringSessionRecord(
      id: json['id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: DateTime.parse(json['ended_at'] as String),
      location: SessionLocation.values.byName(json['location'] as String),
      activity: SessionActivity.values.byName(json['activity'] as String),
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      avgSvm: (json['avg_svm'] as num?)?.toDouble() ?? 9.8,
      maxSvm: (json['max_svm'] as num?)?.toDouble() ?? 0,
      avgAvmDeg: (json['avg_avm_deg'] as num?)?.toDouble() ??
          (json['avg_gyro_magnitude'] as num?)?.toDouble() ??
          0,
      maxAvmDeg: (json['max_avm_deg'] as num?)?.toDouble() ?? 0,
      maxTiltDegrees: (json['max_tilt_degrees'] as num?)?.toDouble() ?? 0,
      maxHeadingDeviationDeg:
          (json['max_heading_deviation_deg'] as num?)?.toDouble() ?? 0,
      fallEvents: json['fall_events'] as int? ?? 0,
      impactEvents: json['impact_events'] as int? ?? 0,
      speechDetectedSeconds: json['speech_detected_seconds'] as int? ?? 0,
      avgSpeechLevel: (json['avg_speech_level'] as num?)?.toDouble() ?? 0,
      balanceScore: json['balance_score'] as int? ?? 80,
      speechScore: json['speech_score'] as int? ?? 90,
      overallScore: json['overall_score'] as int? ?? 85,
      riskLevel: SessionRiskLevel.values.byName(
        (json['risk_level'] as String? ?? 'low').toLowerCase(),
      ),
      timeline: timelineRaw
          .map((e) => MotionTimelinePoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      route: routeRaw
          .map((e) => RoutePoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0,
      gpsActive: json['gps_active'] as bool? ?? false,
      speechAnalysis: json['speech_analysis'] != null
          ? SpeechAnalysisSummary.fromJson(
              json['speech_analysis'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

enum FallState { normal, falling, impactDetected, fallConfirmed }

extension FallStateLabel on FallState {
  String get label {
    switch (this) {
      case FallState.normal:
        return 'Normal';
      case FallState.falling:
        return 'Free-fall terdeteksi';
      case FallState.impactDetected:
        return 'Impact terdeteksi';
      case FallState.fallConfirmed:
        return 'Kemungkinan jatuh';
    }
  }
}

class SessionLiveMetrics {
  const SessionLiveMetrics({
    this.headingRadians = 0,
    this.displayHeadingRadians = 0,
    this.headingLabel = 'Lurus',
    this.avmDeg = 0,
    this.avmIntensity = 0,
    this.svm = 9.8,
    this.posturalDegrees = 0,
    this.fallState = FallState.normal,
    this.speechLevel = 0,
    this.speechActive = false,
    this.speechStatusLabel = '',
    this.waveform = const [],
    this.gpsActive = false,
    this.distanceMeters = 0,
  });

  final double headingRadians;
  final double displayHeadingRadians;
  final String headingLabel;
  final double avmDeg;
  final double avmIntensity;
  final double svm;
  final double posturalDegrees;
  final FallState fallState;
  final double speechLevel;
  final bool speechActive;
  final String speechStatusLabel;
  final List<double> waveform;
  final bool gpsActive;
  final double distanceMeters;
}
