import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/monitoring_session_record.dart';
import '../models/session_timeline.dart';
import '../models/speech_analysis.dart';
import '../services/session_insights.dart';
import 'emergency_alert_service.dart';
import 'motion_processor.dart';
import 'session_gps_service.dart';
import 'session_scoring.dart';
import 'speech_stream_service.dart';

class SessionSensorService extends ChangeNotifier {
  SessionSensorService({SpeechStreamService? speechStream})
      : _speechStream = speechStream ?? SpeechStreamService();

  static const _waveformCapacity = 40;
  static const _uiNotifyInterval = Duration(milliseconds: 50);

  final _motion = MotionProcessor();
  final _gps = SessionGpsService();
  final SpeechStreamService _speechStream;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  Timer? _elapsedTimer;
  Timer? _uiThrottleTimer;
  bool _motionDirty = false;

  final List<MotionTimelinePoint> _timeline = [];
  int _lastFallCount = 0;
  int _lastImpactCount = 0;
  bool _gpsActive = false;
  DateTime? _lastSosAt;
  static const _speechSosDebounce = Duration(seconds: 5);
  static const _motionSosCooldown = Duration(seconds: 45);

  void Function(String reason)? onHighRisk;

  double _speechLevel = -60;
  bool _speechActive = false;
  String _speechStatusLabel = 'Menghubungkan speech...';
  bool _speechOffline = false;
  final List<double> _waveform = [];

  bool _vadLikely = false;

  int _speechSeconds = 0;
  double _speechLevelSum = 0;
  int _speechLevelCount = 0;
  SpeechAnalysisSummary? _speechSummary;

  String? _monitoringSessionId;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  bool _running = false;

  SessionGpsService get gps => _gps;
  FallState get fallState => _motion.fallDetector.state;
  bool get speechOffline => _speechOffline;
  String get speechStatusLabel => _speechStatusLabel;
  SpeechAnalysisSummary? get speechSummary => _speechSummary;

  SessionLiveMetrics get metrics => SessionLiveMetrics(
        headingRadians: _motion.headingRadians,
        displayHeadingRadians: _motion.displayHeadingRadians,
        headingLabel: SessionInsights.headingLabel(_motion.headingRadians),
        avmDeg: _motion.avmDeg,
        avmIntensity: _motion.avmIntensity,
        svm: _motion.svm,
        posturalDegrees: _motion.posturalDegrees,
        fallState: _motion.fallDetector.state,
        speechLevel: _speechLevel,
        speechActive: _speechActive,
        speechStatusLabel: _speechStatusLabel,
        waveform: List.unmodifiable(_waveform),
        gpsActive: _gpsActive,
        distanceMeters: _gps.distanceMeters,
      );

  Duration get elapsed => _elapsed;
  bool get isRunning => _running;

  Future<bool> start({required SessionSetup setup}) async {
    if (_running) return true;

    final mic = await Permission.microphone.request();
    if (!mic.isGranted) return false;

    _resetStats();
    _monitoringSessionId = DateTime.now().millisecondsSinceEpoch.toString();

    if (setup.location == SessionLocation.outdoor) {
      _gpsActive = await _gps.start();
      _gps.addListener(_onGpsUpdate);
    }

    _running = true;
    _startedAt = DateTime.now();

    _speechStream.onClinicalAlert = _triggerHighRisk;
    _speechStream.addListener(_onSpeechUpdate);
    EmergencyAlertService.instance.addOnStoppedCallback(_onEmergencyAlertStopped);
    final speechOk = await _speechStream.start(
      monitoringSessionId: _monitoringSessionId!,
    );
    _speechOffline = !speechOk;
    _speechStatusLabel = _speechStream.live.statusLabel;

    _motion.fallDetector.onProbableFall = (svm, afterFreeFall) {
      final detail = afterFreeFall ? 'benturan setelah jatuh' : 'benturan kuat';
      _triggerHighRisk(
        'Kemungkinan jatuh, $detail (${svm.toStringAsFixed(0)} m/s²), '
        'tidak ada gerakan',
      );
    };

    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((e) {
      _motion.onAccelerometer(e);
      _motionDirty = true;
    });

    _gyroSub = gyroscopeEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((e) {
      _motion.onGyroscope(e, DateTime.now());
      _motionDirty = true;
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      _motion.calibrateHeading();
      _motionDirty = true;
      notifyListeners();
    });

    _uiThrottleTimer = Timer.periodic(_uiNotifyInterval, (_) {
      if (_motionDirty) {
        _motionDirty = false;
        notifyListeners();
      }
    });

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed = DateTime.now().difference(_startedAt!);
      if (!_speechOffline && (_speechActive || _vadLikely)) _speechSeconds++;
      _speechStream.tickDuration(_elapsed.inSeconds);
      _recordTimelinePoint();
      _checkLiveRisk();
      notifyListeners();
    });

    notifyListeners();
    return true;
  }

  void _onSpeechUpdate() {
    final live = _speechStream.live;
    _speechActive = live.speechActive;
    _vadLikely = live.speechActive || live.vadProb > 0.25;
    _speechLevel = live.energyDbfs;
    _speechStatusLabel = live.statusLabel;
    _speechOffline = live.offline;

    if (_speechActive) {
      _speechLevelSum += _speechLevel;
      _speechLevelCount++;
    }

    final normalized = math.max(
      live.vadProb.clamp(0.0, 1.0),
      _speechStream.localMicLevel,
    );
    _waveform.add(normalized);
    if (_waveform.length > _waveformCapacity) {
      _waveform.removeAt(0);
    }

    if (_speechStream.summary != null) {
      _speechSummary = _speechStream.summary;
    }

    notifyListeners();
  }

  void _onGpsUpdate() => notifyListeners();

  void _recordTimelinePoint() {
    if (_startedAt == null) return;

    final offset = _elapsed.inSeconds;
    final impactNow = _motion.impactEvents;
    final isImpact = impactNow > _lastImpactCount;
    _lastImpactCount = impactNow;

    final fallNow = _motion.fallEvents;
    final isFall = fallNow > _lastFallCount;
    _lastFallCount = fallNow;

    _timeline.add(MotionTimelinePoint(
      offsetSec: offset,
      svm: _motion.svm,
      avmDeg: _motion.avmDeg,
      isImpact: isImpact,
      isFall: isFall,
    ));
  }

  Future<MonitoringSessionRecord?> stop({
    required SessionSetup setup,
  }) async {
    if (!_running || _startedAt == null) return null;

    _running = false;
    await _accelSub?.cancel();
    await _gyroSub?.cancel();
    _elapsedTimer?.cancel();
    _uiThrottleTimer?.cancel();

    final durationSec = DateTime.now().difference(_startedAt!).inSeconds;
    _speechSummary = await _speechStream.stop(durationSeconds: durationSec);
    _speechSummary = _applyPeakSpeechAlert(_speechSummary);
    EmergencyAlertService.instance.removeOnStoppedCallback(_onEmergencyAlertStopped);
    _speechStream.removeListener(_onSpeechUpdate);

    if (_gpsActive) {
      _gps.removeListener(_onGpsUpdate);
      await _gps.stop();
    }

    final endedAt = DateTime.now();
    final speechSeconds = _resolveSpeechSeconds();
    final avgSpeech = _speechLevelCount == 0
        ? 0
        : _speechLevelSum / _speechLevelCount;

    final draft = MonitoringSessionRecord(
      id: _monitoringSessionId ?? endedAt.millisecondsSinceEpoch.toString(),
      startedAt: _startedAt!,
      endedAt: endedAt,
      location: setup.location,
      activity: setup.activity,
      durationSeconds: durationSec,
      avgSvm: _motion.avgSvm,
      maxSvm: _motion.maxSvm,
      avgAvmDeg: _motion.avgAvmDeg,
      maxAvmDeg: _motion.maxAvmDeg,
      maxTiltDegrees: _motion.maxTiltDegrees,
      maxHeadingDeviationDeg: _motion.maxHeadingDeviationDeg,
      fallEvents: _motion.fallEvents,
      impactEvents: _motion.impactEvents,
      speechDetectedSeconds: speechSeconds,
      avgSpeechLevel: avgSpeech.toDouble(),
      balanceScore: 0,
      speechScore: _speechOffline ? 100 : (_speechSummary?.speechScore ?? 100),
      overallScore: 0,
      riskLevel: SessionRiskLevel.low,
      timeline: List.from(_timeline),
      route: List.from(_gps.route),
      distanceMeters: _gps.distanceMeters,
      gpsActive: _gpsActive,
      speechAnalysis: _speechSummary,
    );

    final scores = SessionScoring.compute(draft);
    final record = MonitoringSessionRecord(
      id: draft.id,
      startedAt: draft.startedAt,
      endedAt: draft.endedAt,
      location: draft.location,
      activity: draft.activity,
      durationSeconds: draft.durationSeconds,
      avgSvm: draft.avgSvm,
      maxSvm: draft.maxSvm,
      avgAvmDeg: draft.avgAvmDeg,
      maxAvmDeg: draft.maxAvmDeg,
      maxTiltDegrees: draft.maxTiltDegrees,
      maxHeadingDeviationDeg: draft.maxHeadingDeviationDeg,
      fallEvents: draft.fallEvents,
      impactEvents: draft.impactEvents,
      speechDetectedSeconds: draft.speechDetectedSeconds,
      avgSpeechLevel: draft.avgSpeechLevel,
      balanceScore: scores.balanceScore,
      speechScore: draft.speechScore,
      overallScore: SessionScoring.computeOverall(
        scores.balanceScore,
        draft.speechScore,
      ),
      riskLevel: SessionScoring.computeRisk(
        overall: SessionScoring.computeOverall(
          scores.balanceScore,
          draft.speechScore,
        ),
        balance: scores.balanceScore,
        speechScore: draft.speechScore,
        record: draft,
      ),
      timeline: draft.timeline,
      route: draft.route,
      distanceMeters: draft.distanceMeters,
      gpsActive: draft.gpsActive,
      speechAnalysis: draft.speechAnalysis,
    );

    _startedAt = null;
    _elapsed = Duration.zero;
    notifyListeners();
    return record;
  }

  void _checkLiveRisk() {
    if (_startedAt == null) return;

    final draft = MonitoringSessionRecord(
      id: 'live',
      startedAt: _startedAt!,
      endedAt: DateTime.now(),
      location: SessionLocation.home,
      activity: SessionActivity.daily,
      durationSeconds: _elapsed.inSeconds.clamp(1, 999999),
      avgSvm: _motion.avgSvm,
      maxSvm: _motion.maxSvm,
      avgAvmDeg: _motion.avgAvmDeg,
      maxAvmDeg: _motion.maxAvmDeg,
      maxTiltDegrees: _motion.maxTiltDegrees,
      maxHeadingDeviationDeg: _motion.maxHeadingDeviationDeg,
      fallEvents: _motion.fallEvents,
      impactEvents: _motion.impactEvents,
      speechDetectedSeconds: _speechSeconds,
      avgSpeechLevel:
          _speechLevelCount == 0 ? 0 : _speechLevelSum / _speechLevelCount,
      balanceScore: 0,
      speechScore: _speechOffline ? 100 : 80,
      overallScore: 0,
      riskLevel: SessionRiskLevel.low,
      timeline: const [],
      route: const [],
      distanceMeters: 0,
      gpsActive: false,
    );

    final scores = SessionScoring.compute(draft);
    if (scores.riskLevel == SessionRiskLevel.high) {
      _triggerHighRisk('Risiko tinggi terdeteksi (skor ${scores.overallScore})');
    }
  }

  Future<void> resumeSpeechAfterSos() async {
    await _speechStream.recoverAfterInterruption();
    // siap deteksi SOS berikutnya setelah user menutup popup
    _lastSosAt = null;
    _speechActive = _speechStream.live.speechActive;
    _vadLikely = _speechStream.live.speechActive ||
        _speechStream.live.vadProb > 0.25 ||
        _speechStream.localMicLevel > 0.08;
    _speechStatusLabel = _speechStream.live.offline
        ? 'Menyambungkan kembali...'
        : _speechStream.live.statusLabel;
    notifyListeners();
  }

  Future<void> _onEmergencyAlertStopped() async {
    if (!_running) return;
    await _speechStream.recoverAfterInterruption();
    if (_running) {
      _speechActive = _speechStream.live.speechActive;
      _vadLikely = _speechStream.live.speechActive ||
          _speechStream.live.vadProb > 0.25 ||
          _speechStream.localMicLevel > 0.08;
      notifyListeners();
    }
  }

  SpeechAnalysisSummary? _applyPeakSpeechAlert(SpeechAnalysisSummary? summary) {
    if (summary == null) return summary;
    final peak = _speechStream.peakClinicalAlert;
    if (peak == null) return summary;
    final flagsRaw = peak['flags'] as List<dynamic>? ?? [];
    final enriched = (summary.offline ? SpeechAnalysisSummary(
          vadActiveSeconds: summary.vadActiveSeconds,
          confirmedSeconds: summary.confirmedSeconds,
        ) : summary)
        .withLiveAlertFallback(
      peakSeverity: peak['severity'] as String?,
      peakReason: peak['reason'] as String?,
      peakFlags: flagsRaw.map((e) => e.toString()).toList(),
    );
    return enriched;
  }

  void _triggerHighRisk(String reason) {
    final now = DateTime.now();
    final isMotion = reason.contains('jatuh') ||
        reason.contains('benturan') ||
        reason.contains('Risiko tinggi');
    final cooldown = isMotion ? _motionSosCooldown : _speechSosDebounce;
    if (_lastSosAt != null && now.difference(_lastSosAt!) < cooldown) {
      return;
    }
    _lastSosAt = now;
    onHighRisk?.call(reason);
  }

  int _resolveSpeechSeconds() {
    if (_speechOffline) return 0;
    final summary = _speechSummary;
    final fromSummary = summary != null && !summary.offline
        ? summary.detectedSeconds
        : 0;
    if (fromSummary > _speechSeconds) return fromSummary;
    return _speechSeconds;
  }

  void _resetStats() {
    _motion.reset();
    _motion.fallDetector.onProbableFall = null;
    _timeline.clear();
    _lastFallCount = 0;
    _lastImpactCount = 0;
    _lastSosAt = null;
    _gpsActive = false;
    _speechLevel = -60;
    _speechActive = false;
    _vadLikely = false;
    _speechStatusLabel = 'Menghubungkan speech...';
    _speechOffline = false;
    _speechSummary = null;
    _waveform.clear();
    _speechSeconds = 0;
    _speechLevelSum = 0;
    _speechLevelCount = 0;
    _elapsed = Duration.zero;
    _motionDirty = false;
    _monitoringSessionId = null;
  }

  @override
  void dispose() {
    EmergencyAlertService.instance.removeOnStoppedCallback(_onEmergencyAlertStopped);
    _gps.removeListener(_onGpsUpdate);
    _speechStream.removeListener(_onSpeechUpdate);
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _elapsedTimer?.cancel();
    _uiThrottleTimer?.cancel();
    _gps.dispose();
    _speechStream.dispose();
    super.dispose();
  }
}
