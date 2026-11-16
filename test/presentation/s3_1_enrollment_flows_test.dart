import 'dart:convert';
import 'dart:io';

import 'package:deep_sky/data/apk_update_service.dart';
import 'package:deep_sky/data/secure_key_store.dart';
import 'package:deep_sky/domain/crypto/deep_sky_crypto.dart';
import 'package:deep_sky/domain/crypto/e2ee_models.dart';
import 'package:deep_sky/domain/crypto/recovery_key_codec.dart';
import 'package:deep_sky/domain/platform_capabilities.dart';
import 'package:deep_sky/domain/update/apk_update_models.dart';
import 'package:deep_sky/platform/native_bridge.dart';
import 'package:deep_sky/presentation/deep_sky_app.dart';
import 'package:deep_sky/presentation/deep_sky_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final String pilotManifestRaw = File('content/packs/ds2_pilot/manifest.json')
      .readAsStringSync();

  const PlatformCapabilities testCaps = PlatformCapabilities(
    packageName: 'com.vectevo.deep_sky',
    androidApiLevel: 35,
    versionName: '1.0.0',
    versionCode: 1,
    supportsRequestInstallPackages: false,
  );

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      final Finder scrollables = find.byType(Scrollable);
      if (scrollables.evaluate().isNotEmpty) {
        await tester.scrollUntilVisible(
          finder,
          200,
          scrollable: scrollables.last,
        );
      }
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  test('UpdateChannel stable ignores pre-releases while preview selects them', () async {
    final MockClient mockHttp = MockClient((http.Request req) async {
      if (req.url.toString() ==
          'https://api.github.com/repos/Manuel-Materazzo/deep-sky/releases?per_page=10') {
        return http.Response(
          jsonEncode(<Map<String, Object?>>[
            <String, Object?>{
              'tag_name': 'v0.9.0-preview.1',
              'draft': false,
              'prerelease': true,
            },
            <String, Object?>{
              'tag_name': 'v0.8.0',
              'draft': false,
              'prerelease': false,
            },
          ]),
          200,
        );
      }
      return http.Response('not found', 404);
    });

    final ApkUpdateService service = ApkUpdateService(httpClient: mockHttp);

    final Uri stableUri = await service.resolveChannelBaseUri(
      sourceInput: 'Manuel-Materazzo/deep-sky',
      channel: UpdateChannel.stable,
    );
    expect(
      stableUri.toString(),
      'https://github.com/Manuel-Materazzo/deep-sky/releases/latest/download',
    );

    final Uri previewUri = await service.resolveChannelBaseUri(
      sourceInput: 'Manuel-Materazzo/deep-sky',
      channel: UpdateChannel.preview,
    );
    expect(
      previewUri.toString(),
      'https://github.com/Manuel-Materazzo/deep-sky/releases/download/v0.9.0-preview.1',
    );
  });

  testWidgets(
    'Deep link pre-fills Join tab without silently switching server; custom server requires blocking confirmation (S1-APP-01, CA-06)',
    (WidgetTester tester) async {
      final List<Uri> acceptRequests = <Uri>[];
      final DeepSkyController controller = DeepSkyController(
        keyStore: InMemorySecureKeyStore(),
        httpClient: MockClient((http.Request req) async {
          if (req.url.path == '/api/v1/system/compatibility') {
            return http.Response(
              jsonEncode(<String, Object?>{
                'minClientVersionCode': 1,
                'minProtocolVersion': 1,
              }),
              200,
            );
          }
          if (req.url.path == '/api/v1/pairing/invites/accept') {
            acceptRequests.add(req.url);
            return http.Response(
              jsonEncode(<String, Object?>{
                'coupleId': 'c-custom',
                'deviceId': 'd-custom',
                'peerDeviceId': 'd-peer',
                'peerLabel': 'Peer',
                'peerAuthPublicKeyB64': base64UrlEncode(List<int>.filled(32, 1)),
                'peerKemPublicKeyB64': base64UrlEncode(List<int>.filled(32, 2)),
              }),
              200,
              headers: const <String, String>{'Content-Type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
        }),
        loadAssetString: (_) async => pilotManifestRaw,
        loadCapabilities: () async => testCaps,
        defaultServerUrl: 'https://deepsky.vectevo.com',
      );
      controller.reduceMotion = true;
      await controller.initialize();

      await tester.pumpWidget(DeepSkyApp(controller: controller));
      await tester.pumpAndSettle();

      controller.handleIncomingDeepLink(
        'https://deepsky.vectevo.com/join#server=https%3A%2F%2Fcasa.example.test&token=tok-deep-42',
      );
      await tester.pumpAndSettle();

      expect(controller.onboardingTabIndex, 1);
      // Must NOT silently switch activeServerUrl before confirmation (CA-06)
      expect(controller.activeServerUrl, 'https://deepsky.vectevo.com');
      final TextField joinField = tester.widget<TextField>(
        find.byKey(const Key('join-token-field')),
      );
      expect(joinField.controller?.text, contains('tok-deep-42'));

      // Tapping Join shows blocking confirmation naming custom host; rejecting keeps official server
      await tester.ensureVisible(find.byKey(const Key('accept-invite-button')));
      await tester.tap(find.byKey(const Key('accept-invite-button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('custom-server-confirm-dialog')),
        findsOneWidget,
      );
      expect(find.textContaining('casa.example.test'), findsWidgets);

      await tester.tap(find.byKey(const Key('custom-server-reject-button')));
      await tester.pumpAndSettle();
      expect(controller.activeServerUrl, 'https://deepsky.vectevo.com');
      expect(acceptRequests, isEmpty);

      // Confirming switches server and completes acceptInvite
      await tester.ensureVisible(find.byKey(const Key('accept-invite-button')));
      await tester.tap(find.byKey(const Key('accept-invite-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('custom-server-confirm-button')));
      await tester.pumpAndSettle();
      expect(controller.activeServerUrl, 'https://casa.example.test');
      expect(acceptRequests, hasLength(1));
      expect(
        acceptRequests.first.toString(),
        'https://casa.example.test/api/v1/pairing/invites/accept',
      );
    },
  );

  testWidgets(
    'Rejects insecure http:// non-local server in invite link (CA-06)',
    (WidgetTester tester) async {
      final DeepSkyController controller = DeepSkyController(
        keyStore: InMemorySecureKeyStore(),
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode(<String, Object?>{
              'minClientVersionCode': 1,
              'minProtocolVersion': 1,
            }),
            200,
          ),
        ),
        loadAssetString: (_) async => pilotManifestRaw,
        loadCapabilities: () async => testCaps,
        defaultServerUrl: 'https://deepsky.vectevo.com',
      );
      controller.reduceMotion = true;
      await controller.initialize();

      await tester.pumpWidget(DeepSkyApp(controller: controller));
      await tester.pumpAndSettle();

      controller.handleIncomingDeepLink(
        'deepsky://pair#server=http%3A%2F%2Fevil.example.com&token=tok-evil',
      );
      await tester.pumpAndSettle();

      expect(controller.activeServerUrl, 'https://deepsky.vectevo.com');
      expect(controller.errorNotice, contains('HTTPS'));
    },
  );

  testWidgets(
    'Guided 24-word recovery shows word chips, missing count, and calm failure (S1-D10, S1-APP-04)',
    (WidgetTester tester) async {
      final MockClient mockHttp = MockClient((http.Request req) async {
        if (req.url.path == '/api/v1/system/compatibility') {
          return http.Response(
            jsonEncode(<String, Object?>{
              'minClientVersionCode': 1,
              'minProtocolVersion': 1,
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode(<String, Object?>{
            'code': 'NOT_FOUND',
            'message': 'Couple not found for recovery key',
          }),
          404,
        );
      });

      final DeepSkyController controller = DeepSkyController(
        keyStore: InMemorySecureKeyStore(),
        httpClient: mockHttp,
        loadAssetString: (_) async => pilotManifestRaw,
        loadCapabilities: () async => testCaps,
        defaultServerUrl: 'https://couple.example.test',
      );
      controller.reduceMotion = true;
      await tester.pumpWidget(DeepSkyApp(controller: controller));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('Recupera'));
      await tester.enterText(
        find.byKey(const Key('recovery-words-field')),
        'abandon ability notaword',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('recovery-word-chips-panel')),
        findsOneWidget,
      );
      expect(find.textContaining('21 parole mancanti'), findsOneWidget);
      expect(
        find.byKey(const Key('recovery-invalid-words-hint')),
        findsOneWidget,
      );

      final String validSentence = RecoveryKeyCodec.toSentence(
        Uint8List.fromList(List<int>.generate(32, (int i) => i + 1)),
      );
      await tester.enterText(
        find.byKey(const Key('recovery-words-field')),
        validSentence,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('24 parole complete'), findsOneWidget);
      expect(
        find.byKey(const Key('recovery-invalid-words-hint')),
        findsNothing,
      );

      await tapVisible(tester, find.byKey(const Key('recover-space-button')));
      expect(
        find.textContaining('Non siamo riusciti a sbloccare la stanza'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Dedicated RecoveryKeySetupPage toggles QR, contextual push prompt dismisses, and revoke asks calmly (S1-D04, S1-D11, S1-D12)',
    (WidgetTester tester) async {
      final DeepSkyCrypto crypto = DeepSkyCrypto();
      final Uint8List seed = Uint8List.fromList(
        List<int>.generate(32, (int i) => i + 7),
      );
      final authKp = await crypto.generateDeviceAuthKeyPair();
      final kemKp = await crypto.generateDeviceKemKeyPair();
      final InMemorySecureKeyStore store = InMemorySecureKeyStore();
      final LocalDeviceIdentity initialId = LocalDeviceIdentity(
        serverUrl: 'https://couple.example.test',
        coupleId: 'couple-1',
        deviceId: 'dev-a',
        deviceLabel: 'Luca',
        authPrivateKeySeed: Uint8List.fromList(
          await authKp.extractPrivateKeyBytes(),
        ),
        authPublicKey: Uint8List.fromList(
          (await authKp.extractPublicKey()).bytes,
        ),
        kemPrivateKey: Uint8List.fromList(await kemKp.extractPrivateKeyBytes()),
        kemPublicKey: Uint8List.fromList(
          (await kemKp.extractPublicKey()).bytes,
        ),
        recoverySeed: seed,
        pairingCompleted: true,
        nameSetupCompleted: true,
        recoverySavedConfirmed: false,
      );
      await store.write(
        'deep_sky.device_identity.v1',
        jsonEncode(initialId.toJson()),
      );

      String? revokedDevice;
      final MockClient mockHttp = MockClient((http.Request req) async {
        if (req.url.path == '/api/v1/system/compatibility') {
          return http.Response(
            jsonEncode(<String, Object?>{
              'minClientVersionCode': 1,
              'minProtocolVersion': 1,
            }),
            200,
          );
        }
        if (req.url.path == '/api/v1/sync/envelopes') {
          return http.Response(
            '{"items":[],"nextAfterSeq":0,"hasMore":false}',
            200,
          );
        }
        if (req.url.path == '/api/v1/pairing/devices') {
          return http.Response(
            jsonEncode(<Map<String, Object?>>[
              <String, Object?>{
                'deviceId': 'dev-a',
                'label': 'Luca',
                'enrolledVia': 'INITIAL',
                'createdAt': '2026-11-15T10:00:00Z',
                'revokedAt': null,
              },
              if (revokedDevice == null)
                <String, Object?>{
                  'deviceId': 'dev-b',
                  'label': 'Partner Phone',
                  'enrolledVia': 'INVITE_JOIN',
                  'createdAt': '2026-11-15T10:05:00Z',
                  'revokedAt': null,
                },
            ]),
            200,
          );
        }
        if (req.url.path == '/api/v1/push/config') {
          return http.Response(
            jsonEncode(<String, Object?>{
              'enabled': true,
              'projectId': 'ds-test',
              'apiKey': 'test-key',
              'appId': '1:1:android:abc',
              'senderId': '1',
            }),
            200,
          );
        }
        if (req.url.path == '/api/v1/pairing/devices/dev-b/revoke') {
          revokedDevice = 'dev-b';
          return http.Response('', 204);
        }
        return http.Response('not found', 404);
      });

      final DeepSkyController controller = DeepSkyController(
        keyStore: store,
        httpClient: mockHttp,
        loadAssetString: (_) async => pilotManifestRaw,
        loadCapabilities: () async => testCaps,
        defaultServerUrl: 'https://couple.example.test',
      );
      controller.reduceMotion = true;
      await tester.pumpWidget(DeepSkyApp(controller: controller));
      await tester.pumpAndSettle();

      // Lands on dedicated RecoveryKeySetupPage (S1-D04)
      expect(find.byKey(const Key('recovery-key-setup-page')), findsOneWidget);
      await tapVisible(tester, find.text('Codice QR'));
      expect(find.byKey(const Key('recovery-qr-image')), findsOneWidget);
      await tapVisible(
        tester,
        find.byKey(const Key('recovery-saved-checkbox')),
      );
      await tapVisible(
        tester,
        find.byKey(const Key('confirm-recovery-button')),
      );

      // Enters Home and sees contextual quiet notifications prompt (S1-D12)
      expect(find.byKey(const Key('home-shell-page')), findsOneWidget);
      expect(find.byKey(const Key('push-optin-card')), findsOneWidget);
      await tapVisible(
        tester,
        find.byKey(const Key('push-optin-later-button')),
      );
      expect(find.byKey(const Key('push-optin-card')), findsNothing);

      // Devices tab asks calmly for confirmation before revoking another device (S1-D11)
      await tapVisible(tester, find.text('Dispositivi'));
      await tapVisible(tester, find.byKey(const Key('revoke-device-dev-b')));
      expect(find.text('Revocare questo dispositivo?'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('confirm-revoke-dev-b')));
      expect(revokedDevice, 'dev-b');
    },
  );

  testWidgets(
    'Settings push card surfaces native diagnostics and opens notification settings when needed',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final InMemorySecureKeyStore store = InMemorySecureKeyStore();
      final DeepSkyCrypto crypto = DeepSkyCrypto();
      final authKp = await crypto.generateDeviceAuthKeyPair();
      final kemKp = await crypto.generateDeviceKemKeyPair();
      final Uint8List seed = Uint8List.fromList(
        List<int>.generate(32, (i) => i + 3),
      );
      final LocalDeviceIdentity initialId = LocalDeviceIdentity(
        serverUrl: 'https://couple.example.test',
        coupleId: 'couple-1',
        deviceId: 'dev-a',
        deviceLabel: 'Luca',
        authPrivateKeySeed: Uint8List.fromList(
          await authKp.extractPrivateKeyBytes(),
        ),
        authPublicKey: Uint8List.fromList(
          (await authKp.extractPublicKey()).bytes,
        ),
        kemPrivateKey: Uint8List.fromList(await kemKp.extractPrivateKeyBytes()),
        kemPublicKey: Uint8List.fromList(
          (await kemKp.extractPublicKey()).bytes,
        ),
        recoverySeed: seed,
        pairingCompleted: true,
        nameSetupCompleted: true,
        recoverySavedConfirmed: true,
      );
      await store.write(
        'deep_sky.device_identity.v1',
        jsonEncode(initialId.toJson()),
      );

      final MockClient mockHttp = MockClient((http.Request req) async {
        if (req.url.path == '/api/v1/system/compatibility') {
          return http.Response(
            jsonEncode(<String, Object?>{
              'minClientVersionCode': 1,
              'minProtocolVersion': 1,
            }),
            200,
          );
        }
        if (req.url.path == '/api/v1/sync/envelopes') {
          return http.Response(
            '{"items":[],"nextAfterSeq":0,"hasMore":false}',
            200,
          );
        }
        if (req.url.path == '/api/v1/pairing/devices') {
          return http.Response('[]', 200);
        }
        if (req.url.path == '/api/v1/push/config') {
          return http.Response(
            jsonEncode(<String, Object?>{
              'enabled': true,
              'projectId': 'ds-test',
              'apiKey': 'test-key',
              'appId': '1:1:android:abc',
              'senderId': '1',
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      });

      const MethodChannel channel = MethodChannel('test.push/xiaomi');
      bool openedSettings = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            switch (call.method) {
              case 'getPushStatus':
                return <String, Object?>{
                  'configured': false,
                  'firebaseInitialized': false,
                  'projectId': '',
                  'appId': '',
                  'lastKnownToken': '',
                  'pendingToken': '',
                  'lastWakeupKey': '',
                  'lastWakeupEpochMs': 0,
                  'receivedCount': 0,
                  'hasNotificationPermission': true,
                };
              case 'consumePendingPushToken':
                return '';
              case 'requestNotificationPermission':
                return true;
              case 'configureRuntimePush':
                throw PlatformException(
                  code: 'gms_unavailable',
                  message: 'Play Services restricted',
                );
              case 'openNotificationSettings':
                openedSettings = true;
                return true;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      final DeepSkyController controller = DeepSkyController(
        keyStore: store,
        httpClient: mockHttp,
        nativeBridge: const NativeBridge(channel),
        loadAssetString: (_) async => pilotManifestRaw,
        loadCapabilities: () async => testCaps,
        defaultServerUrl: 'https://couple.example.test',
      );
      controller.reduceMotion = true;
      await tester.pumpWidget(DeepSkyApp(controller: controller));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('Impostazioni'));
      expect(find.text('Permesso di sistema: consentito'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('enable-push-button')));
      expect(find.byKey(const Key('push-feedback-text')), findsOneWidget);
      expect(find.textContaining('Google Play Services'), findsOneWidget);

      await tapVisible(
        tester,
        find.byKey(const Key('open-notification-settings-button')),
      );
      expect(openedSettings, isTrue);
    },
  );
}
