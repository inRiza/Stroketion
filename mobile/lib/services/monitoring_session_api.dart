import 'api_client.dart';
import '../models/monitoring_session_record.dart';
import 'session_service.dart';

class MonitoringSessionApi {
  MonitoringSessionApi({
    ApiClient? apiClient,
    SessionService? sessionService,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService();

  final ApiClient _api;
  final SessionService _session;

  Future<void> uploadSession(MonitoringSessionRecord record) async {
    final token = await _session.getToken();
    if (token == null) return;
    await _api.post('/sessions', body: record.toJson(), token: token);
  }

  Future<List<Map<String, dynamic>>> getMySessions({int limit = 50}) async {
    final token = await _session.getToken();
    if (token == null) return [];
    return _api.getList('/sessions/me?limit=$limit', token: token);
  }

  Future<List<Map<String, dynamic>>> getPatientSessions(
    String patientId, {
    int limit = 50,
  }) async {
    final token = await _session.getToken();
    if (token == null) return [];
    return _api.getList('/sessions/patients/$patientId?limit=$limit', token: token);
  }

  Future<MonitoringSessionRecord?> getSession(String sessionId) async {
    final token = await _session.getToken();
    if (token == null) return null;
    final data = await _api.get('/sessions/$sessionId', token: token);
    return MonitoringSessionRecord.fromJson(data);
  }
}
