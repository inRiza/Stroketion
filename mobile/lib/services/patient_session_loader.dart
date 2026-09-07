import '../models/monitoring_session_record.dart';
import '../models/session_summary_item.dart';
import 'monitoring_session_api.dart';
import 'session_history_storage.dart';

class PatientSessionLoader {
  PatientSessionLoader({
    SessionHistoryStorage? historyStorage,
    MonitoringSessionApi? sessionApi,
  })  : _history = historyStorage ?? SessionHistoryStorage(),
        _api = sessionApi ?? MonitoringSessionApi();

  final SessionHistoryStorage _history;
  final MonitoringSessionApi _api;

  Future<List<MonitoringSessionRecord>> loadMerged({int limit = 50}) async {
    await SessionHistoryStorage.dropLegacySharedHistory();

    final byId = <String, MonitoringSessionRecord>{};
    for (final record in await _history.getAll()) {
      byId[record.id] = record;
    }

    try {
      final rows = await _api.getMySessions(limit: limit);
      for (final row in rows) {
        final summary = SessionSummaryItem.fromJson(row);
        byId.putIfAbsent(summary.id, () => summary.toListRecord());
      }
    } catch (_) {}

    final merged = byId.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return merged.take(limit).toList();
  }

  Future<MonitoringSessionRecord?> resolveDetail(
    MonitoringSessionRecord record,
  ) async {
    if (record.timeline.isNotEmpty || record.route.isNotEmpty) {
      return record;
    }
    return _api.getSession(record.id);
  }
}
