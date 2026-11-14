import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:deep_sky/data/couple_api_client.dart';
import 'package:deep_sky/data/push_api_client.dart';
import 'package:deep_sky/domain/crypto/deep_sky_crypto.dart';
import 'package:deep_sky/domain/crypto/e2ee_models.dart';
import 'package:deep_sky/domain/push_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('fetches runtime config, registers signed token, dispatches wakeup, and unregisters', () async {
    final DeepSkyCrypto crypto = DeepSkyCrypto();
    final SimpleKeyPair authPair = await crypto.generateDeviceAuthKeyPair();
    final SimpleKeyPair kemPair = await crypto.generateDeviceKemKeyPair();
    final SimplePublicKey authPub = await authPair.extractPublicKey();
    final SimplePublicKey kemPub = await kemPair.extractPublicKey();
    final List<int> authSeed = await authPair.extractPrivateKeyBytes();
    final List<int> kemPriv = await kemPair.extractPrivateKeyBytes();
    final LocalDeviceIdentity identity = LocalDeviceIdentity(
      serverUrl: 'https://couple.example.test',
      coupleId: 'couple-1',
      deviceId: 'device-a',
      deviceLabel: 'Pixel A',
      authPrivateKeySeed: Uint8List.fromList(authSeed),
      authPublicKey: Uint8List.fromList(authPub.bytes),
      kemPrivateKey: Uint8List.fromList(kemPriv),
      kemPublicKey: Uint8List.fromList(kemPub.bytes),
      recoverySeed: crypto.generateRecoverySeed(),
    );

    final List<String> seenRequests = <String>[];
    final MockClient mockHttp = MockClient((http.Request request) async {
      seenRequests.add('${request.method} ${request.url.path}');
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/push/config') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'enabled': true,
            'projectId': 'deepsky-proto',
            'apiKey': 'AIzaTest',
            'appId': '1:111:android:222',
            'senderId': '111',
          }),
          200,
        );
      }

      // Protected endpoints must carry DeviceAuthFilter Ed25519 signature headers.
      expect(request.headers['X-Device-Id'], 'device-a');
      expect(request.headers['X-Timestamp'], isNotEmpty);
      expect(request.headers['X-Nonce'], isNotEmpty);
      expect(request.headers['X-Signature'], isNotEmpty);

      if (request.method == 'POST' &&
          request.url.path == '/api/v1/push/register') {
        final Map<String, dynamic> body =
            jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['fcmToken'], 'tok-123');
        expect(body['platform'], 'android');
        return http.Response(
          jsonEncode(<String, Object?>{
            'deviceId': 'device-a',
            'tokenPrefix': 'tok-123',
          }),
          200,
        );
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/v1/push/wakeup') {
        final Map<String, dynamic> body =
            jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['localizationKey'], 'wakeup.thinking_of_you');
        return http.Response(
          jsonEncode(<String, Object?>{
            'localizationKey': 'wakeup.thinking_of_you',
            'attempted': 1,
            'delivered': 1,
            'unregisteredRemoved': 0,
          }),
          200,
        );
      }
      if (request.method == 'DELETE' &&
          request.url.path == '/api/v1/push/register') {
        return http.Response('', 204);
      }
      return http.Response('not found', 404);
    });

    final PushApiClient client = PushApiClient(
      apiClient: CoupleApiClient(
        baseUrl: 'https://couple.example.test/',
        httpClient: mockHttp,
      ),
    );

    final RuntimeFirebaseConfig config = await client.fetchRuntimeConfig();
    expect(config.enabled, isTrue);
    expect(config.projectId, 'deepsky-proto');

    await client.registerToken(identity: identity, fcmToken: 'tok-123');

    final PushWakeupOutcome outcome = await client.sendPartnerWakeup(
      identity: identity,
      localizationKey: 'wakeup.thinking_of_you',
    );
    expect(outcome.delivered, 1);

    await client.unregisterToken(identity: identity);
    expect(seenRequests, <String>[
      'GET /api/v1/push/config',
      'POST /api/v1/push/register',
      'POST /api/v1/push/wakeup',
      'DELETE /api/v1/push/register',
    ]);
  });
}
