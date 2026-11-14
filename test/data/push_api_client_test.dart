import 'dart:convert';

import 'package:deep_sky/data/push_api_client.dart';
import 'package:deep_sky/domain/push_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'fetches runtime config, registers token, and dispatches wakeup',
    () async {
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
        if (request.method == 'PUT' &&
            request.url.path == '/api/v1/push/token') {
          final Map<String, dynamic> body =
              jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['deviceId'], 'device-a');
          expect(body['fcmToken'], 'tok-123');
          return http.Response(
            jsonEncode(<String, Object?>{
              'deviceId': 'device-a',
              'tokenPrefix': 'tok-123',
            }),
            200,
          );
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/v1/push/test-wakeup') {
          final Map<String, dynamic> body =
              jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['localizationKey'], 'wakeup.capsule_ready');
          return http.Response(
            jsonEncode(<String, Object?>{
              'localizationKey': 'wakeup.capsule_ready',
              'attempted': 1,
              'delivered': 1,
              'unregisteredRemoved': 0,
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      });

      final PushApiClient client = PushApiClient(
        baseUrl: 'https://couple.example.test/',
        httpClient: mockHttp,
      );

      final RuntimeFirebaseConfig config = await client.fetchRuntimeConfig();
      expect(config.enabled, isTrue);
      expect(config.projectId, 'deepsky-proto');

      await client.registerToken(
        deviceId: 'device-a',
        coupleId: 'couple-1',
        fcmToken: 'tok-123',
      );

      final PushWakeupOutcome outcome = await client.sendTestWakeup(
        deviceId: 'device-a',
        localizationKey: 'wakeup.capsule_ready',
      );
      expect(outcome.delivered, 1);
      expect(seenRequests, <String>[
        'GET /api/v1/push/config',
        'PUT /api/v1/push/token',
        'POST /api/v1/push/test-wakeup',
      ]);
    },
  );
}
