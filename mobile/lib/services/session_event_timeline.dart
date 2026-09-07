import '../models/monitoring_session_record.dart';
import '../models/session_timeline.dart';
import '../models/speech_analysis.dart';

enum SessionEventSeverity { info, low, medium, high }

class SessionTimelineEvent {
  const SessionTimelineEvent({
    required this.offsetSec,
    required this.title,
    required this.severity,
    this.subtitle,
    this.category = 'session',
  });

  final int offsetSec;
  final String title;
  final String? subtitle;
  final SessionEventSeverity severity;
  final String category;
}

class SessionEventTimeline {
  SessionEventTimeline._();

  static List<SessionTimelineEvent> build(MonitoringSessionRecord record) {
    final events = <SessionTimelineEvent>[];

    events.add(
      const SessionTimelineEvent(
        offsetSec: 0,
        title: 'Sesi dimulai',
        subtitle: 'Monitoring balance dan speech aktif',
        severity: SessionEventSeverity.info,
        category: 'session',
      ),
    );

    _addMotionEvents(events, record.timeline);
    _addSpeechEvents(events, record);

    events.add(
      SessionTimelineEvent(
        offsetSec: record.durationSeconds,
        title: 'Sesi selesai',
        subtitle: 'Risiko ${record.riskLevel.levelLabel}, skor ${record.overallScore}',
        severity: _riskSeverity(record.riskLevel),
        category: 'session',
      ),
    );

    events.sort((a, b) {
      final cmp = a.offsetSec.compareTo(b.offsetSec);
      if (cmp != 0) return cmp;
      return _severityRank(b.severity).compareTo(_severityRank(a.severity));
    });

    return events;
  }

  static void _addMotionEvents(
    List<SessionTimelineEvent> events,
    List<MotionTimelinePoint> timeline,
  ) {
    for (final point in timeline) {
      if (point.isFall) {
        events.add(
          SessionTimelineEvent(
            offsetSec: point.offsetSec,
            title: 'Kemungkinan jatuh',
            subtitle: 'Guncangan kuat lalu gerak minimal (deviasi SVM)',
            severity: SessionEventSeverity.high,
            category: 'motion',
          ),
        );
      } else if (point.isImpact) {
        events.add(
          SessionTimelineEvent(
            offsetSec: point.offsetSec,
            title: 'Guncangan terdeteksi',
            subtitle: 'Puncak percepatan ${point.svm.toStringAsFixed(1)} m/s²',
            severity: SessionEventSeverity.medium,
            category: 'motion',
          ),
        );
      }
    }
  }

  static void _addSpeechEvents(
    List<SessionTimelineEvent> events,
    MonitoringSessionRecord record,
  ) {
    final analysis = record.speechAnalysis;

    if (analysis == null || analysis.offline) {
      if (record.durationSeconds > 60) {
        events.add(
          const SessionTimelineEvent(
            offsetSec: 0,
            title: 'Analisis speech offline',
            subtitle: 'Pipeline backend tidak tersedia selama sesi',
            severity: SessionEventSeverity.info,
            category: 'speech',
          ),
        );
      }
      return;
    }

    if (record.speechDetectedSeconds == 0 && record.durationSeconds > 60) {
      events.add(
        const SessionTimelineEvent(
          offsetSec: 0,
          title: 'Tidak ada suara terdeteksi',
          subtitle: 'VAD tidak mengonfirmasi bicara selama sesi',
          severity: SessionEventSeverity.info,
          category: 'speech',
        ),
      );
    }

    if (analysis.dysarthriaRisk == 'high' ||
        analysis.dysarthriaRisk == 'medium') {
      events.add(
        SessionTimelineEvent(
          offsetSec: _speechRiskOffset(analysis),
          title: 'Indikasi deviasi artikulasi',
          subtitle: 'Disartria ${analysis.dysarthriaRiskLabel.replaceAll('Disartria: ', '')}',
          severity: analysis.dysarthriaRisk == 'high'
              ? SessionEventSeverity.high
              : SessionEventSeverity.medium,
          category: 'speech',
        ),
      );
    }

    if (analysis.aphasiaRisk == 'high' || analysis.aphasiaRisk == 'medium') {
      events.add(
        SessionTimelineEvent(
          offsetSec: _speechRiskOffset(analysis),
          title: 'Indikasi disfluensi ucapan',
          subtitle: analysis.aphasiaRiskLabel.replaceAll('Afasia/fluensi: ', ''),
          severity: analysis.aphasiaRisk == 'high'
              ? SessionEventSeverity.high
              : SessionEventSeverity.medium,
          category: 'speech',
        ),
      );
    }

    for (final seg in analysis.clinicalSegments) {
      events.add(
        SessionTimelineEvent(
          offsetSec: seg.offsetSec,
          title: 'Rekaman SOS tersedia',
          subtitle: '${seg.label} (${seg.timeLabel})',
          severity: SessionEventSeverity.high,
          category: 'speech',
        ),
      );
    }
  }

  static int _speechRiskOffset(SpeechAnalysisSummary analysis) {
    if (analysis.clinicalSegments.isNotEmpty) {
      return analysis.clinicalSegments.first.offsetSec;
    }
    return 0;
  }

  static SessionEventSeverity _riskSeverity(SessionRiskLevel level) {
    switch (level) {
      case SessionRiskLevel.high:
        return SessionEventSeverity.high;
      case SessionRiskLevel.medium:
        return SessionEventSeverity.medium;
      case SessionRiskLevel.low:
        return SessionEventSeverity.low;
    }
  }

  static int _severityRank(SessionEventSeverity s) {
    switch (s) {
      case SessionEventSeverity.high:
        return 3;
      case SessionEventSeverity.medium:
        return 2;
      case SessionEventSeverity.low:
        return 1;
      case SessionEventSeverity.info:
        return 0;
    }
  }

  static String formatOffset(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
