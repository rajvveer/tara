import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.offline = false});

  final String message;
  final int? statusCode;
  final bool offline;

  @override
  String toString() => message;
}

class TokenStore {
  TokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'onward_access_token';
  static const _refreshKey = 'onward_refresh_token';
  final FlutterSecureStorage _storage;

  Future<String?> get accessToken => _storage.read(key: _accessKey);
  Future<String?> get refreshToken => _storage.read(key: _refreshKey);

  Future<void> save(String access, String refresh) async {
    await Future.wait([
      _storage.write(key: _accessKey, value: access),
      _storage.write(key: _refreshKey, value: refresh),
    ]);
  }

  Future<void> clear() => _storage.deleteAll();
}

class CacheStore {
  Future<void> write(String key, Object value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, jsonEncode(value));
  }

  Future<dynamic> read(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(key);
    return value == null ? null : jsonDecode(value);
  }

  Future<void> remove(String key) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(key);
  }
}

class ApiClient {
  ApiClient({http.Client? client, TokenStore? tokens, String? baseUrl})
    : _client = client ?? http.Client(),
      tokens = tokens ?? TokenStore(),
      baseUrl =
          (baseUrl ??
                  const String.fromEnvironment(
                    'API_BASE_URL',
                    defaultValue: 'http://10.0.2.2:4000/api/v1',
                  ))
              .replaceFirst(RegExp(r'/$'), '');

  final http.Client _client;
  final TokenStore tokens;
  final String baseUrl;
  Future<bool>? _refreshInFlight;
  VoidCallback? onSessionExpired;

  Future<Map<String, dynamic>> get(String path) => _request('GET', path);

  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
  ]) => _request('POST', path, body: body);

  Future<Map<String, dynamic>> postLong(
    String path, [
    Map<String, dynamic>? body,
  ]) =>
      _request('POST', path, body: body, timeout: const Duration(seconds: 45));

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) =>
      _request('PATCH', path, body: body);

  Future<Map<String, dynamic>> delete(String path) => _request('DELETE', path);

  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) => _request(method, path, body: body);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool retried = false,
    Duration timeout = const Duration(seconds: 14),
  }) async {
    try {
      final accessToken = await tokens.accessToken;
      final request = http.Request(method, Uri.parse('$baseUrl$path'))
        ..headers['Accept'] = 'application/json'
        ..headers['Content-Type'] = 'application/json';
      if (accessToken != null) {
        request.headers['Authorization'] = 'Bearer $accessToken';
      }
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 401 && !retried) {
        if (await _refresh()) {
          return _request(
            method,
            path,
            body: body,
            retried: true,
            timeout: timeout,
          );
        }
        await tokens.clear();
        onSessionExpired?.call();
        throw const ApiException(
          'Your session expired. Sign in again to continue.',
          statusCode: 401,
        );
      }
      final decoded = _decode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded['error'];
        final message =
            decoded['message']?.toString() ??
            (error is Map ? error['message']?.toString() : error?.toString()) ??
            'That did not work. Please try again.';
        throw ApiException(message, statusCode: response.statusCode);
      }
      return decoded;
    } on ApiException {
      rethrow;
    } on http.ClientException {
      throw const ApiException(
        'We could not reach GoalSpring. Check your connection and try again.',
        offline: true,
      );
    } on TimeoutException {
      throw const ApiException(
        'We could not reach GoalSpring. Check your connection and try again.',
        offline: true,
      );
    } on Exception catch (error) {
      if (kDebugMode) debugPrint('API request failed: $error');
      throw const ApiException('Something went wrong. Please try again.');
    }
  }

  Map<String, dynamic> _decode(String source) {
    if (source.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(source);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is List) return {'items': decoded};
    return {'data': decoded};
  }

  Future<bool> _refresh() async {
    final existing = _refreshInFlight;
    if (existing != null) return existing;
    final operation = _doRefresh();
    _refreshInFlight = operation;
    try {
      return await operation;
    } finally {
      if (identical(_refreshInFlight, operation)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<bool> _doRefresh() async {
    final refreshToken = await tokens.refreshToken;
    if (refreshToken == null) return false;
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/auth/refresh'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await tokens.clear();
        return false;
      }
      final payload = payloadOf(_decode(response.body));
      final access = payload['accessToken']?.toString();
      final refresh = payload['refreshToken']?.toString() ?? refreshToken;
      if (access == null) return false;
      await tokens.save(access, refresh);
      return true;
    } catch (_) {
      return false;
    }
  }
}

Map<String, dynamic> payloadOf(Map<String, dynamic> response) {
  final data = response['data'];
  return data is Map<String, dynamic> ? data : response;
}

List<dynamic> listOf(Map<String, dynamic> response, String key) {
  final data = response['data'];
  if (data is List) return data;
  final payload = data is Map<String, dynamic> ? data : payloadOf(response);
  final value = payload[key] ?? payload['items'];
  return value is List ? value : const [];
}
