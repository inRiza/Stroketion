import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/api_config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.apiV1}$path'),
      headers: _headers(token),
      body: jsonEncode(body ?? {}),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> get(String path, {String? token}) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.apiV1}$path'),
      headers: _headers(token),
    );
    return _handleResponse(response);
  }

  Future<List<Map<String, dynamic>>> getList(String path, {String? token}) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.apiV1}$path'),
      headers: _headers(token),
    );
    final decoded = _decodeBody(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return [];
    }
    _throwError(response.statusCode, decoded);
  }

  Map<String, String> _headers(String? token) {
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final decoded = _decodeBody(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    }
    _throwError(response.statusCode, decoded);
  }

  dynamic _decodeBody(http.Response response) {
    if (response.body.isEmpty) return {};
    return jsonDecode(response.body);
  }

  Never _throwError(int statusCode, dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final detail = decoded['detail'];
      final message = detail is String
          ? detail
          : detail is List && detail.isNotEmpty
              ? detail.first['msg']?.toString() ?? 'Request failed'
              : 'Request failed ($statusCode)';
      throw ApiException(message, statusCode: statusCode);
    }
    throw ApiException('Request failed ($statusCode)', statusCode: statusCode);
  }
}
