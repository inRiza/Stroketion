import 'api_client.dart';
import '../models/link_models.dart';
import 'session_service.dart';

class LinkService {
  LinkService({
    ApiClient? apiClient,
    SessionService? sessionService,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService();

  final ApiClient _api;
  final SessionService _session;

  Future<String?> _token() => _session.getToken();

  Future<UserProfile> getMyProfile() async {
    final token = await _token();
    final data = await _api.get('/links/me/profile', token: token);
    return UserProfile.fromJson(data);
  }

  Future<CaregiverLookup> lookupCaregiverByPhone(String phone) async {
    final token = await _token();
    final data = await _api.get('/links/caregivers/lookup?phone=$phone', token: token);
    return CaregiverLookup.fromJson(data);
  }

  Future<void> scanPatient(String patientId) async {
    final token = await _token();
    await _api.post('/links/scan-patient', body: {'patient_id': patientId}, token: token);
  }

  Future<void> requestCaregiver({
    String? caregiverId,
    String? phone,
    String? relationship,
  }) async {
    final token = await _token();
    final body = <String, dynamic>{};
    if (caregiverId != null) body['caregiver_id'] = caregiverId;
    if (phone != null) body['phone'] = phone;
    if (relationship != null) body['relationship'] = relationship;
    await _api.post('/links/request-caregiver', body: body, token: token);
  }

  Future<UserProfile> getUserProfile(String userId) async {
    final token = await _token();
    final data = await _api.get('/links/users/$userId', token: token);
    return UserProfile.fromJson(data);
  }

  Future<List<LinkedPatient>> getMyPatients() async {
    final token = await _token();
    final data = await _api.getList('/links/my-patients', token: token);
    return data.map((e) => LinkedPatient.fromJson(e)).toList();
  }

  Future<List<LinkedCaregiver>> getMyCaregivers() async {
    final token = await _token();
    final data = await _api.getList('/links/my-caregivers', token: token);
    return data.map((e) => LinkedCaregiver.fromJson(e)).toList();
  }

  Future<List<PendingNotification>> getPendingNotifications() async {
    final token = await _token();
    final data = await _api.getList('/links/pending', token: token);
    return data.map((e) => PendingNotification.fromJson(e)).toList();
  }

  Future<void> approveLink(String linkId) async {
    final token = await _token();
    await _api.post('/links/$linkId/approve', token: token);
  }

  Future<void> rejectLink(String linkId) async {
    final token = await _token();
    await _api.post('/links/$linkId/reject', token: token);
  }
}
