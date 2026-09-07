enum SessionRiskLevel { low, medium, high }

extension SessionRiskLevelLabel on SessionRiskLevel {
  static const typeLabel = 'Risiko';

  String get levelLabel {
    switch (this) {
      case SessionRiskLevel.low:
        return 'Rendah';
      case SessionRiskLevel.medium:
        return 'Sedang';
      case SessionRiskLevel.high:
        return 'Tinggi';
    }
  }

  String get label => levelLabel;
}

class MotionTimelinePoint {
  const MotionTimelinePoint({
    required this.offsetSec,
    required this.svm,
    required this.avmDeg,
    this.isImpact = false,
    this.isFall = false,
  });

  final int offsetSec;
  final double svm;
  final double avmDeg;
  final bool isImpact;
  final bool isFall;

  Map<String, dynamic> toJson() => {
        't': offsetSec,
        'svm': svm,
        'avm': avmDeg,
        'impact': isImpact,
        'fall': isFall,
      };

  factory MotionTimelinePoint.fromJson(Map<String, dynamic> json) {
    return MotionTimelinePoint(
      offsetSec: json['t'] as int? ?? json['offset_sec'] as int? ?? 0,
      svm: (json['svm'] as num?)?.toDouble() ?? 9.8,
      avmDeg: (json['avm'] as num?)?.toDouble() ??
          (json['avm_deg'] as num?)?.toDouble() ??
          0,
      isImpact: json['impact'] as bool? ?? false,
      isFall: json['fall'] as bool? ?? false,
    );
  }
}

class RoutePoint {
  const RoutePoint({
    required this.lat,
    required this.lng,
    required this.offsetSec,
  });

  final double lat;
  final double lng;
  final int offsetSec;

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        't': offsetSec,
      };

  factory RoutePoint.fromJson(Map<String, dynamic> json) {
    return RoutePoint(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      offsetSec: json['t'] as int? ?? json['offset_sec'] as int? ?? 0,
    );
  }
}

class SessionScoreResult {
  const SessionScoreResult({
    required this.balanceScore,
    required this.speechScore,
    required this.overallScore,
    required this.riskLevel,
  });

  final int balanceScore;
  final int speechScore;
  final int overallScore;
  final SessionRiskLevel riskLevel;
}
