import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

import '../core/constants/emergency_assets.dart';

class EmergencyAlertService {
  EmergencyAlertService._();

  static final EmergencyAlertService instance = EmergencyAlertService._();

  final AudioPlayer _player = AudioPlayer();
  final List<Future<void> Function()> _onStoppedCallbacks = [];
  Timer? _vibrateTimer;
  bool _active = false;
  bool _audioContextReady = false;

  bool get isActive => _active;

  void addOnStoppedCallback(Future<void> Function() callback) {
    if (!_onStoppedCallbacks.contains(callback)) {
      _onStoppedCallbacks.add(callback);
    }
  }

  void removeOnStoppedCallback(Future<void> Function() callback) {
    _onStoppedCallbacks.remove(callback);
  }

  Future<void> _ensureAudioContext() async {
    if (_audioContextReady) return;
    try {
      // playAndRecord + mixWithOthers: alarm SOS tidak mematikan mikrofon sesi
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playAndRecord,
            options: {
              AVAudioSessionOptions.defaultToSpeaker,
              AVAudioSessionOptions.mixWithOthers,
              AVAudioSessionOptions.allowBluetooth,
            },
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        ),
      );
      _audioContextReady = true;
    } catch (e) {
      if (kDebugMode) debugPrint('Emergency audio context error: $e');
    }
  }

  Future<void> start() async {
    if (_active) return;
    _active = true;

    await _startVibration();
    await _startSound();
  }

  Future<void> stop() async {
    if (!_active) return;
    _active = false;

    _vibrateTimer?.cancel();
    _vibrateTimer = null;

    try {
      await _player.stop();
    } catch (e) {
      if (kDebugMode) debugPrint('Emergency sound stop error: $e');
    }

    try {
      if (await Vibration.hasVibrator() == true) {
        await Vibration.cancel();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Emergency vibrate cancel error: $e');
    }

    for (final callback in List.of(_onStoppedCallbacks)) {
      try {
        await callback();
      } catch (e) {
        if (kDebugMode) debugPrint('Emergency onStopped callback error: $e');
      }
    }
  }

  Future<void> _startSound() async {
    try {
      await _ensureAudioContext();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource(EmergencyAssets.sosAlertSound));
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Emergency sound missing or failed. '
          'Add ${EmergencyAssets.sosAlertSound} under mobile/assets/sounds/',
        );
      }
    }
  }

  Future<void> _startVibration() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator != true) return;

      final pattern = [0, 600, 200, 600, 200, 600];
      final supportsCustom = await Vibration.hasCustomVibrationsSupport();
      if (supportsCustom == true) {
        await Vibration.vibrate(pattern: pattern, repeat: 0);
        return;
      }

      _vibrateTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
        Vibration.vibrate(duration: 500);
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Emergency vibrate error: $e');
    }
  }

  void dispose() {
    stop();
    _player.dispose();
  }
}
