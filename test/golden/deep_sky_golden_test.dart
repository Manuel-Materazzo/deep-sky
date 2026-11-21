import 'dart:convert';
import 'dart:io';

import 'package:deep_sky/data/encrypted_local_cache.dart';
import 'package:deep_sky/data/secure_key_store.dart';
import 'package:deep_sky/domain/crypto/deep_sky_crypto.dart';
import 'package:deep_sky/domain/crypto/e2ee_models.dart';
import 'package:deep_sky/domain/platform_capabilities.dart';
import 'package:deep_sky/presentation/deep_sky_app.dart';
import 'package:deep_sky/presentation/deep_sky_controller.dart';
import 'package:deep_sky/scene/local_scene_view_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _GoldenDeepSkyCrypto extends DeepSkyCrypto {
  @override
  String generateSasSecretB64() => 'AQIDBAUGBwgJCgsMDQ4PEA';
}

/// Loads the bundled OFL fonts (and MaterialIcons when the Flutter SDK is found) so goldens
/// render real typography instead of the default Ahem test blocks.
Future<void> _loadGoldenFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final FontLoader loader = FontLoader(family);
    for (final String path in paths) {
      final File file = File(path);
      if (file.existsSync()) {
        final Uint8List bytes = file.readAsBytesSync();
        loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
      }
    }
    await loader.load();
  }

  await load('Plus Jakarta Sans', <String>[
    'assets/fonts/plus_jakarta_sans/PlusJakartaSans-Regular.ttf',
    'assets/fonts/plus_jakarta_sans/PlusJakartaSans-Medium.ttf',
    'assets/fonts/plus_jakarta_sans/PlusJakartaSans-SemiBold.ttf',
    'assets/fonts/plus_jakarta_sans/PlusJakartaSans-Bold.ttf',
  ]);
  await load('Nunito Sans', <String>[
    'assets/fonts/nunito_sans/NunitoSans-Regular.ttf',
    'assets/fonts/nunito_sans/NunitoSans-Medium.ttf',
    'assets/fonts/nunito_sans/NunitoSans-SemiBold.ttf',
    'assets/fonts/nunito_sans/NunitoSans-Bold.ttf',
  ]);
  final String? flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    await load('MaterialIcons', <String>[
      '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ]);
  }
}

const PlatformCapabilities _goldenCaps = PlatformCapabilities(
  packageName: 'com.vectevo.deep_sky',
  androidApiLevel: 35,
  versionName: '1.1.0',
  versionCode: 2,
  supportsRequestInstallPackages: false,
);

Future<InMemorySecureKeyStore> _pairedGoldenStore() async {
  final InMemorySecureKeyStore store = InMemorySecureKeyStore();
  final DeepSkyCrypto crypto = DeepSkyCrypto();
  final authKp = await crypto.generateDeviceAuthKeyPair();
  final kemKp = await crypto.generateDeviceKemKeyPair();
  final Uint8List seed = Uint8List.fromList(
    List<int>.generate(32, (int i) => i + 5),
  );
  final LocalDeviceIdentity id = LocalDeviceIdentity(
    serverUrl: 'https://couple.example.test',
    coupleId: 'couple-golden',
    deviceId: 'dev-me',
    deviceLabel: 'Luca',
    authPrivateKeySeed: Uint8List.fromList(
      await authKp.extractPrivateKeyBytes(),
    ),
    authPublicKey: Uint8List.fromList((await authKp.extractPublicKey()).bytes),
    kemPrivateKey: Uint8List.fromList(await kemKp.extractPrivateKeyBytes()),
    kemPublicKey: Uint8List.fromList((await kemKp.extractPublicKey()).bytes),
    recoverySeed: seed,
    pairingCompleted: true,
    nameSetupCompleted: true,
    recoverySavedConfirmed: true,
  );
  await store.write('deep_sky.device_identity.v1', jsonEncode(id.toJson()));
  return store;
}

MockClient _goldenHomeServer() {
  return MockClient((http.Request req) async {
    if (req.url.path == '/api/v1/system/compatibility') {
      return http.Response(
        '{"minClientVersionCode":1,"minProtocolVersion":1,"minPackVersion":"1.0.0"}',
        200,
      );
    }
    if (req.url.path == '/api/v1/sync/envelopes') {
      return http.Response(
        '{"items":[],"nextAfterSeq":0,"hasMore":false,"coupleKeyEpoch":1}',
        200,
      );
    }
    if (req.url.path == '/api/v1/pairing/devices') {
      return http.Response(
        jsonEncode(<Map<String, Object?>>[
          <String, Object?>{
            'deviceId': 'dev-me',
            'label': 'Luca',
            'enrolledVia': 'PAIRING_INVITER',
            'createdAt': '2026-11-15T10:00:00Z',
            'revokedAt': null,
          },
          <String, Object?>{
            'deviceId': 'dev-partner',
            'label': 'Anna',
            'enrolledVia': 'PAIRING_JOINER',
            'createdAt': '2026-11-15T10:05:00Z',
            'revokedAt': null,
          },
        ]),
        200,
      );
    }
    if (req.url.path == '/api/v1/push/config') {
      return http.Response('{"enabled":false}', 200);
    }
    return http.Response('{}', 404);
  });
}

/// v1.0.0 manifest plus a SYNTHETIC `floor_lamp` slot (test-only, reusing existing v1 PNGs as
/// stand-in art: `window_frame` = calm, `window_sky_night` = lit) so the lit state is renderable
/// before the real v1.1.0 lamp assets exist.
String _manifestWithSyntheticLamp(String v1ManifestRaw) {
  final Map<String, Object?> manifest =
      jsonDecode(v1ManifestRaw) as Map<String, Object?>;
  (manifest['slots']! as List<Object?>).add(<String, Object?>{
    'id': 'floor_lamp',
    'description': 'Synthetic lamp for golden tests',
    'zIndex': 35,
    'replaceable': true,
    'anchor': <String, double>{'x': 0.83, 'y': 0.54},
    'bounds': <String, double>{
      'x': 0.75,
      'y': 0.30,
      'width': 0.16,
      'height': 0.48,
    },
    'touchArea': <String, double>{
      'x': 0.73,
      'y': 0.28,
      'width': 0.20,
      'height': 0.52,
    },
    'accessibilityLabel': <String, String>{
      'it': 'Lampada da terra',
      'en': 'Floor lamp',
    },
    'defaultState': 'calm',
    'states': <String, Object?>{
      'calm': <String, Object?>{
        'layers': <Object?>[
          <String, Object?>{
            'id': 'lamp',
            'asset': 'assets/window_frame.png',
            'zOffset': 0,
          },
        ],
      },
      'lit': <String, Object?>{
        'layers': <Object?>[
          <String, Object?>{
            'id': 'lamp',
            'asset': 'assets/window_sky_night.png',
            'zOffset': 0,
          },
        ],
      },
    },
    'animations': <Object?>[],
  });
  return jsonEncode(manifest);
}

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets(
    'Deep Sky Intimate Sanctuary welcome screen matches dark & light golden snapshots',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final String pilotManifestRaw = File(
        'content/packs/ds2_pilot/manifest.json',
      ).readAsStringSync();

      final MockClient mockHttp = MockClient((http.Request req) async {
        if (req.method == 'POST' && req.url.path == '/api/v1/pairing/invites') {
          return http.Response(
            jsonEncode(<String, Object?>{
              'coupleId': 'couple-golden',
              'deviceId': 'dev-golden',
              'inviteToken': 'golden_tok_8492a1f',
              'expiresAt': DateTime.now()
                  .toUtc()
                  .add(const Duration(minutes: 15))
                  .toIso8601String(),
            }),
            201,
            headers: const <String, String>{'Content-Type': 'application/json'},
          );
        }
        return http.Response('{}', 503);
      });

      final DeepSkyController controller = DeepSkyController(
        keyStore: InMemorySecureKeyStore(),
        crypto: _GoldenDeepSkyCrypto(),
        httpClient: mockHttp,
        loadAssetString: (_) async => pilotManifestRaw,
        loadCapabilities: () async => const PlatformCapabilities(
          packageName: 'com.vectevo.deep_sky',
          androidApiLevel: 35,
          versionName: '1.0.0',
          versionCode: 1,
          supportsRequestInstallPackages: false,
        ),
      );
      controller.reduceMotion = true;

      await tester.pumpWidget(DeepSkyApp(controller: controller));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(DeepSkyApp),
        matchesGoldenFile('goldens/onboarding_dark.png'),
      );

      controller.toggleNightMode();
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(DeepSkyApp),
        matchesGoldenFile('goldens/onboarding_light.png'),
      );
    },
  );

  testWidgets(
    'S3-2 Home screen matches dark night, light day, and received-thought golden snapshots',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final String v1ManifestRaw = File('content/packs/v1/manifest.json')
          .readAsStringSync();
      final DateTime nowUtc = DateTime.utc(2026, 11, 21, 21, 0);

      final InMemorySecureKeyStore store = await _pairedGoldenStore();
      final MockClient mockHttp = _goldenHomeServer();

      final DeepSkyController controller = DeepSkyController(
        keyStore: store,
        httpClient: mockHttp,
        loadAssetString: (_) async => v1ManifestRaw,
        loadCapabilities: () async => _goldenCaps,
        defaultServerUrl: 'https://couple.example.test',
        enableSkyRefreshTimer: false,
        clockUtc: () => nowUtc,
        clockLocal: () => DateTime(2026, 11, 21, 22, 0),
      );
      controller.reduceMotion = true;

      await tester.pumpWidget(DeepSkyApp(controller: controller));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(DeepSkyApp),
        matchesGoldenFile('goldens/home_night_dark.png'),
      );

      // Light theme + Day sky
      await controller.setSkyPreference(SkyTimePreference.day);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(DeepSkyApp),
        matchesGoldenFile('goldens/home_day_light.png'),
      );

      // Dark theme + Night sky + received unseen partner thought (< 6h)
      controller.isNight = true;
      await controller.setSkyPreference(SkyTimePreference.night);
      controller.events = <CachedEventEntry>[
        CachedEventEntry(
          envelopeId: 'env-golden-1',
          coupleId: 'couple-golden',
          senderDeviceId: 'dev-partner',
          channel: EnvelopeChannel.event,
          keyEpoch: 1,
          seq: 1,
          createdAtServer: nowUtc.subtract(const Duration(minutes: 45)),
          payload: DecryptedEnvelopePayload(
            schemaVersion: 1,
            eventType: 'thinking_of_you',
            createdAtClient: nowUtc.subtract(const Duration(minutes: 45)),
            authorDeviceId: 'dev-partner',
            body: const <String, Object?>{'note': 'Sotto lo stesso cielo'},
          ),
        ),
      ];
      controller.refreshLocalSkyPeriod();
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(DeepSkyApp),
        matchesGoldenFile('goldens/home_thought_received_dark.png'),
      );
    },
  );

  testWidgets(
    'S3-2 Home matches twilight (19:10 local) and lit floor-lamp golden snapshots',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final String lampManifest = _manifestWithSyntheticLamp(
        File('content/packs/v1/manifest.json').readAsStringSync(),
      );
      final DateTime nowUtc = DateTime.utc(2026, 11, 21, 18, 10);

      final DeepSkyController controller = DeepSkyController(
        keyStore: await _pairedGoldenStore(),
        httpClient: _goldenHomeServer(),
        loadAssetString: (_) async => lampManifest,
        loadCapabilities: () async => _goldenCaps,
        defaultServerUrl: 'https://couple.example.test',
        enableSkyRefreshTimer: false,
        clockUtc: () => nowUtc,
        clockLocal: () => DateTime(2026, 11, 21, 19, 10),
      );
      controller.reduceMotion = true;

      await tester.pumpWidget(DeepSkyApp(controller: controller));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();

      expect(controller.sceneState.skyPeriod, SkyPeriod.twilight);
      expect(controller.sceneState.floorLampLit, isFalse);
      await expectLater(
        find.byType(DeepSkyApp),
        matchesGoldenFile('goldens/home_twilight.png'),
      );

      // Unseen partner thought (< 6h) lights the floor lamp (`lit`) at the same local time.
      controller.events = <CachedEventEntry>[
        CachedEventEntry(
          envelopeId: 'env-golden-lit',
          coupleId: 'couple-golden',
          senderDeviceId: 'dev-partner',
          channel: EnvelopeChannel.event,
          keyEpoch: 1,
          seq: 1,
          createdAtServer: nowUtc.subtract(const Duration(minutes: 30)),
          payload: DecryptedEnvelopePayload(
            schemaVersion: 1,
            eventType: 'thinking_of_you',
            createdAtClient: nowUtc.subtract(const Duration(minutes: 30)),
            authorDeviceId: 'dev-partner',
            body: const <String, Object?>{'note': 'Ti aspetto a casa'},
          ),
        ),
      ];
      await controller.setSkyPreference(SkyTimePreference.auto);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();

      expect(controller.sceneState.floorLampLit, isTrue);
      await expectLater(
        find.byType(DeepSkyApp),
        matchesGoldenFile('goldens/home_twilight_lamp_lit.png'),
      );
    },
  );
}
