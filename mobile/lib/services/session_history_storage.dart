import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/monitoring_session_record.dart';
import 'session_service.dart';

class SessionHistoryStorage {
  static const _legacyKey = 'monitoring_session_history';

  SessionHistoryStorage({SessionService? sessionService})
      : _session = sessionService ?? SessionService();

  final SessionService _session;

  Future<String?> _storageKey() async {
    final user = await _session.getUser();
    if (user == null) return null;
    return 'monitoring_session_history_${user.id}';
  }

  Future<List<MonitoringSessionRecord>> getAll() async {
    final key = await _storageKey();
    if (key == null) return [];

    await Future.delayed(const Duration(milliseconds: 350));
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(key) ?? [];
    final records = raw
        .map(
          (e) => MonitoringSessionRecord.fromJson(
            jsonDecode(e) as Map<String, dynamic>,
          ),
        )
        .toList();
    records.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return records;
  }

  Future<void> save(MonitoringSessionRecord record) async {
    final key = await _storageKey();
    if (key == null) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(key) ?? [];

    final encoded = jsonEncode(record.toJson());
    final withoutDuplicate = raw.where((entry) {
      final decoded = jsonDecode(entry) as Map<String, dynamic>;
      return decoded['id'] != record.id;
    }).toList();

    withoutDuplicate.insert(0, encoded);
    await prefs.setStringList(key, withoutDuplicate);
  }

  Future<List<MonitoringSessionRecord>> search({
    String query = '',
    SessionLocation? location,
    SessionActivity? activity,
    int offset = 0,
    int limit = 20,
  }) async {
    var records = await getAll();

    if (query.trim().isNotEmpty) {
      final q = query.toLowerCase();
      records = records.where((r) {
        return r.location.label.toLowerCase().contains(q) ||
            r.activity.label.toLowerCase().contains(q);
      }).toList();
    }

    if (location != null) {
      records = records.where((r) => r.location == location).toList();
    }

    if (activity != null) {
      records = records.where((r) => r.activity == activity).toList();
    }

    final end = min(offset + limit, records.length);
    if (offset >= records.length) return [];
    return records.sublist(offset, end);
  }

  /// Hapus cache lama yang tidak terikat ke akun (migrasi sekali).
  static Future<void> dropLegacySharedHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyKey);
  }
}
