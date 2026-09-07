import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/config/api_config.dart';
import '../models/speech_analysis.dart';
import 'session_service.dart';

class SpeechStreamService extends ChangeNotifier {
  SpeechStreamService({SessionService? sessionService})
      : _session = sessionService ?? SessionService();

  final SessionService _session;
  final _recorder = AudioRecorder();

  WebSocketChannel? _channel;
  StreamSubscription<Uint8List>? _micSub;
  Timer? _chunkTimer;
  Timer? _healthTimer;
  Completer<void>? _readyCompleter;
  Completer<SpeechAnalysisSummary>? _summaryCompleter;

  void Function(String reason)? onClinicalAlert;

  Map<String, dynamic>? _peakClinicalAlert;
  Map<String, dynamic>? get peakClinicalAlert => _peakClinicalAlert;

  final List<int> _pcmBuffer = [];
  SpeechLiveMetrics _live = const SpeechLiveMetrics();
  SpeechAnalysisSummary? _summary;
  int _timestampMs = 0;
  bool _running = false;
  bool _closing = false;
  bool _recovering = false;
  DateTime? _lastMicChunkAt;
  double _localMicLevel = 0;

  SpeechLiveMetrics get live => _live;
  SpeechAnalysisSummary? get summary => _summary;
  bool get isRunning => _running;
  double get localMicLevel => _localMicLevel;

  Future<bool> start({required String monitoringSessionId}) async {
    if (_running) return true;

    final token = await _session.getToken();
    if (token == null) {
      _setOffline('Token sesi tidak ditemukan');
      return false;
    }

    _summary = null;
    _timestampMs = 0;
    _pcmBuffer.clear();
    _peakClinicalAlert = null;
    _localMicLevel = 0;
    _lastMicChunkAt = null;
    _readyCompleter = Completer<void>();

    try {
      final uri = Uri.parse('${ApiConfig.wsSpeechStream}?token=$token');
      if (kDebugMode) debugPrint('Speech WS connect: $uri');

      _channel = WebSocketChannel.connect(uri);
      _channel!.stream.listen(
        _onMessage,
        onError: (e) {
          if (kDebugMode) debugPrint('Speech WS onError: $e');
          if (!_closing) {
            _setOffline('Koneksi speech putus: $e');
          }
        },
        onDone: () {
          if (kDebugMode) debugPrint('Speech WS closed');
          if (_closing) return;
          final waitingReady =
              _readyCompleter != null && !_readyCompleter!.isCompleted;
          if (_running || waitingReady) {
            _setOffline('Koneksi speech ditutup server');
          }
        },
      );
      await _channel!.ready;

      _live = const SpeechLiveMetrics(loading: true);
      notifyListeners();

      _channel!.sink.add(jsonEncode({
        'type': 'start',
        'monitoring_session_id': monitoringSessionId,
        'sample_rate': 16000,
      }));

      await _readyCompleter!.future.timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          throw TimeoutException('Server speech tidak merespons ready');
        },
      );

      if (!await _recorder.hasPermission()) {
        _setOffline('Izin mikrofon ditolak');
        return false;
      }

      await _startMicCapture();

      _chunkTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        _flushChunk();
      });

      _healthTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _checkMicHealth();
      });

      _running = true;
      _live = const SpeechLiveMetrics(connected: true);
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('SpeechStream start error: $e');
      _setOffline('Gagal memulai speech: $e');
      return false;
    }
  }

  Future<void> _startMicCapture() async {
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      ),
    );

    await _micSub?.cancel();
    _micSub = stream.listen(
      (chunk) {
        _pcmBuffer.addAll(chunk);
        _lastMicChunkAt = DateTime.now();
        _localMicLevel = _estimateMicLevel(chunk);
        notifyListeners();
      },
      onError: (e) {
        if (kDebugMode) debugPrint('Speech mic stream error: $e');
        unawaited(recoverAfterInterruption());
      },
    );
  }

  double _estimateMicLevel(Uint8List chunk) {
    if (chunk.length < 2) return 0;
    var sum = 0.0;
    final samples = chunk.length ~/ 2;
    for (var i = 0; i < chunk.length - 1; i += 2) {
      final sample = (chunk[i] | (chunk[i + 1] << 8)).toSigned(16);
      sum += sample * sample;
    }
    if (samples == 0) return 0;
    final rms = math.sqrt(sum / samples);
    // normalize ~0..1 for waveform (typical speech RMS ~500-8000)
    return (math.log(rms + 1) / 9.5).clamp(0.0, 1.0);
  }

  void _checkMicHealth() {
    if (!_running || _recovering || _closing) return;

    final micAt = _lastMicChunkAt;
    if (micAt == null) return;

    final silentTooLong = DateTime.now().difference(micAt) > const Duration(seconds: 3);
    if (silentTooLong) {
      if (kDebugMode) {
        debugPrint('SpeechStream: mic idle >3s, recovering capture...');
      }
      unawaited(recoverAfterInterruption());
    }
  }

  void _flushChunk() {
    if (!_running || _channel == null || _pcmBuffer.isEmpty) return;

    final chunk = List<int>.from(_pcmBuffer);
    _pcmBuffer.clear();
    _timestampMs += 100;

    _channel!.sink.add(jsonEncode({
      'type': 'chunk',
      'pcm_base64': base64Encode(chunk),
      'timestamp_ms': _timestampMs,
    }));
  }

  void _onMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = msg['type'] as String?;

      if (type == 'loading') {
        _live = const SpeechLiveMetrics(loading: true);
        notifyListeners();
      } else if (type == 'ready') {
        if (_readyCompleter != null && !_readyCompleter!.isCompleted) {
          _readyCompleter!.complete();
        }
        if (!_running) {
          _live = const SpeechLiveMetrics(loading: true);
          notifyListeners();
        }
      } else if (type == 'live') {
        _live = SpeechLiveMetrics(
          speechActive: msg['speech_active'] as bool? ?? false,
          energyDbfs: (msg['energy_dbfs'] as num?)?.toDouble() ?? -60,
          vadProb: (msg['vad_prob'] as num?)?.toDouble() ?? 0,
          connected: true,
        );
        final alert = msg['clinical_alert'] as Map<String, dynamic>?;
        if (alert != null) {
          final severity = alert['severity'] as String? ?? 'low';
          final prev = _peakClinicalAlert?['severity'] as String? ?? 'low';
          const rank = {'low': 1, 'medium': 2, 'high': 3};
          if ((rank[severity] ?? 0) >= (rank[prev] ?? 0)) {
            _peakClinicalAlert = alert;
          }
          if (severity == 'high') {
            final reason = alert['reason'] as String? ?? 'Gangguan bicara terdeteksi';
            onClinicalAlert?.call(reason);
          }
        }
        notifyListeners();
      } else if (type == 'summary') {
        _summary = SpeechAnalysisSummary.fromJson(msg);
        _summaryCompleter?.complete(_summary!);
        notifyListeners();
      } else if (type == 'error') {
        final code = msg['code'] as String?;
        final message = msg['message'] as String? ?? 'Unknown error';
        if (kDebugMode) {
          debugPrint('Speech WS error: $code $message');
        }
        if (code == 'speech_ml_unavailable') {
          _setOffline(
            'Model speech belum terpasang di server. '
            'Jalankan: cd backend && uv sync --extra speech lalu restart uvicorn.',
          );
        } else if (code != 'speech_processing_error') {
          _setOffline(message);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Speech WS parse error: $e');
    }
  }

  void tickDuration(int durationSeconds) {
    if (!_running || _channel == null) return;
    _channel!.sink.add(jsonEncode({
      'type': 'tick',
      'duration_seconds': durationSeconds,
    }));
  }

  /// Pulihkan mikrofon setelah SOS/alarm — selalu stop lalu start ulang.
  Future<void> recoverAfterInterruption() async {
    if (!_running || _recovering) return;
    _recovering = true;
    try {
      if (kDebugMode) debugPrint('SpeechStream: recovering mic after interruption...');

      await _micSub?.cancel();
      _micSub = null;

      try {
        if (await _recorder.isRecording()) {
          await _recorder.stop();
        }
      } catch (e) {
        if (kDebugMode) debugPrint('SpeechStream stop recorder: $e');
      }

      await Future<void>.delayed(const Duration(milliseconds: 350));

      if (!_running) return;

      await _startMicCapture();
      _lastMicChunkAt = DateTime.now();

      if (_live.offline) {
        _live = const SpeechLiveMetrics(connected: true);
      } else {
        _live = SpeechLiveMetrics(
          speechActive: _live.speechActive,
          energyDbfs: _live.energyDbfs,
          vadProb: _live.vadProb,
          connected: true,
        );
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('SpeechStream mic recover error: $e');
    } finally {
      _recovering = false;
    }
  }

  @Deprecated('Use recoverAfterInterruption')
  Future<void> resumeMicAfterInterruption() => recoverAfterInterruption();

  Future<SpeechAnalysisSummary> stop({required int durationSeconds}) async {
    if (!_running) {
      return _summary ?? SpeechAnalysisSummary.offlineFallback;
    }

    _healthTimer?.cancel();
    _flushChunk();
    _summaryCompleter = Completer<SpeechAnalysisSummary>();
    _channel?.sink.add(jsonEncode({
      'type': 'stop',
      'duration_seconds': durationSeconds,
    }));

    await _micSub?.cancel();
    _chunkTimer?.cancel();
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (_) {}

    try {
      final summary = await _summaryCompleter!.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('SpeechStream: summary timeout, using peak alert fallback');
          }
          return _buildTimeoutSummary(durationSeconds);
        },
      );
      _running = false;
      _closing = true;
      await _channel?.sink.close();
      _channel = null;
      _closing = false;
      return summary;
    } catch (_) {
      _running = false;
      _closing = true;
      await _channel?.sink.close();
      _channel = null;
      _closing = false;
      return _summary ?? _buildTimeoutSummary(durationSeconds);
    }
  }

  SpeechAnalysisSummary _buildTimeoutSummary(int durationSeconds) {
    if (_summary != null && !_summary!.offline) return _summary!;
    final peak = _peakClinicalAlert;
    if (peak == null) return SpeechAnalysisSummary.offlineFallback;

    final flagsRaw = peak['flags'] as List<dynamic>? ?? [];
    return SpeechAnalysisSummary(
      vadActiveSeconds: durationSeconds.clamp(0, 999),
      speechScore: 60,
      dysarthriaRisk: flagsRaw.any((f) => f.toString().contains('disartria'))
          ? 'medium'
          : 'unknown',
      aphasiaRisk: 'high',
      clinicalNotes: [
        if (peak['reason'] != null) peak['reason'].toString(),
        'Ringkasan server timeout — hasil dari alert live sesi.',
      ],
    ).withLiveAlertFallback(
      peakSeverity: peak['severity'] as String?,
      peakReason: peak['reason'] as String?,
      peakFlags: flagsRaw.map((e) => e.toString()).toList(),
    );
  }

  void _setOffline([String? reason]) {
    if (_readyCompleter != null && !_readyCompleter!.isCompleted) {
      _readyCompleter!.completeError(StateError(reason ?? 'offline'));
    }
    if (_summaryCompleter != null && !_summaryCompleter!.isCompleted) {
      _summaryCompleter!.complete(
        _summary ?? _buildTimeoutSummary(0),
      );
    }
    _live = SpeechLiveMetrics(offline: true, offlineReason: reason);
    if (_summary == null) {
      _summary = SpeechAnalysisSummary.offlineFallback;
    }
    _running = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    _chunkTimer?.cancel();
    _micSub?.cancel();
    _channel?.sink.close();
    _recorder.dispose();
    super.dispose();
  }
}
