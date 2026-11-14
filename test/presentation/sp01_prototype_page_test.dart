import 'dart:convert';

import 'package:deep_sky/platform/native_bridge.dart';
import 'package:deep_sky/presentation/push/sp01_prototype_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(NativeBridge.channelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets(
    'SP-01 harness fetches runtime config, registers token, and triggers wakeup',
    (WidgetTester tester) async {
      bool initialized = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            switch (call.method) {
              case 'requestNotificationPermission':
                return true;
              case 'configureRuntimePush':
                initialized = true;
                return 'fcm-widget-token-999';
              case 'getPushStatus':
                return <String, Object>{
                  'configured': initialized,
                  'firebaseInitialized': initialized,
                  'projectId': initialized ? 'deepsky-proto' : '',
                  'appId': initialized ? '1:111:android:222' : '',
                  'lastKnownToken': initialized ? 'fcm-widget-token-999' : '',
                  'pendingToken': '',
                  'lastWakeupKey': '',
                  'lastWakeupEpochMs': 0,
                  'receivedCount': 0,
                  'hasNotificationPermission': true,
                };
              default:
                return null;
            }
          });

      final MockClient mockHttp = MockClient((http.Request request) async {
        if (request.url.path == '/api/v1/push/config') {
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
        if (request.url.path == '/api/v1/push/token') {
          return http.Response(jsonEncode(<String, Object?>{'ok': true}), 200);
        }
        if (request.url.path == '/api/v1/push/test-wakeup') {
          return http.Response(
            jsonEncode(<String, Object?>{
              'localizationKey': 'wakeup.new_moment',
              'attempted': 1,
              'delivered': 1,
              'unregisteredRemoved': 0,
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      });

      await tester.pumpWidget(
        MaterialApp(home: Sp01PrototypePage(httpClient: mockHttp)),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('sp01-fetch-config')));
      await tester.tap(find.byKey(const Key('sp01-fetch-config')));
      await tester.pumpAndSettle();
      expect(find.textContaining('deepsky-proto'), findsWidgets);

      await tester.ensureVisible(find.byKey(const Key('sp01-init-register')));
      await tester.tap(find.byKey(const Key('sp01-init-register')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('sp01-send-target')));
      await tester.tap(find.byKey(const Key('sp01-send-target')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Firebase initialized: true'));
      expect(find.text('Firebase initialized: true'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('sp01-status-banner')));
      expect(find.textContaining('delivered=1, evicted=0'), findsOneWidget);
    },
  );
}
