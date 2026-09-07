import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

import '../models/monitoring_session_record.dart';

/// Deteksi guncangan dan kemungkinan jatuh.
///
/// Konfirmasi jatuh secara pasti tidak mungkin dari accelerometer saja, jadi
/// pendekatannya: guncangan kuat yang diikuti tubuh tidak bergerak = kemungkinan jatuh.
/// Free-fall sebelum benturan menaikkan keyakinan, tapi bukan syarat wajib
/// (HP di kantong sering tidak mencatat free-fall).
class FallDetector {
  FallState _state = FallState.normal;
  DateTime? _stateChangedAt;

  final List<double> _svmBuffer = [];
  static const _bufferMaxSize = 100;

  static const freeFallThreshold = 2.0;

  /// Guncangan tercatat untuk timeline dan skor keseimbangan.
  static const impactThreshold = 25.0;

  /// Guncangan cukup kuat untuk dianggap kandidat jatuh.
  static const severeImpactThreshold = 30.0;

  /// Rotasi tubuh saat benturan — menandakan terpelanting, bukan HP tersenggol.
  static const rotationThreshold = 60.0;

  static const inactivityVarianceThreshold = 1.5;
  static const _postImpactWindow = Duration(milliseconds: 2500);

  int fallConfirmedCount = 0;
  int impactDetectedCount = 0;
  int severeImpactCount = 0;
  double _lastAvmDeg = 0;
  double _lastImpactSvm = 0;
  bool _impactAfterFreeFall = false;
  bool _impactHadRotation = false;

  /// Kemungkinan jatuh: guncangan kuat lalu tidak bergerak.
  void Function(double svm, bool afterFreeFall)? onProbableFall;

  FallState get state => _state;
  double get lastImpactSvm => _lastImpactSvm;

  void reset() {
    _state = FallState.normal;
    _stateChangedAt = null;
    _svmBuffer.clear();
    fallConfirmedCount = 0;
    impactDetectedCount = 0;
    severeImpactCount = 0;
    _lastAvmDeg = 0;
    _lastImpactSvm = 0;
    _impactAfterFreeFall = false;
    _impactHadRotation = false;
  }

  void onAvm(double avmDeg) => _lastAvmDeg = avmDeg;

  void onPosturalDegrees(double deg) {}

  void onSvm(double svm) {
    _svmBuffer.add(svm);
    if (_svmBuffer.length > _bufferMaxSize) _svmBuffer.removeAt(0);

    switch (_state) {
      case FallState.normal:
        if (svm < freeFallThreshold) {
          _transitionTo(FallState.falling);
        } else if (svm > impactThreshold) {
          _registerImpact(svm, afterFreeFall: false);
        }
      case FallState.falling:
        if (svm > impactThreshold) {
          _registerImpact(svm, afterFreeFall: true);
        } else if (_timeSinceStateChange() > const Duration(milliseconds: 800)) {
          _transitionTo(FallState.normal);
        }
      case FallState.impactDetected:
        if (_timeSinceStateChange() > _postImpactWindow) {
          _evaluatePostImpact();
        }
      case FallState.fallConfirmed:
        _transitionTo(FallState.normal);
    }
  }

  void _registerImpact(double svm, {required bool afterFreeFall}) {
    impactDetectedCount++;
    _lastImpactSvm = svm;
    _impactAfterFreeFall = afterFreeFall;
    // rotasi saat benturan menandakan tubuh terpelanting, bukan HP tersenggol
    _impactHadRotation = _lastAvmDeg >= rotationThreshold;

    final isSevere = svm >= severeImpactThreshold;
    if (isSevere) severeImpactCount++;

    // kandidat jatuh: guncangan kuat, didahului free-fall, atau disertai rotasi
    if (isSevere || afterFreeFall || _impactHadRotation) {
      _svmBuffer.clear();
      _transitionTo(FallState.impactDetected);
    } else {
      _transitionTo(FallState.normal);
    }
  }

  void _evaluatePostImpact() {
    final isStill = _variance(_svmBuffer) < inactivityVarianceThreshold;
    if (isStill) {
      fallConfirmedCount++;
      _transitionTo(FallState.fallConfirmed);
      onProbableFall?.call(
        _lastImpactSvm,
        _impactAfterFreeFall || _impactHadRotation,
      );
    } else {
      _transitionTo(FallState.normal);
    }
  }

  void _transitionTo(FallState newState) {
    _state = newState;
    _stateChangedAt = DateTime.now();
  }

  Duration _timeSinceStateChange() {
    return DateTime.now().difference(_stateChangedAt ?? DateTime.now());
  }

  double _variance(List<double> data) {
    if (data.isEmpty) return 0;
    final mean = data.reduce((a, b) => a + b) / data.length;
    return data.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / data.length;
  }
}

/// Motion analytics + UI heading per context/motion.md.
class MotionProcessor {
  MotionProcessor({
    this.complementaryAlpha = 0.97,
    this.headingSmoothing = 0.45,
    this.headingDisplayGain = 2.0,
    this.avmSmoothing = 0.85,
    this.avmDeadZoneDeg = 8.0,
    this.avmDisplayMaxDeg = 120.0,
    this.minHorizontalAccel = 0.35,
  });

  final double complementaryAlpha;
  final double headingSmoothing;
  final double headingDisplayGain;
  final double avmSmoothing;
  final double avmDeadZoneDeg;
  final double avmDisplayMaxDeg;
  final double minHorizontalAccel;

  final FallDetector fallDetector = FallDetector();

  // UI heading — accelerometer only (responsive, correct left/right)
  double _heading = 0;
  double _headingOffset = 0;
  bool _headingInitialized = false;

  // Analytics — complementary filter on postural angle θ = arctan2(a_y, a_z)
  double _posturalTheta = 0;
  bool _posturalInitialized = false;
  double _lastAccelY = 0;
  double _lastAccelZ = 9.8;
  DateTime? _lastGyroAt;

  double _svm = 9.8;
  double _rawAvmDeg = 0;
  double _smoothedAvmDeg = 0;

  double _svmSum = 0;
  int _svmCount = 0;
  double _maxSvm = 0;
  double _maxAvmDeg = 0;
  double _maxPosturalDeg = 0;
  double _maxHeadingDeviationDeg = 0;
  double _avmSum = 0;
  int _avmCount = 0;

  double get svm => _svm;
  double get avmDeg => _smoothedAvmDeg;
  double get headingRadians => _heading - _headingOffset;
  double get displayHeadingRadians {
    final amplified = headingRadians * headingDisplayGain;
    const maxRad = 70 * pi / 180;
    return amplified.clamp(-maxRad, maxRad);
  }

  double get maxHeadingDeviationDeg => _maxHeadingDeviationDeg;
  double get posturalDegrees => _posturalTheta * 180 / pi;
  double get maxTiltDegrees => _maxPosturalDeg;
  double get avgSvm => _svmCount == 0 ? 9.8 : _svmSum / _svmCount;
  double get maxSvm => _maxSvm;
  double get avgAvmDeg => _avmCount == 0 ? 0 : _avmSum / _avmCount;
  double get maxAvmDeg => _maxAvmDeg;
  int get fallEvents => fallDetector.fallConfirmedCount;
  int get impactEvents => fallDetector.impactDetectedCount;
  int get severeImpactEvents => fallDetector.severeImpactCount;

  double get avmIntensity {
    final v = max(0, _smoothedAvmDeg - avmDeadZoneDeg);
    return (v / avmDisplayMaxDeg).clamp(0.0, 1.0);
  }

  void reset() {
    fallDetector.reset();
    _heading = 0;
    _headingOffset = 0;
    _headingInitialized = false;
    _posturalTheta = 0;
    _posturalInitialized = false;
    _lastGyroAt = null;
    _svm = 9.8;
    _rawAvmDeg = 0;
    _smoothedAvmDeg = 0;
    _svmSum = 0;
    _svmCount = 0;
    _maxSvm = 0;
    _maxAvmDeg = 0;
    _maxPosturalDeg = 0;
    _maxHeadingDeviationDeg = 0;
    _avmSum = 0;
    _avmCount = 0;
  }

  /// Lock current heading as "straight ahead" for compass UI.
  void calibrateHeading() {
    _headingOffset = _heading;
  }

  void onAccelerometer(AccelerometerEvent event) {
    _svm = _computeSvm(event);
    _lastAccelY = event.y;
    _lastAccelZ = event.z;
    _trackSvm(_svm);
    fallDetector.onSvm(_svm);

    _updateHeading(event);
    _updatePosturalFromAccel(event);
  }

  void onGyroscope(GyroscopeEvent event, DateTime now) {
    final dt = _lastGyroAt == null
        ? 0.02
        : now.difference(_lastGyroAt!).inMicroseconds / 1e6;
    _lastGyroAt = now;

    _rawAvmDeg = _computeAvmDeg(event);
    _smoothedAvmDeg =
        avmSmoothing * _smoothedAvmDeg + (1 - avmSmoothing) * _rawAvmDeg;
    _trackAvm(_smoothedAvmDeg);
    fallDetector.onAvm(_rawAvmDeg);

    if (!_posturalInitialized) return;

    final gyroRate = event.x;
    final thetaAccel = atan2(_lastAccelY, _lastAccelZ);
    _posturalTheta = _normalizeAngle(
      complementaryAlpha * (_posturalTheta + gyroRate * dt) +
          (1 - complementaryAlpha) * thetaAccel,
    );
    _trackPostural();
    fallDetector.onPosturalDegrees(_posturalTheta * 180 / pi);
  }

  void _updateHeading(AccelerometerEvent e) {
    final horizontal = sqrt(e.x * e.x + e.y * e.y);

    // Prefer x/y when phone is upright; fall back to x/z when nearly flat
    final raw = horizontal >= minHorizontalAccel
        ? atan2(-e.x, e.y)
        : atan2(-e.x, e.z);

    if (!_headingInitialized) {
      _heading = raw;
      _headingInitialized = true;
      _headingOffset = raw;
    } else if (horizontal >= minHorizontalAccel || e.z.abs() > 5) {
      _heading = _lerpAngle(_heading, raw, 1 - headingSmoothing);
    }

    final dev = (_heading - _headingOffset).abs() * 180 / pi;
    if (dev > _maxHeadingDeviationDeg) _maxHeadingDeviationDeg = dev;
  }

  void _updatePosturalFromAccel(AccelerometerEvent e) {
    final thetaAccel = _computePosturalAccel(e);
    if (!_posturalInitialized) {
      _posturalTheta = thetaAccel;
      _posturalInitialized = true;
    } else {
      _posturalTheta = _normalizeAngle(
        complementaryAlpha * _posturalTheta +
            (1 - complementaryAlpha) * thetaAccel,
      );
    }
    _trackPostural();
    fallDetector.onPosturalDegrees(_posturalTheta * 180 / pi);
  }

  double _computeSvm(AccelerometerEvent e) {
    return sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
  }

  double _computeAvmDeg(GyroscopeEvent e) {
    return sqrt(e.x * e.x + e.y * e.y + e.z * e.z) * (180 / pi);
  }

  /// Postural θ from motion.md: arctan2(a_y, a_z)
  double _computePosturalAccel(AccelerometerEvent e) {
    return atan2(e.y, e.z);
  }

  void _trackSvm(double value) {
    _svmSum += value;
    _svmCount++;
    if (value > _maxSvm) _maxSvm = value;
  }

  void _trackAvm(double value) {
    _avmSum += value;
    _avmCount++;
    if (value > _maxAvmDeg) _maxAvmDeg = value;
  }

  void _trackPostural() {
    final deg = _posturalTheta.abs() * 180 / pi;
    if (deg > _maxPosturalDeg) _maxPosturalDeg = deg;
  }

  double _lerpAngle(double from, double to, double t) {
    final delta = _normalizeAngle(to - from);
    return _normalizeAngle(from + delta * t);
  }

  double _normalizeAngle(double radians) {
    var a = radians;
    while (a > pi) {
      a -= 2 * pi;
    }
    while (a < -pi) {
      a += 2 * pi;
    }
    return a;
  }
}
