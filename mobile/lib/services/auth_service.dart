import '../models/user.dart';
import '../models/user_role.dart';
import 'api_client.dart';
import 'session_service.dart';

class AuthService {
  AuthService({
    ApiClient? apiClient,
    SessionService? sessionService,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService();

  final ApiClient _api;
  final SessionService _session;

  Future<AuthResult> login({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final data = await _api.post('/auth/login', body: {
      'email': email,
      'password': password,
      'role': role.apiValue,
    });

    final result = AuthResult.fromJson(data);
    await _session.saveSession(result);
    return result;
  }

  Future<AuthResult> register({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? phone,
    String? gender,
    String? dateOfBirth,
  }) async {
    final data = await _api.post('/auth/register', body: {
      'email': email,
      'password': password,
      'full_name': fullName,
      'role': role.apiValue,
      'phone': phone,
      'gender': gender,
      'date_of_birth': dateOfBirth,
    });

    final result = AuthResult.fromJson(data);
    await _session.saveSession(result);
    return result;
  }

  Future<void> logout() => _session.clear();

  Future<User?> getCurrentUser() => _session.getUser();
}
