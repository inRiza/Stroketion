import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import '../../services/api_host_storage.dart';

class ApiConfig {
  ApiConfig._();

  static const int port = 8000;

  /// Fallback saat compile. Bisa dioverride lewat Pengaturan Server di app.
  static const String lanHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: '192.168.1.112',
  );

  static late String baseUrl;
  static late String activeHost;

  /// Cached once — avoid slow device_info call on every save.
  static bool _useLanHost = true;
  static bool _deviceTypeResolved = false;

  static Future<void> init() async {
    await _ensureDeviceType();
    await _applyBaseUrl();
  }

  static Future<void> reload() async {
    await _applyBaseUrl();
  }

  /// Update host immediately in memory, then persist (fast — no device_info).
  static Future<void> setHost(String host) async {
    await _ensureDeviceType();
    final normalized = _normalizeHost(host);
    _assignHost(normalized);
    await ApiHostStorage.save(normalized);
  }

  static Future<void> clearHostOverride() async {
    await _ensureDeviceType();
    await ApiHostStorage.clear();
    await _applyBaseUrl();
  }

  static String _normalizeHost(String raw) {
    var host = raw.trim();
    host = host.replaceFirst(RegExp(r'^https?://'), '');
    host = host.split('/').first;
    host = host.split(':').first;
    return host;
  }

  static Future<void> _ensureDeviceType() async {
    if (_deviceTypeResolved) return;

    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      _useLanHost = info.isPhysicalDevice;
    } else if (Platform.isIOS) {
      final info = await DeviceInfoPlugin().iosInfo;
      _useLanHost = info.isPhysicalDevice;
    } else {
      _useLanHost = false;
    }
    _deviceTypeResolved = true;
  }

  static Future<void> _applyBaseUrl() async {
    await _ensureDeviceType();

    if (!_useLanHost) {
      if (Platform.isAndroid) {
        _assignHost('10.0.2.2');
      } else {
        _assignHost('127.0.0.1');
      }
      return;
    }

    final stored = await ApiHostStorage.load();
    _assignHost(stored ?? lanHost);
  }

  static void _assignHost(String host) {
    activeHost = host;
    baseUrl = 'http://$host:$port';
    _logConfig();
  }

  static void _logConfig() {
    if (!kDebugMode) return;
    debugPrint('ApiConfig.baseUrl = $baseUrl');
    debugPrint('ApiConfig.activeHost = $activeHost');
  }

  static String get apiV1 => '$baseUrl/api/v1';

  static String get wsSpeechStream {
    final wsBase =
        baseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
    return '$wsBase/api/v1/speech/stream';
  }

  static String healthUrlForHost(String host) =>
      'http://${_normalizeHost(host)}:$port/health';
}
