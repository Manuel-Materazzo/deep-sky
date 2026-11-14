import 'package:deep_sky/data/couple_api_client.dart';
import 'package:deep_sky/domain/crypto/e2ee_models.dart';
import 'package:deep_sky/domain/push_models.dart';

/// Authenticated REST client for M2 runtime push config, token registration,
/// and partner wakeup endpoints (SP-01 + PR-M2-03).
class PushApiClient {
  PushApiClient({required this._apiClient});

  final CoupleApiClient _apiClient;

  /// Fetches public runtime Firebase configuration (`GET /api/v1/push/config`).
  Future<RuntimeFirebaseConfig> fetchRuntimeConfig() async {
    final Object? data = await _apiClient.unsignedGetJson(
      '/api/v1/push/config',
    );
    return RuntimeFirebaseConfig.fromJson(data! as Map<String, dynamic>);
  }

  /// Registers or updates the current device's FCM token (`POST /api/v1/push/register`).
  Future<void> registerToken({
    required LocalDeviceIdentity identity,
    required String fcmToken,
  }) async {
    await _apiClient.signedJsonRequest(
      method: 'POST',
      pathWithQuery: '/api/v1/push/register',
      identity: identity,
      body: <String, Object?>{
        'fcmToken': fcmToken.trim(),
        'platform': 'android',
      },
    );
  }

  /// Removes the current device's push token registration (`DELETE /api/v1/push/register`).
  Future<void> unregisterToken({required LocalDeviceIdentity identity}) async {
    await _apiClient.signedJsonRequest(
      method: 'DELETE',
      pathWithQuery: '/api/v1/push/register',
      identity: identity,
    );
  }

  /// Requests a localized silent/notification wakeup for the partner (`POST /api/v1/push/wakeup`).
  Future<PushWakeupOutcome> sendPartnerWakeup({
    required LocalDeviceIdentity identity,
    String localizationKey = 'wakeup.thinking_of_you',
  }) async {
    final Object? data = await _apiClient.signedJsonRequest(
      method: 'POST',
      pathWithQuery: '/api/v1/push/wakeup',
      identity: identity,
      body: <String, Object?>{'localizationKey': localizationKey},
    );
    return PushWakeupOutcome.fromJson(data! as Map<String, dynamic>);
  }
}
