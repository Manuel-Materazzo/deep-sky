import 'dart:convert';

import 'package:deep_sky/domain/push_models.dart';
import 'package:http/http.dart' as http;

/// HTTP exception returned by SP-01 backend endpoints.
class PushApiException implements Exception {
  PushApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'PushApiException($statusCode): $message';
}

/// REST client for SP-01 runtime push config, token registration, and test wakeups.
class PushApiClient {
  PushApiClient({required String baseUrl, http.Client? httpClient})
    : _baseUri = _normalizeBaseUrl(baseUrl),
      _http = httpClient ?? http.Client();

  final Uri _baseUri;
  final http.Client _http;

  static Uri _normalizeBaseUrl(String raw) {
    final String trimmed = raw.trim().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse(trimmed);
  }

  Uri _endpoint(String path) => Uri.parse('$_baseUri$path');

  Future<RuntimeFirebaseConfig> fetchRuntimeConfig() async {
    final http.Response response = await _http.get(
      _endpoint('/api/v1/push/config'),
      headers: const <String, String>{'Accept': 'application/json'},
    );
    final Map<String, dynamic> data = _decodeJsonMap(response);
    return RuntimeFirebaseConfig.fromJson(data);
  }

  Future<void> registerToken({
    required String deviceId,
    required String fcmToken,
    String? coupleId,
  }) async {
    final http.Response response = await _http.put(
      _endpoint('/api/v1/push/token'),
      headers: const <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(<String, Object?>{
        'deviceId': deviceId.trim(),
        'coupleId': coupleId?.trim(),
        'fcmToken': fcmToken.trim(),
        'platform': 'android',
      }),
    );
    _decodeJsonMap(response);
  }

  Future<void> unregisterToken(String deviceId) async {
    final http.Response response = await _http.delete(
      _endpoint('/api/v1/push/token/${Uri.encodeComponent(deviceId.trim())}'),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PushApiException(response.statusCode, response.body);
    }
  }

  Future<PushWakeupOutcome> sendTestWakeup({
    String? deviceId,
    String? coupleId,
    String localizationKey = 'wakeup.new_moment',
  }) async {
    final http.Response response = await _http.post(
      _endpoint('/api/v1/push/test-wakeup'),
      headers: const <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(<String, Object?>{
        if (deviceId != null && deviceId.trim().isNotEmpty)
          'deviceId': deviceId.trim(),
        if (coupleId != null && coupleId.trim().isNotEmpty)
          'coupleId': coupleId.trim(),
        'localizationKey': localizationKey,
      }),
    );
    final Map<String, dynamic> data = _decodeJsonMap(response);
    return PushWakeupOutcome.fromJson(data);
  }

  Map<String, dynamic> _decodeJsonMap(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PushApiException(response.statusCode, response.body);
    }
    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw PushApiException(
        response.statusCode,
        'Expected JSON object response.',
      );
    }
    return decoded;
  }
}
