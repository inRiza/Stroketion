import 'api_client.dart';
import '../models/sos_alert.dart';
import 'session_service.dart';

class SosNotificationService {
  SosNotificationService({
    ApiClient? apiClient,
    SessionService? sessionService,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService();

  final ApiClient _api;
  final SessionService _session;

  Future<void> sendSosAlert({required String message}) async {
    final token = await _session.getToken();
    await _api.post('/notifications/sos', body: {'message': message}, token: token);
  }

  Future<List<SosAlert>> getPendingAlerts() async {
    final token = await _session.getToken();
    final data = await _api.getList('/notifications/sos/pending', token: token);
    return data.map(SosAlert.fromJson).toList();
  }

  Future<void> acknowledgeAlert(String alertId) async {
    final token = await _session.getToken();
    await _api.post('/notifications/sos/$alertId/ack', token: token);
  }
}
